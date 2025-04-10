import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

import '../../core/supabase/instruction_service.dart';
import '../../core/language/extensions.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/conversation_manager.dart';
import '../../core/models/conversation_message.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/conversation_interface_widget.dart';

class Conversation {
  final String id;
  final String role;
  final String text;
  final String timestamp;
  final bool isFinal;
  final String? status;

  const Conversation({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isFinal = false,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'timestamp': timestamp,
        'isFinal': isFinal,
        'status': status,
      };

  Conversation copyWith({
    String? text,
    bool? isFinal,
    String? status,
  }) {
    return Conversation(
      id: id,
      role: role,
      text: text ?? this.text,
      timestamp: timestamp,
      isFinal: isFinal ?? this.isFinal,
      status: status ?? this.status,
    );
  }
}

class WebRTCError implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  WebRTCError(this.message, {this.code, this.details});

  @override
  String toString() =>
      'WebRTCError: $message${code != null ? ' (code: $code)' : ''}';
}

/// 실시간 음성 대화 페이지
///
/// WebRTC를 활용한 AI와의 실시간 음성 대화 인터페이스를 제공합니다.
class RealtimeCommunicationPage extends StatefulWidget {
  /// 사용자 ID
  final String userId;

  /// AI 모델
  final String model;

  /// 음성 유형
  final String voice;

  /// 생성자
  const RealtimeCommunicationPage({
    super.key,
    required this.userId,
    this.model = "gpt-4o-realtime-preview-2024-12-17",
    this.voice = "alloy",
  });

  @override
  State<RealtimeCommunicationPage> createState() =>
      _RealtimeCommunicationPageState();
}

class _RealtimeCommunicationPageState extends State<RealtimeCommunicationPage> {
  // 서비스 객체들
  late WebRTCService _webRTCService;
  late AudioService _audioService;
  late ConversationManager _conversationManager;

  // 상태 변수들
  final _audioElement = RTCVideoRenderer();
  String _status = 'Initializing...';
  String _connectionState = 'New';
  bool _isInputActive = false;
  bool _isOutputActive = false;
  bool _isConversationStarted = false;
  bool _isSaving = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // 애니메이션 컨트롤러
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _setupServices();
    _initializeSession();
    _loadInterstitialAd();

    // Set initial status with default value (will be properly localized in build)
    _status = 'initializing';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Localizations는 initState가 완료된 후에 액세스해야 함
    if (!mounted) return;

    if (_conversationManager != null) {
      final locale = Localizations.localeOf(context);
      final newLanguageCode = locale.languageCode;

      // 처음 실행 시 또는 언어 코드가 변경된 경우 업데이트
      if (_conversationManager.languageCode != newLanguageCode) {
        _conversationManager.languageCode = newLanguageCode;
      }
    }
  }

  @override
  void dispose() {
    // Reset saving state
    _isSaving = false;

    // 서비스 객체 정리
    _audioService.dispose();
    _webRTCService.dispose();
    _conversationManager.dispose();

    // 오디오 요소 정리
    _audioElement.dispose();

    // 전면 광고 정리
    _interstitialAd?.dispose();

    super.dispose();
  }

  /// 서비스 객체 초기화
  void _setupServices() {
    // WebRTC 서비스 초기화
    _webRTCService = WebRTCService(
      onConnectionStateChanged: _handleConnectionStateChanged,
      onAudioTrackReceived: _handleAudioTrackReceived,
    );
    _webRTCService.setAudioRenderer(_audioElement);

    // 오디오 서비스 초기화
    _audioService = AudioService(
      onInputStatusChanged: _handleInputStatusChanged,
      onOutputStatusChanged: _handleOutputStatusChanged,
    );

    // 대화 관리자 초기화 (기본 언어 코드로 초기화)
    _conversationManager = ConversationManager(
      _webRTCService,
      onConversationStateChanged: _handleConversationStateChanged,
      onConversationUpdated: _handleConversationUpdated,
      onSaved: _handleConversationSaved,
      onError: _handleConversationError,
      // 기본값으로 'en' 사용, didChangeDependencies에서 업데이트됨
    );
  }

  /// 세션 초기화
  Future<void> _initializeSession() async {
    try {
      await _audioElement.initialize();

      if (!mounted) return;

      final instruction = await InstructionService.getInstruction(
        widget.userId,
      );

      if (!mounted) return;

      await _webRTCService.initializeSession(
        userId: widget.userId,
        model: widget.model,
        voice: widget.voice,
        instructions: instruction,
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Unknown error occurred';

      if (e is WebRTCError) {
        errorMessage = e.message;
        if (e.code != null) {
          errorMessage += ' (${e.code})';
        }
      } else {
        errorMessage = e.toString();
      }

      _updateStatus('Error: $errorMessage');
      _showErrorDialog(errorMessage);
    }
  }

  /// 연결 상태 변경 처리
  void _handleConnectionStateChanged(String state) {
    if (!mounted) return;

    setState(() {
      _connectionState = state;
      _updateStatus(state);
    });
  }

  /// 오디오 트랙 수신 처리
  void _handleAudioTrackReceived(MediaStream stream) {
    if (!mounted) return;

    setState(() {
      _audioElement.srcObject = stream;
    });

    // 오디오 분석 시작
    _audioService.startAudioAnalysis();
  }

  /// 입력 상태 변경 처리
  void _handleInputStatusChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isInputActive = isActive;
    });

    _updateVoiceAnimation();
  }

  /// 출력 상태 변경 처리
  void _handleOutputStatusChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isOutputActive = isActive;
    });

    _updateVoiceAnimation();
  }

  /// 대화 상태 변경 처리
  void _handleConversationStateChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isConversationStarted = isActive;
    });
  }

  /// 대화 업데이트 처리
  void _handleConversationUpdated(List<ConversationMessage> messages) {
    if (mounted) {
      setState(() {
        // 화면 갱신 트리거
      });
    }
  }

  /// 대화 저장
  void _saveConversation() async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Set saving mode flag
    setState(() {
      _isSaving = true;
    });

    // 전면 광고가 준비되어 있다면 표시
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // 다음 광고 로드
          _saveConversationToServer();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd(); // 다음 광고 로드
          _saveConversationToServer();
        },
      );
      await _interstitialAd!.show();
    } else {
      _saveConversationToServer();
    }
  }

  /// 서버에 대화 저장
  Future<void> _saveConversationToServer() async {
    try {
      // 대화 저장 요청
      await _conversationManager.stopAndSaveConversation(context);

      // 로딩 닫기 (이미 저장 성공/실패 핸들러에서 네비게이션하므로 여기서는 팝업만 닫음)
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _handleConversationError();
    }
  }

  /// 대화 저장 완료 처리
  void _handleConversationSaved() {
    if (!mounted) return;

    // Reset saving mode flag
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('conversationSavedSuccessfully')),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pushReplacementNamed('/');
  }

  /// 대화 저장 오류 처리
  void _handleConversationError() {
    if (!mounted) return;

    // Reset saving mode flag
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('failedToSaveConversation')),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 상태 텍스트 업데이트
  void _updateStatus(String status) {
    if (!mounted) return;

    setState(() {
      switch (status) {
        case 'Requesting microphone access...':
          _status = 'checkingMicrophone';
          break;
        case 'Fetching session data...':
          _status = 'preparingAIModel';
          break;
        case 'Establishing connection...':
          _status = 'settingUpVoiceChat';
          break;
        case 'Connected':
          _status = 'readyToStartConversation';
          break;
        case 'Data channel opened':
          _status = 'connectionEstablished';
          break;
        default:
          if (status.startsWith('Error:')) {
            _status = 'connectionErrorOccurred';
          } else if (status.startsWith('Connection state:')) {
            // 연결 상태 업데이트는 상태 텍스트에 반영하지 않음
            return;
          } else {
            _status = status;
          }
      }
    });
  }

  /// 음성 애니메이션 제어
  void _updateVoiceAnimation() {
    if (!mounted || _animationController == null) return;

    if (_isInputActive || _isOutputActive) {
      _animationController!.repeat();
    } else if (_isConversationStarted) {
      // 대화가 시작되었으나 입력/출력이 없는 경우
      _animationController!.repeat();
    } else {
      // 대화가 시작되지 않은 경우
      _animationController!.stop();
    }
  }

  /// 오류 대화상자 표시
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryConnection();
            },
            child: Text(context.tr('retry')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  /// 연결 재시도
  Future<void> _retryConnection() async {
    if (!mounted) return;

    // Reset saving flag in case of retry after error
    setState(() {
      _isSaving = false;
    });

    _webRTCService.cleanup();
    await _initializeSession();
  }

  /// 전면 광고 로드
  void _loadInterstitialAd() {
    final String adUnitId = Platform.isAndroid
        ? dotenv.get('GOOGLE_ADMOB_INTERSTITIAL_ANDROID_ID')
        : dotenv.get('GOOGLE_ADMOB_INTERSTITIAL_IOS_ID');

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: ${error.message}');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(context.tr('voiceChat')),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_connectionState != 'Data channel opened' && !_isSaving)
              // 연결 상태 표시 위젯
              ConnectionStatusWidget(status: context.tr(_status))
            else
              // 대화 인터페이스 위젯
              ConversationInterfaceWidget(
                isInputActive: _isInputActive,
                isOutputActive: _isOutputActive,
                isConversationStarted: _isConversationStarted,
                messages: _conversationManager.conversation,
                onControllerReady: (controller) {
                  // 마운트 상태 확인
                  if (!mounted) return;

                  // 안전하게 컨트롤러 설정
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

                    // 기존 컨트롤러 처리
                    final oldController = _animationController;
                    _animationController = controller;

                    if (oldController != null && oldController != controller) {
                      try {
                        oldController.dispose();
                      } catch (e) {
                        // 오류 무시
                      }
                    }

                    if (mounted) {
                      _updateVoiceAnimation();
                    }
                  });
                },
                onSave: _saveConversation,
              ),
          ],
        ),
      ),
    );
  }
}
