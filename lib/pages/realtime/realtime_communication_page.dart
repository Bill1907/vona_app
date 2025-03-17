// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
// import 'package:sdp_transform/sdp_transform.dart';
import '../../core/network/http_service.dart';
import 'package:flutter/services.dart';
import '../../core/models/journal.dart';
import '../../core/supabase/journal_service.dart';
import '../../core/supabase/conversation_service.dart';
import '../../core/supabase/instruction_service.dart';
import '../../widgets/voice_animations.dart';
import 'package:flutter_webrtc/src/native/audio_management.dart';
import '../../core/language/extensions.dart';

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
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _audioElement = RTCVideoRenderer();
  RTCDataChannel? _dataChannel;
  String? _ephemeralKey;
  String _connectionState = 'New';
  String _status = 'Initializing...';
  List<Map<String, dynamic>>? _iceServers;
  bool _isConversationActive = false;
  bool _isConversationStarted = false;

  // Audio analysis
  static const platform = MethodChannel('com.vona.app/audio_analysis');
  Timer? _audioAnalysisTimer;
  double _currentAudioLevel = 0.0;

  // Audio indicators
  bool _isInputActive = false;
  bool _isOutputActive = false;
  Timer? _inputIndicatorTimer;
  Timer? _outputIndicatorTimer;

  // Data channel messages
  final List<Conversation> _conversation = [];
  String? _ephemeralMessageId;
  bool _isDataChannelOpen = false;

  // Animation controller
  AnimationController? _animationController;

  // Dispose flag
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    // 객체 참조를 로컬 변수에 저장하기 전에 플래그 설정
    _isDisposing = true;

    if (_isConversationActive) {
      _isConversationActive = false;
    }

    // 타이머 즉시 취소
    _inputIndicatorTimer?.cancel();
    _outputIndicatorTimer?.cancel();
    _audioAnalysisTimer?.cancel();
    _inputIndicatorTimer = null;
    _outputIndicatorTimer = null;
    _audioAnalysisTimer = null;

    // 오디오 분석 중지
    _stopAudioAnalysis();

    // 데이터 채널 즉시 닫기 시도 (오류 무시)
    try {
      if (_dataChannel != null) {
        _dataChannel?.close();
        _dataChannel = null;
      }
    } catch (e) {
      // 오류 무시
    }

    // Peer Connection 닫기 시도 (오류 무시)
    try {
      if (_peerConnection != null) {
        _peerConnection?.close();
        _peerConnection = null;
      }
    } catch (e) {
      // 오류 무시
    }

    // 스트림 트랙 중지
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
      _localStream = null;
    } catch (e) {
      // 오류 무시
    }

    // 오디오 렌더러 dispose
    try {
      _audioElement.dispose();
    } catch (e) {
      // 오류 무시
    }

    super.dispose();
  }

  void _updateStatus(String status) {
    if (!mounted) {
      return; // Check if widget is still mounted before calling setState
    }

    setState(() {
      switch (status) {
        case 'Requesting microphone access...':
          _status = 'Checking microphone permission...';
          break;
        case 'Fetching session data...':
          _status = 'Preparing AI model...';
          break;
        case 'Establishing connection...':
          _status = 'Setting up voice chat...';
          break;
        case 'Connected':
          _status = 'Ready to start conversation!';
          break;
        case 'Data channel opened':
          _status = 'Connection established';
          break;
        default:
          if (status.startsWith('Error:')) {
            _status = 'Connection error occurred';
          } else if (status.startsWith('Connection state:')) {
            // Ignore connection state updates in status
            return;
          } else {
            _status = status;
          }
      }
    });
  }

  // 음성 애니메이션을 제어하는 메서드
  void _updateVoiceAnimation() {
    if (!mounted) return; // 위젯이 더 이상 마운트되지 않은 경우 작업 중단
    if (_animationController == null) return;

    if (_isInputActive || _isOutputActive) {
      _animationController?.repeat();
    } else if (_isConversationStarted) {
      // 대화가 시작되었지만 입력/출력이 없는 경우에는 계속 애니메이션
      _animationController?.repeat();
    } else {
      // 대화가 시작되지 않은 경우에는 애니메이션 정지
      _animationController?.stop();
    }
  }

  Future<void> _initializeSession() async {
    try {
      await _audioElement.initialize();
      // Note: RTCVideoRenderer doesn't have a volume property.
      // Volume control should be implemented on the audio tracks when received

      if (!mounted) return; // mounted 상태 확인

      _updateStatus('Requesting microphone access...');

      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });

        if (!mounted) return; // mounted 상태 확인
      } on PlatformException catch (e) {
        if (e.code == 'NotAllowedError' || e.code == 'PermissionDeniedError') {
          throw WebRTCError('Microphone permission denied', code: e.code);
        } else {
          throw WebRTCError('Failed to access microphone',
              code: e.code, details: e.message);
        }
      }

      _updateStatus('Fetching session data...');

      final instruction = await InstructionService.getInstruction(
        widget.userId,
      );

      try {
        final response = await HttpService.instance.post<Map<String, dynamic>>(
          '/webrtc/sessions',
          body: {
            'userId': widget.userId,
            'model': widget.model,
            'voice': widget.voice,
            'instructions': instruction,
          },
          headers: {
            'Content-Type': 'application/json',
          },
          onSuccess: (data) {
            if (data is! Map<String, dynamic>) {
              throw WebRTCError(
                  'Unexpected response format: ${data.runtimeType}');
            }
            return data;
          },
        );

        if (!mounted) return; // mounted 상태 확인

        if (response['client_secret'] == null) {
          throw WebRTCError('Missing client_secret in response');
        }

        if (response['client_secret']['value'] == null) {
          throw WebRTCError('Missing value in client_secret');
        }

        _ephemeralKey = response['client_secret']['value'];

        _iceServers = List<Map<String, dynamic>>.from(response['ice_servers'] ??
            [
              {"urls": "stun:stun.l.google.com:19302"}
            ]);

        _updateStatus('Establishing connection...');
        await _setupWebRTC();

        if (!mounted) return; // mounted 상태 확인
      } catch (e) {
        if (e is WebRTCError) {
          rethrow;
        }
        throw WebRTCError('Failed to initialize session', details: e);
      }
    } catch (e) {
      // 에러 처리 전에 mounted 상태 확인
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
      _cleanupSession();
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryConnection();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryConnection() async {
    if (!mounted) return;

    _cleanupSession();
    await _initializeSession();
  }

  void _cleanupSession() {
    // 기존 타이머 취소
    _inputIndicatorTimer?.cancel();
    _outputIndicatorTimer?.cancel();
    _audioAnalysisTimer?.cancel();

    // 오디오 분석 중지
    _stopAudioAnalysis();

    // 데이터 채널 닫기 시도
    try {
      if (_dataChannel != null) {
        // 리스너 제거 시도
        _dataChannel!.onDataChannelState = null;
        _dataChannel!.onMessage = null;

        _dataChannel!.close();
      }
    } catch (e) {
      // 오류 무시
    } finally {
      // 무조건 참조 제거
      _dataChannel = null;
    }

    // Peer Connection 닫기 시도
    try {
      if (_peerConnection != null) {
        // 리스너 제거 시도
        _peerConnection!.onConnectionState = null;
        _peerConnection!.onIceConnectionState = null;
        _peerConnection!.onIceGatheringState = null;
        _peerConnection!.onIceCandidate = null;
        _peerConnection!.onDataChannel = null;
        _peerConnection!.onTrack = null;

        _peerConnection!.close();
      }
    } catch (e) {
      // 오류 무시
    } finally {
      // 무조건 참조 제거
      _peerConnection = null;
    }

    // 로컬 스트림 처리
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        _localStream!.dispose();
      }
    } catch (e) {
      // 오류 무시
    } finally {
      // 무조건 참조 제거
      _localStream = null;
    }

    // 상태 플래그 업데이트
    _isDataChannelOpen = false;
  }

  void _configureDataChannel(RTCDataChannel channel) {
    if (_isDisposing) {
      return;
    }

    // 이전 리스너 제거 시도 (명시적으로)
    try {
      channel.onDataChannelState = null;
      channel.onMessage = null;
    } catch (e) {
      // 오류 무시
    }

    // 데이터 채널 상태 변경 이벤트 처리
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (_isDisposing || !mounted) {
        return;
      }

      // setState는 try-catch로 보호
      try {
        setState(() {
          _isDataChannelOpen = state == RTCDataChannelState.RTCDataChannelOpen;
        });
      } catch (e) {
        // 오류 무시
      }

      if (_isDataChannelOpen) {
        _updateStatus('Data channel opened');

        // 지연 시작으로 경쟁 조건 방지
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted &&
              !_isDisposing &&
              _isDataChannelOpen &&
              _dataChannel != null) {
            _startConversation();
          }
        });
      } else if (state == RTCDataChannelState.RTCDataChannelClosed ||
          state == RTCDataChannelState.RTCDataChannelClosing) {
        // 지연 시간을 두고 재연결 시도 (경쟁 조건 방지)
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && !_isDisposing) {
            _checkConnectionAndReconnect();
          }
        });
      }
    };

    // 데이터 채널 메시지 처리
    channel.onMessage = (RTCDataChannelMessage message) {
      if (_isDisposing || !mounted) {
        return;
      }

      try {
        final data = jsonDecode(message.text);
        if (mounted && !_isDisposing) {
          _handleDataChannelMessage(data);
        }
      } catch (e) {
        // 오류 무시
      }
    };
  }

  void _updateEphemeralMessage(String? text, {bool? isFinal, String? status}) {
    if (!mounted || _ephemeralMessageId == null) return;

    setState(() {
      final index =
          _conversation.indexWhere((msg) => msg.id == _ephemeralMessageId);
      if (index != -1) {
        _conversation[index] = _conversation[index].copyWith(
          text: text ?? '',
          isFinal: isFinal ?? false,
          status: status,
        );
      }
    });
  }

  void _handleDataChannelMessage(Map<String, dynamic> data) {
    if (!mounted) return; // 위젯이 더 이상 마운트되지 않은 경우 작업 중단

    final messageType = data['type'] as String;

    switch (messageType) {
      case 'input_audio_buffer.speech_started':
        setState(() {
          _isInputActive = true;
          // Add a new user message when speech starts
          _ephemeralMessageId =
              DateTime.now().millisecondsSinceEpoch.toString();
          _conversation.add(Conversation(
            id: _ephemeralMessageId!,
            role: 'user',
            text: '', // Start with empty text
            timestamp: DateTime.now().toIso8601String(),
            status: 'speaking',
          ));

          // 대화가 시작되었음을 표시
          _isConversationStarted = true;
        });
        _updateVoiceAnimation();
        break;

      case 'input_audio_buffer.speech_stopped':
        setState(() {
          _isInputActive = false;
        });
        _updateVoiceAnimation();
        _updateEphemeralMessage('',
            status: 'processing'); // Keep the text, just update status
        break;

      case 'input_audio_buffer.committed':
        _updateEphemeralMessage(null,
            status: 'processing'); // Keep the text, just update status
        break;

      case 'conversation.item.input_audio_transcription':
        final transcript = data['transcript'] ?? data['text'] ?? '';
        if (transcript.isNotEmpty) {
          _updateEphemeralMessage(
            transcript,
            status: 'speaking',
            isFinal: false,
          );
        }
        break;

      case 'conversation.item.input_audio_transcription.completed':
        final transcript = data['transcript'] as String? ?? '';
        if (transcript.isNotEmpty) {
          _updateEphemeralMessage(
            transcript,
            status: null, // Remove the status when final
            isFinal: true,
          );
        } else {
          // If transcript is empty, remove the message
          setState(() {
            _conversation.removeWhere((msg) => msg.id == _ephemeralMessageId);
          });
        }
        _ephemeralMessageId = null;
        break;

      case 'response.audio_transcript.delta':
        final delta = data['delta'] as String;

        setState(() {
          _isOutputActive = true;
          if (_outputIndicatorTimer?.isActive ?? false) {
            _outputIndicatorTimer!.cancel();
          }
          _outputIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return; // 타이머 콜백에서 마운트 여부 확인
            setState(() {
              _isOutputActive = false;
            });
            _updateVoiceAnimation();
          });

          if (_conversation.isNotEmpty &&
              _conversation.last.role == 'assistant' &&
              !_conversation.last.isFinal) {
            final lastMsg = _conversation.last;
            _conversation[_conversation.length - 1] = lastMsg.copyWith(
              text: '${lastMsg.text}$delta',
            );
          } else {
            _conversation.add(Conversation(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: 'assistant',
              text: delta,
              timestamp: DateTime.now().toIso8601String(),
              isFinal: false,
            ));
          }
        });
        _updateVoiceAnimation();
        break;

      case 'response.audio_transcript.done':
        setState(() {
          if (_conversation.isNotEmpty) {
            final lastMsg = _conversation.last;
            _conversation[_conversation.length - 1] = lastMsg.copyWith(
              isFinal: true,
            );
          }
        });
        break;
    }
  }

  Future<void> _startAudioAnalysis() async {
    try {
      await platform.invokeMethod('startAudioAnalysis');

      _audioAnalysisTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          if (!mounted) return; // 타이머 콜백에서 마운트 여부 확인

          final audioLevel = await platform.invokeMethod('getAudioLevel');
          setState(() {
            _currentAudioLevel = audioLevel;
            _isOutputActive =
                audioLevel > 0.1; // Threshold for activity detection
          });
        } catch (e) {
          // Error handling
        }
      });
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _stopAudioAnalysis() async {
    try {
      await platform.invokeMethod('stopAudioAnalysis');
      _audioAnalysisTimer?.cancel();
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _setupWebRTC() async {
    try {
      Map<String, dynamic> configuration = {
        "iceServers": _iceServers,
      };

      _peerConnection = await createPeerConnection(configuration);
      if (!mounted) return; // mounted 상태 확인

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (!mounted) return; // mounted 상태 확인

        setState(() {
          _connectionState = state.toString().split('.').last;
          _updateStatus('Connection state: $_connectionState');
        });

        // 연결이 끊어진 경우 재연결 검토
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _checkConnectionAndReconnect();
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (!mounted) return; // mounted 상태 확인

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          setState(() {
            _connectionState = 'Connected';
            _updateStatus('Connected');
          });
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          setState(() {
            _connectionState = 'Failed';
            _updateStatus('Connection failed');
          });
          _checkConnectionAndReconnect();
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        // ICE 수집 상태 변경 처리
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        // ICE 후보 처리
      };

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      final dataChannelInit = RTCDataChannelInit()
        ..ordered = true
        ..protocol = 'oai-events';

      _dataChannel = await _peerConnection!.createDataChannel(
        'oai-events',
        dataChannelInit,
      );
      if (!mounted) return; // mounted 상태 확인

      _configureDataChannel(_dataChannel!);

      _peerConnection!.onDataChannel = (channel) {
        if (!mounted) return; // mounted 상태 확인
        _configureDataChannel(channel);
      };

      _peerConnection?.onTrack = (event) {
        if (!mounted) return;

        event.streams[0].getAudioTracks().forEach((track) {
          // Enable audio track
          try {
            track.enabled = true;

            // NativeAudioManagement의 setVolume 메서드 사용
            NativeAudioManagement.setVolume(4.0, track).then((_) {
              // 볼륨 설정 성공
            }).catchError((e) {
              // 볼륨 설정 실패
            });
          } catch (e) {
            // 오류 무시
          }
        });

        if (event.track.kind == 'audio') {
          setState(() {
            _audioElement.srcObject = event.streams[0];
          });
          _startAudioAnalysis();
        }
      };

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      if (!mounted) return; // mounted 상태 확인

      await _peerConnection!.setLocalDescription(offer);
      if (!mounted) return; // mounted 상태 확인

      try {
        final url = Uri.parse('https://api.openai.com/v1/realtime');
        final queryParams = {
          'model': widget.model,
        };
        final fullUrl = url.replace(queryParameters: queryParams);

        final request = http.Request('POST', fullUrl);
        request.headers['Authorization'] = 'Bearer $_ephemeralKey';
        request.headers['Content-Type'] = 'application/sdp';
        request.headers['Accept'] = 'application/sdp';

        request.bodyBytes = offer.sdp!.codeUnits;

        final streamedResponse = await request.send();
        if (!mounted) return; // mounted 상태 확인

        final response = await http.Response.fromStream(streamedResponse);
        if (!mounted) return; // mounted 상태 확인

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception(
              'Failed to connect: ${response.statusCode} ${response.body}');
        }

        try {
          final answerSdp = response.body.trim();

          if (!answerSdp.startsWith('v=0')) {
            throw Exception('Invalid SDP answer format');
          }

          final normalizedSdp =
              '${answerSdp.split('\n').map((line) => line.trim()).join('\r\n').trimRight()}\r\n';

          final answer = RTCSessionDescription(
            normalizedSdp,
            'answer',
          );

          if (answer.sdp == null || answer.type == null) {
            throw Exception('Failed to create valid RTCSessionDescription');
          }

          if (_peerConnection == null) {
            throw Exception('PeerConnection is null');
          }

          await _peerConnection!.setRemoteDescription(answer);
          if (!mounted) return; // mounted 상태 확인

          setState(() {
            if (_peerConnection?.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
              _connectionState = 'Connected';
              _updateStatus('Connected');
            }
          });

          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return; // mounted 상태 확인
        } catch (e) {
          throw e;
        }
      } catch (e) {
        if (!mounted) return; // mounted 상태 확인

        _updateStatus('Connection failed: $e');
        throw WebRTCError('Failed to setup WebRTC connection', details: e);
      }
    } catch (e) {
      if (mounted) {
        _updateStatus('WebRTC setup error: $e');
      }
      rethrow;
    }
  }

  // _safelySendMessage에 dispose 체크 추가
  bool _safelySendMessage(dynamic message) {
    try {
      if (_isDisposing) {
        return false;
      }

      if (!mounted || _dataChannel == null) {
        return false;
      }

      // 현재 데이터 채널 상태 가져오기
      final RTCDataChannelState? state = _dataChannel?.state;

      if (state != RTCDataChannelState.RTCDataChannelOpen) {
        return false;
      }

      // JSON으로 변환
      final messageStr = message is String ? message : jsonEncode(message);

      // 데이터 채널로 메시지 전송 (try-catch로 감싸기)
      try {
        _dataChannel?.send(RTCDataChannelMessage(messageStr));
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void _startConversation() {
    if (_isDisposing) {
      return;
    }

    if (_dataChannel != null && !_isConversationActive) {
      final bool isOpen =
          _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

      if (!isOpen) {
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted && !_isDisposing) {
            _checkConnectionAndReconnect();
          }
        });
        return;
      }

      try {
        setState(() {
          _isConversationActive = true;
        });
      } catch (e) {
        // 오류 무시
      }

      _fetchAndSendSessionUpdate();
    }
  }

  Future<void> _fetchAndSendSessionUpdate() async {
    try {
      // 최근 7일간의 저널 가져오기
      final journals = await JournalService.getRecentJournals(days: 7);

      if (!mounted) return;

      // 시스템 메시지 내용 준비
      String systemContent =
          "You are a helpful assistant that listens to the user's day and provides thoughtful responses. ";

      if (journals.isNotEmpty) {
        // 저널 수를 최대 3개로 제한
        final limitedJournals = journals.take(3).toList();

        if (limitedJournals.isNotEmpty) {
          systemContent +=
              "You have access to these summaries of the user's past conversations: ";

          for (int i = 0; i < limitedJournals.length; i++) {
            final journal = limitedJournals[i];

            // 저널 내용 길이 제한 (최대 50자)
            String limitedContent = journal.content;
            if (limitedContent.length > 50) {
              limitedContent = limitedContent.substring(0, 47) + "...";
            }

            // 간결한 형식으로 저널 정보 포함
            systemContent +=
                "[${journal.createdAt.month}/${journal.createdAt.day}: ${journal.title}, emotion: ${journal.emotion}] ";
          }

          systemContent += "Connect with these past experiences when relevant.";
        }
      }

      print(
          'System message (${systemContent.length} chars): ${systemContent.substring(0, min(50, systemContent.length))}...');

      // 세션 업데이트에 시스템 메시지 포함하지 않고 기본 설정만 전송
      final bool sessionSent = _safelySendMessage({
        "type": "session.update",
        "session": {
          "modalities": ["text", "audio"],
          "tools": [],
          "input_audio_transcription": {
            "model": "whisper-1",
          },
        },
      });

      if (!sessionSent) {
        print('Failed to send session update, checking connection');
        _checkConnectionAndReconnect();
        return;
      }

      // 잠시 기다려서 세션 설정이 적용되도록 함
      await Future.delayed(Duration(milliseconds: 500));

      // 첫 메시지에 시스템 지침 포함 (올바른 형식으로)
      if (!mounted) return;

      // 안전하게 첫 메시지와 시스템 지침 전송 (올바른 형식으로)
      final messageSent = _safelySendMessage({
        "type": "conversation.item.create",
        "item": {
          "type": "message",
          "role": "system",
          "content": [
            {"type": "input_text", "text": systemContent}
          ],
        }
      });

      if (!messageSent) {
        print('Failed to send first message, checking connection');
        _checkConnectionAndReconnect();
        return;
      }

      // 응답이 없는 경우를 위한 백업 메시지 (더 짧은 시간 내에)
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted || _dataChannel == null) return;

        // 데이터 채널 상태 다시 확인
        final isStillOpen =
            _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
        if (!isStillOpen) {
          print('Data channel no longer open, cannot send follow-up message');
          return;
        }

        if (!_isOutputActive) {
          print("No response detected after 2.5s, sending follow-up message");
          _safelySendMessage({
            "type": "conversation.item.create",
            "item": {
              "type": "message",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "Can you help me reflect on my day?"
                }
              ]
            }
          });
        }
      });
    } catch (e) {
      print('Error in _fetchAndSendSessionUpdate: $e');
      // 기본 방식으로 시도
      _sendBasicSystemMessage();
    }
  }

  void _sendBasicSystemMessage() {
    try {
      print('Sending basic system message (fallback)');

      // 안전하게 세션 업데이트 전송
      final sessionSent = _safelySendMessage({
        "type": "session.update",
        "session": {
          "modalities": ["text", "audio"],
          "tools": [],
          "input_audio_transcription": {
            "model": "whisper-1",
          },
        },
      });

      if (!sessionSent) {
        print('Failed to send basic session update, checking connection');
        _checkConnectionAndReconnect();
        return;
      }
    } catch (e) {
      print('Error in _sendBasicSystemMessage: $e');
      _checkConnectionAndReconnect();
    }
  }

  // 연결 상태 확인 및 필요시 재연결 시도
  void _checkConnectionAndReconnect() {
    if (!mounted) return;

    print(
        'Checking WebRTC connection status: $_connectionState, dataChannel state: ${_dataChannel?.state}');

    // 이미 재연결 시도 중인지 확인
    if (_connectionState == 'Connecting' ||
        _connectionState == 'New' ||
        _connectionState == 'Reconnecting') {
      print('Already attempting to reconnect, skipping');
      return;
    }

    // 데이터 채널이 닫혔거나 연결이 끊어진 경우 재연결 시도
    if (_connectionState == 'Failed' ||
        _connectionState == 'Disconnected' ||
        _connectionState == 'Closed' ||
        _dataChannel == null ||
        _dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      print('Connection appears to be broken, attempting to reconnect');

      // 상태 업데이트
      setState(() {
        _isConversationActive = false;
        _connectionState = 'Reconnecting';
        _updateStatus('Reconnecting...');
      });

      // 기존 연결 정리
      _cleanupSession();

      // 재연결 시도
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _initializeSession();
        }
      });
    }
  }

  // Helper method to escape strings for JSON
  String _escapeString(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  void _stopConversation() async {
    if (_dataChannel == null || !_isConversationActive) {
      return;
    }

    // 데이터 채널 상태 확인
    final isDataChannelOpen =
        _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
    if (!isDataChannelOpen) {
      print('Data channel not open, cannot stop conversation properly');
      // 연결이 끊어진 상태에서도 대화 내용을 저장하도록 진행
    }

    try {
      // Check if widget is still mounted before showing dialog
      if (!mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Close the WebRTC session first
      try {
        if (isDataChannelOpen) {
          _safelySendMessage({
            "type": "session.close",
          });
        }
      } catch (e) {
        print('Error closing session: $e');
      }

      // Wait a bit for the session to close properly
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Create conversation only if we have messages
      if (_conversation.isEmpty) {
        if (!mounted) return;
        // Pop the dialog if mounted
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Remove loading indicator
        }
        return;
      }

      // Convert conversation to JSON format
      final conversationData =
          _conversation.map((msg) => msg.toJson()).toList();

      // Save conversation
      final conversationId = await ConversationService.createConversation(
        conversationData,
      ).catchError((error) {
        throw Exception('Failed to save conversation');
      });

      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Create journal
      await HttpService.instance.post(
        'journals',
        body: {
          'conversation': conversationData,
        },
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        onSuccess: (data) async {
          if (data == null) {
            throw Exception('Failed to process conversation');
          }
          try {
            // Ensure proper decoding of Korean text
            // Parse and print the JSON data in a more readable format
            final keywords =
                (data['keywords'] as List<dynamic>?)?.map((keyword) {
                      if (keyword is String) {
                        try {
                          // Try to properly decode Korean text if needed
                          final decodedKeyword =
                              utf8.decode(utf8.encode(keyword));
                          return decodedKeyword;
                        } catch (e) {
                          return keyword;
                        }
                      }
                      return keyword.toString();
                    }).toList() ??
                    [];

            final title = data['title'] != null
                ? utf8.decode(utf8.encode(data['title'] as String))
                : 'Untitled Journal';

            final content = data['content'] != null
                ? utf8.decode(utf8.encode(data['content'] as String))
                : '';

            final journal = Journal(
              keywords: keywords,
              emotion: data['emotion'] ?? 'neutral',
              title: title,
              content: content,
              conversationId: conversationId,
            );

            await JournalService.createJournal(journal);

            // Check if widget is still mounted
            if (!mounted) return;

            // Update UI state after successful save
            setState(() {
              _isConversationActive = false;
              _conversation.clear();
            });

            // Remove loading indicator (check mounted and canPop first)
            if (mounted && context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            // Show success message and navigate (check mounted first)
            if (mounted && context.mounted) {
              // Use a post-frame callback to ensure we're in a safe frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conversation saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.of(context).pushReplacementNamed('/');
                }
              });
            }
          } catch (e) {
            throw Exception('Failed to create journal');
          }
        },
      );
    } catch (e) {
      // Check if widget is still mounted
      if (!mounted) return;

      // Remove loading indicator if it's showing
      if (mounted && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message to user
      if (mounted && context.mounted) {
        // Use a post-frame callback for Scaffold operations
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
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
            if (_connectionState != 'Connected')
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF3A70EF)),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please wait a moment...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepIndicator(
                            'Mic',
                            Icons.mic,
                            _status.contains('microphone') ||
                                _status.contains('Mic'),
                            _status.contains('AI') ||
                                _status.contains('voice') ||
                                _status.contains('Ready'),
                          ),
                          _buildStepConnector(
                            _status.contains('AI') ||
                                _status.contains('voice') ||
                                _status.contains('Ready'),
                          ),
                          _buildStepIndicator(
                            'AI Model',
                            Icons.psychology,
                            _status.contains('AI'),
                            _status.contains('voice') ||
                                _status.contains('Ready'),
                          ),
                          _buildStepConnector(
                            _status.contains('voice') ||
                                _status.contains('Ready'),
                          ),
                          _buildStepIndicator(
                            'Voice Chat',
                            Icons.chat,
                            _status.contains('voice') ||
                                _status.contains('Ready'),
                            _status.contains('Ready'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // 메인 화면 (항상 애니메이션과 텍스트만 표시)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 상단 공간
                        const Spacer(flex: 1),

                        // 중앙에 Lottie 애니메이션
                        Center(
                          child: LottieVoiceAnimationWithController(
                            width: 210,
                            height: 210,
                            backgroundColor: Colors.transparent,
                            useDarkBackground: false,
                            ringColor: _isInputActive
                                ? Color.fromRGBO(
                                    244, 67, 54, 0.8) // 사용자 입력 시 빨간색
                                : _isOutputActive
                                    ? Color(0xFF3A70EF) // AI 출력 시 파란색
                                    : Color(0xFF3A70EF), // 평소에는 파란색
                            autoPlay: _isConversationStarted &&
                                !_isInputActive, // 대화가 시작되고 입력이 없을 때만 애니메이션 재생
                            onControllerReady: (controller) {
                              // Widget이 마운트된 상태인지 확인
                              if (!mounted) return;

                              // 새 컨트롤러를 안전하게 설정
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;

                                // 기존 컨트롤러가 있다면 안전하게 dispose
                                final oldController = _animationController;
                                _animationController = controller;

                                if (oldController != null &&
                                    oldController != controller) {
                                  try {
                                    oldController.dispose();
                                  } catch (e) {
                                    print('Error disposing old controller: $e');
                                  }
                                }

                                // 상태가 마운트 되어있는지 다시 확인 후 애니메이션 업데이트
                                if (mounted) {
                                  _updateVoiceAnimation();
                                }
                              });
                            },
                          ),
                        ),

                        // 상태에 따른 텍스트 표시
                        const SizedBox(height: 86),
                        Text(
                          _isConversationStarted
                              ? (_isInputActive
                                  ? "Listening..."
                                  : _isOutputActive
                                      ? "Speaking..."
                                      : "How can I help?")
                              : "How was your day today?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'poppins',
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // 서브 텍스트
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _isConversationStarted
                                ? "Your conversation will be saved when you press the Save button"
                                : "Talk freely about your feelings and feel the feelings you felt today, check your emotions and see what you have spent.",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              height: 1.5,
                              fontFamily: 'poppins',
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        // 하단 공간
                        const Spacer(flex: 1),

                        // Save 버튼
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          child: ElevatedButton(
                            onPressed: _stopConversation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3A70EF),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              "Save",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
      String label, IconData icon, bool isActive, bool isComplete) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete
                ? Color.fromRGBO(76, 175, 80, 0.2)
                : isActive
                    ? Color.fromRGBO(33, 150, 243, 0.2)
                    : Color.fromRGBO(158, 158, 158, 0.1),
            border: Border.all(
              color: isComplete
                  ? Colors.green
                  : isActive
                      ? Colors.blue
                      : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isComplete
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isComplete
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isActive ? Colors.green : Color.fromRGBO(158, 158, 158, 0.3),
    );
  }
}
