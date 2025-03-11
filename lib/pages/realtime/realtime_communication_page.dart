// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// import 'package:sdp_transform/sdp_transform.dart';
import '../../core/network/http_service.dart';
import 'package:flutter/services.dart';
import '../../core/models/journal.dart';
import '../../core/supabase/journal_service.dart';
import '../../core/supabase/conversation_service.dart';
import '../../widgets/voice_animations.dart';
import 'package:flutter_webrtc/src/native/audio_management.dart';

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
    this.model = "gpt-4o-mini-realtime-preview-2024-12-17",
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

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    // 화면을 나가는 시점에서 모든 작업 취소
    if (_isConversationActive) {
      _isConversationActive = false;
    }

    // 객체 참조를 로컬 변수에 저장
    final audioElement = _audioElement;
    final peerConnection = _peerConnection;
    final localStream = _localStream;
    final dataChannel = _dataChannel;
    final controller = _animationController;

    // 변경 가능한 객체들만 null로 설정
    _peerConnection = null;
    _localStream = null;
    _dataChannel = null;
    _animationController = null;

    // 타이머 취소
    _inputIndicatorTimer?.cancel();
    _outputIndicatorTimer?.cancel();
    _audioAnalysisTimer?.cancel();
    _inputIndicatorTimer = null;
    _outputIndicatorTimer = null;
    _audioAnalysisTimer = null;

    // 오디오 분석 중지
    _stopAudioAnalysis();

    // 위젯 트리에서 실행될 때까지 대기하여 dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 이제 안전하게 dispose 가능
      try {
        audioElement.dispose();
      } catch (e) {
        print('Error disposing audioElement: $e');
      }

      try {
        peerConnection?.dispose();
      } catch (e) {
        print('Error disposing peerConnection: $e');
      }

      try {
        localStream?.dispose();
      } catch (e) {
        print('Error disposing localStream: $e');
      }

      try {
        dataChannel?.close();
      } catch (e) {
        print('Error closing dataChannel: $e');
      }

      try {
        controller?.dispose();
      } catch (e) {
        print('Error disposing animationController: $e');
      }
    });

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
          'audio': {'sampleRate': 44100, 'channelCount': 2},
          // 'audio': true,
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

      final apiUrl = '/getWebRTCSession';
      _updateStatus('Fetching session data...');

      try {
        final response = await HttpService.instance.post<Map<String, dynamic>>(
          apiUrl,
          body: {
            'userId': widget.userId,
            'model': widget.model,
            'voice': widget.voice,
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
    _peerConnection?.dispose();
    _localStream?.dispose();
    _dataChannel?.close();
    _peerConnection = null;
    _localStream = null;
    _dataChannel = null;
  }

  void _configureDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (!mounted) return;

      setState(() {
        _isDataChannelOpen = state == RTCDataChannelState.RTCDataChannelOpen;
      });

      if (_isDataChannelOpen) {
        _updateStatus('Data channel opened');
        // Start conversation when data channel is open
        _startConversation();
      }
    };

    channel.onMessage = (RTCDataChannelMessage message) {
      if (!mounted) return;

      final data = jsonDecode(message.text);
      _handleDataChannelMessage(data);
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
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (!mounted) return; // mounted 상태 확인

      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        setState(() {
          _connectionState = 'Connected';
          _updateStatus('Connected');
        });
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() {
          _connectionState = 'Failed';
          _updateStatus('Connection failed');
        });
      }
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
            print('Successfully set volume to 4.0');
          }).catchError((e) {
            print('Error setting volume with NativeAudioManagement: $e');
          });
        } catch (e) {
          print('Error configuring audio track: $e');
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
        rethrow;
      }
    } catch (e) {
      if (!mounted) return; // mounted 상태 확인

      _updateStatus('Connection failed: $e');
      throw WebRTCError('Failed to setup WebRTC connection', details: e);
    }
  }

  void _startConversation() {
    if (_isDataChannelOpen && _dataChannel != null && !_isConversationActive) {
      setState(() {
        _isConversationActive = true;
      });

      final sessionUpdateMessage = jsonEncode({
        "type": "session.update",
        "session": {
          "modalities": ["text", "audio"],
          "tools": [],
          "input_audio_transcription": {
            "model": "whisper-1",
          },
        },
      });

      _dataChannel!.send(RTCDataChannelMessage(sessionUpdateMessage));
    }
  }

  void _stopConversation() async {
    if (!_isDataChannelOpen || _dataChannel == null || !_isConversationActive) {
      return;
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
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          "type": "session.close",
        })));
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
        'createJournals',
        body: {
          'conversation': conversationData,
          'conversationId': conversationId,
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
        title: const Text(
          'Voice',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: 'poppins',
            letterSpacing: -0.3,
          ),
        ),
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
