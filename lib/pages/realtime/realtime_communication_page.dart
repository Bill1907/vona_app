// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// import 'package:sdp_transform/sdp_transform.dart';
import '../../core/network/http_service.dart';
import '../../core/network/network_config.dart';
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
      _updateStatus('Requesting microphone access...');

      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
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
      } catch (e) {
        if (e is WebRTCError) {
          rethrow;
        }
        throw WebRTCError('Failed to initialize session', details: e);
      }
    } catch (e, stackTrace) {
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
      print('Error initializing session: $e');
      print('Stack trace: $stackTrace');

      _showErrorDialog(errorMessage);
      _cleanupSession();
    }
  }

  void _showErrorDialog(String message) {
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
            text: '', // Start with empty text
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
          print('Error getting audio level: $e');
        }
      });
    } catch (e) {
      print('Error starting audio analysis: $e');
    }
  }

  Future<void> _stopAudioAnalysis() async {
    try {
      await platform.invokeMethod('stopAudioAnalysis');
      _audioAnalysisTimer?.cancel();
    } catch (e) {
      print('Error stopping audio analysis: $e');
    }
  }

  Future<void> _setupWebRTC() async {
    Map<String, dynamic> configuration = {
      "iceServers": _iceServers,
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      setState(() {
        _connectionState = state.toString().split('.').last;
        _updateStatus('Connection state: $_connectionState');
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
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

    _configureDataChannel(_dataChannel!);

    _peerConnection!.onDataChannel = (channel) {
      _configureDataChannel(channel);
    };

    _peerConnection?.onTrack = (event) {
      if (event.track.kind == 'audio') {
        setState(() {
          _audioElement.srcObject = event.streams[0];
        });
        _startAudioAnalysis();
      }
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

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
      final response = await http.Response.fromStream(streamedResponse);

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

        setState(() {
          if (_peerConnection?.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _connectionState = 'Connected';
            _updateStatus('Connected');
          }
        });

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error setting remote description: $e');
        rethrow;
      }
    } catch (e, stackTrace) {
      print('Error setting up WebRTC connection: $e');
      print('Stack trace: $stackTrace');
      _updateStatus('Connection failed: $e');
      throw WebRTCError('Failed to setup WebRTC connection', details: e);
    }
  }

  void _toggleConversation() async {
    print('Toggling conversation');
    if (_isDataChannelOpen && _dataChannel != null) {
      setState(() {
        _isConversationActive = !_isConversationActive;
      });

      if (_isConversationActive) {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          "type": "session.update",
          "session": {
            "modalities": ["text", "audio"],
            "tools": [],
            "input_audio_transcription": {
              "model": "whisper-1",
            },
          },
        })));
      } else {
        print('Closing conversation');
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          "type": "session.close",
        })));

        final conversationId = await ConversationService.createConversation(
            _conversation as List<dynamic>);

        print('Conversation created: $conversationId');

        await HttpService.instance.post(
          'createJournals',
          body: {
            'conversation': _conversation,
          },
          onSuccess: (data) async {
            print('API response: $data');

            // Create journal from API response
            final journal = Journal(
              keywords: List<String>.from(data['keywords']),
              emotion: data['emotion'],
              summary: data['summary'],
              conversationId: conversationId,
            );

            try {
              final createdJournal =
                  await JournalService.createJournal(journal);
              print('Journal created: ${createdJournal.id}');
            } catch (e) {
              print('Error creating journal: $e');
            }
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _connectionState != 'Connected'
                  ? Center(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Please wait a moment...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
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
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Microphone indicator
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isInputActive
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      color: _isInputActive
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    if (_isInputActive) ...[
                                      const SizedBox(width: 8),
                                      const Text('Speaking',
                                          style:
                                              TextStyle(color: Colors.green)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Center conversation control button
                              GestureDetector(
                                onDoubleTap: _toggleConversation,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isConversationActive
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.blue.withOpacity(0.2),
                                    border: Border.all(
                                      color: _isConversationActive
                                          ? Colors.red
                                          : Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    _isConversationActive
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    color: _isConversationActive
                                        ? Colors.red
                                        : Colors.blue,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Speaker indicator
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isOutputActive
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.volume_up,
                                      color: _isOutputActive
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    if (_isOutputActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 30,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          widthFactor: _currentAudioLevel,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            if (_connectionState == 'Connected') ...[
              Container(
                height: 200,
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _conversation.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversation[index];
                    final isUser = conversation.role == 'user';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.smart_toy_outlined,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    conversation.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (!conversation.isFinal &&
                                      conversation.status != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      conversation.status!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
                ? Colors.green.withOpacity(0.2)
                : isActive
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
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
      color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
    );
  }
}
