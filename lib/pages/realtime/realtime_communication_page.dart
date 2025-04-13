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

class RealtimeCommunicationPage extends StatefulWidget {
  final String userId;
  final String model;
  final String voice;

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
  late WebRTCService _webRTCService;
  late AudioService _audioService;
  late ConversationManager _conversationManager;

  final _audioElement = RTCVideoRenderer();
  String _status = 'Initializing...';
  String _connectionState = 'New';
  bool _isInputActive = false;
  bool _isOutputActive = false;
  bool _isConversationStarted = false;
  bool _isSaving = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _setupServices();
    _initializeSession();
    _loadInterstitialAd();

    _status = 'initializing';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!mounted) return;

    if (_conversationManager != null) {
      final locale = Localizations.localeOf(context);
      final newLanguageCode = locale.languageCode;

      if (_conversationManager.languageCode != newLanguageCode) {
        _conversationManager.languageCode = newLanguageCode;
      }
    }
  }

  @override
  void dispose() {
    _isSaving = false;
    _audioService.dispose();
    _webRTCService.dispose();
    _conversationManager.dispose();
    _audioElement.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _setupServices() {
    _webRTCService = WebRTCService(
      onConnectionStateChanged: _handleConnectionStateChanged,
      onAudioTrackReceived: _handleAudioTrackReceived,
    );
    _webRTCService.setAudioRenderer(_audioElement);

    _audioService = AudioService(
      onInputStatusChanged: _handleInputStatusChanged,
      onOutputStatusChanged: _handleOutputStatusChanged,
    );

    _conversationManager = ConversationManager(
      _webRTCService,
      onConversationStateChanged: _handleConversationStateChanged,
      onConversationUpdated: _handleConversationUpdated,
      onSaved: _handleConversationSaved,
      onError: _handleConversationError,
    );
  }

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

  void _handleConnectionStateChanged(String state) {
    if (!mounted) return;

    setState(() {
      _connectionState = state;
      _updateStatus(state);
    });
  }

  void _handleAudioTrackReceived(MediaStream stream) {
    if (!mounted) return;

    setState(() {
      _audioElement.srcObject = stream;
    });

    _audioService.startAudioAnalysis();
  }

  void _handleInputStatusChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isInputActive = isActive;
    });

    _updateVoiceAnimation();
  }

  void _handleOutputStatusChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isOutputActive = isActive;
    });

    _updateVoiceAnimation();
  }

  void _handleConversationStateChanged(bool isActive) {
    if (!mounted) return;

    setState(() {
      _isConversationStarted = isActive;
    });
  }

  void _handleConversationUpdated(List<ConversationMessage> messages) {
    if (mounted) {
      setState(() {});
    }
  }

  void _saveConversation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    setState(() {
      _isSaving = true;
    });

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _saveConversationToServer();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          _saveConversationToServer();
        },
      );
      await _interstitialAd!.show();
    } else {
      _saveConversationToServer();
    }
  }

  Future<void> _saveConversationToServer() async {
    try {
      await _conversationManager.stopAndSaveConversation(context);

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

  void _handleConversationSaved() {
    if (!mounted) return;

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

  void _handleConversationError() {
    if (!mounted) return;

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
            return;
          } else {
            _status = status;
          }
      }
    });
  }

  void _updateVoiceAnimation() {
    if (!mounted || _animationController == null) return;

    if (_isInputActive || _isOutputActive) {
      _animationController!.repeat();
    } else if (_isConversationStarted) {
      _animationController!.repeat();
    } else {
      _animationController!.stop();
    }
  }

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

  Future<void> _retryConnection() async {
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    _webRTCService.cleanup();
    await _initializeSession();
  }

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
    String fontFam = 'Poppins';
    if (Localizations.localeOf(context).languageCode == 'ko') {
      fontFam = 'Pretendard';
    }
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          context.tr('voiceChat'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            fontFamily: fontFam,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_connectionState != 'Data channel opened' && !_isSaving)
              ConnectionStatusWidget(status: context.tr(_status))
            else
              ConversationInterfaceWidget(
                isInputActive: _isInputActive,
                isOutputActive: _isOutputActive,
                isConversationStarted: _isConversationStarted,
                messages: _conversationManager.conversation,
                onControllerReady: (controller) {
                  if (!mounted) return;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

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
