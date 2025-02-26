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

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _audioElement.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    _dataChannel?.close();
    _inputIndicatorTimer?.cancel();
    _outputIndicatorTimer?.cancel();
    _audioAnalysisTimer?.cancel();
    _stopAudioAnalysis();
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

  Future<void> _initializeSession() async {
    try {
      await _audioElement.initialize();
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
      final data = jsonDecode(message.text);
      _handleDataChannelMessage(data);
    };
  }

  void _updateEphemeralMessage(String? text, {bool? isFinal, String? status}) {
    if (_ephemeralMessageId == null) return;

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
            text: 'hi', // Start with empty text
            timestamp: DateTime.now().toIso8601String(),
            status: 'speaking',
          ));
        });
        break;

      case 'input_audio_buffer.speech_stopped':
        setState(() {
          _isInputActive = false;
        });
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
            setState(() {
              _isOutputActive = false;
            });
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
      if (!mounted) return; // mounted 상태 확인

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
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
        "type": "session.close",
      })));

      // Wait a bit for the session to close properly
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if widget is still mounted
      if (!mounted) return;

      // Create conversation only if we have messages
      if (_conversation.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Remove loading indicator
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

      // Check if widget is still mounted
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

            // Remove loading indicator
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            // Show success message and navigate
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation saved successfully!'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.of(context).pushReplacementNamed('/');
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
      if (Navigator.of(context).canPop() && context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const CircularProgressIndicator(),
                      const SizedBox(height: 32),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please wait a moment...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Microphone indicator with animation
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isInputActive
                                ? const Color.fromRGBO(76, 175, 80, 0.2)
                                : const Color.fromRGBO(158, 158, 158, 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isInputActive)
                                    ...List.generate(3, (index) {
                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 1000),
                                        curve: Curves.easeInOut,
                                        width: 24.0 + (index * 8.0),
                                        height: 24.0 + (index * 8.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.green.withOpacity(
                                            0.3 - (index * 0.1),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  Icon(
                                    Icons.mic,
                                    color: _isInputActive
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                              if (_isInputActive) ...[
                                const SizedBox(width: 8),
                                const Text('Speaking',
                                    style: TextStyle(color: Colors.green)),
                              ],
                            ],
                          ),
                        ),
                        // Speaker indicator with animation
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isOutputActive
                                ? const Color.fromRGBO(33, 150, 243, 0.2)
                                : const Color.fromRGBO(158, 158, 158, 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isOutputActive)
                                    ...List.generate(3, (index) {
                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 1000),
                                        curve: Curves.easeInOut,
                                        width: 24.0 + (index * 8.0),
                                        height: 24.0 + (index * 8.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue.withOpacity(
                                            0.3 - (index * 0.1),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  Icon(
                                    Icons.volume_up,
                                    color: _isOutputActive
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                              if (_isOutputActive) ...[
                                const SizedBox(width: 8),
                                const Text('Speaking',
                                    style: TextStyle(color: Colors.blue)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            // Center stop button
            if (_connectionState == 'Connected')
              Center(
                child: GestureDetector(
                  onTap: _stopConversation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromRGBO(244, 67, 54, 0.2),
                      border: Border.all(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ),
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
