import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/src/native/audio_management.dart';
import 'package:http/http.dart' as http;
import '../network/http_service.dart';
import '../models/webrtc_error.dart';

/// WebRTC 연결 상태 변경 콜백 타입
typedef WebRTCConnectionStateCallback = void Function(String state);

/// WebRTC 데이터 메시지 콜백 타입
typedef WebRTCMessageCallback = void Function(Map<String, dynamic> data);

/// WebRTC 오디오 트랙 콜백 타입
typedef WebRTCAudioTrackCallback = void Function(MediaStream stream);

/// WebRTC 서비스 클래스
///
/// WebRTC 연결 설정, 데이터 채널 관리, 메시지 송수신을 담당합니다.
class WebRTCService {
  // WebRTC 연결 관련
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer? _audioElement;
  RTCDataChannel? _dataChannel;
  String? _ephemeralKey;
  String _connectionState = 'New';
  List<Map<String, dynamic>>? _iceServers;
  bool _isDataChannelOpen = false;
  bool _isDisposing = false;

  // 콜백 함수들
  WebRTCConnectionStateCallback? onConnectionStateChanged;
  WebRTCMessageCallback? onMessageReceived;
  WebRTCAudioTrackCallback? onAudioTrackReceived;
  VoidCallback? onDataChannelOpened;

  /// WebRTC 서비스 생성자
  WebRTCService({
    this.onConnectionStateChanged,
    this.onMessageReceived,
    this.onAudioTrackReceived,
    this.onDataChannelOpened,
  });

  /// 현재 연결 상태 반환
  String get connectionState => _connectionState;

  /// 데이터 채널 열림 여부
  bool get isDataChannelOpen => _isDataChannelOpen;

  /// 세션 초기화
  Future<void> initializeSession({
    required String userId,
    required String model,
    required String voice,
    required dynamic instructions,
  }) async {
    try {
      if (_audioElement != null) {
        await _audioElement!.initialize();
      }

      _updateConnectionState('Requesting microphone access...');

      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
      } on Exception catch (e) {
        if (e.toString().contains('NotAllowedError') ||
            e.toString().contains('PermissionDeniedError')) {
          throw WebRTCError.microphonePermissionDenied(e.toString());
        } else {
          throw WebRTCError.microphoneAccessFailed(e.toString(), e);
        }
      }

      _updateConnectionState('Fetching session data...');

      try {
        final response = await HttpService.instance.post<Map<String, dynamic>>(
          '/webrtc/sessions',
          body: {
            'userId': userId,
            'model': model,
            'voice': voice,
            'instructions': instructions,
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

        _updateConnectionState('Establishing connection...');
        await _setupWebRTC(model);
      } catch (e) {
        if (e is WebRTCError) {
          rethrow;
        }
        throw WebRTCError.initializationFailed(e);
      }
    } catch (e) {
      await cleanup();
      rethrow;
    }
  }

  /// WebRTC 연결 설정
  Future<void> _setupWebRTC(String model) async {
    try {
      Map<String, dynamic> configuration = {
        "iceServers": _iceServers,
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        final stateString = state.toString().split('.').last;
        _connectionState = stateString;
        _updateConnectionState('Connection state: $stateString');

        // 연결이 끊어진 경우 콜백 호출
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          onConnectionStateChanged?.call('Failed');
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _connectionState = 'Connected';
          _updateConnectionState('Connected');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          _connectionState = 'Failed';
          _updateConnectionState('Connection failed');
          onConnectionStateChanged?.call('Failed');
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
        event.streams[0].getAudioTracks().forEach((track) {
          try {
            track.enabled = true;

            // 볼륨 설정
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
          if (_audioElement != null) {
            _audioElement!.srcObject = event.streams[0];
          }
          onAudioTrackReceived?.call(event.streams[0]);
        }
      };

      RTCSessionDescription offer = await _peerConnection!.createOffer();

      await _peerConnection!.setLocalDescription(offer);

      // OpenAI API 호출
      try {
        final url = Uri.parse('https://api.openai.com/v1/realtime');
        final queryParams = {
          'model': model,
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

          if (_peerConnection?.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _connectionState = 'Connected';
            _updateConnectionState('Connected');
          }
        } catch (e) {
          throw e;
        }
      } catch (e) {
        _updateConnectionState('Connection failed: $e');
        throw WebRTCError.connectionFailed(e);
      }
    } catch (e) {
      _updateConnectionState('WebRTC setup error: $e');
      rethrow;
    }
  }

  /// 데이터 채널 구성
  void _configureDataChannel(RTCDataChannel channel) {
    if (_isDisposing) {
      return;
    }

    // 이전 리스너 제거 시도
    try {
      channel.onDataChannelState = null;
      channel.onMessage = null;
    } catch (e) {
      // 오류 무시
    }

    // 데이터 채널 상태 변경 이벤트 처리
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (_isDisposing) {
        return;
      }

      _isDataChannelOpen = state == RTCDataChannelState.RTCDataChannelOpen;

      if (_isDataChannelOpen) {
        _updateConnectionState('Data channel opened');
        onDataChannelOpened?.call();
      }
    };

    // 데이터 채널 메시지 처리
    channel.onMessage = (RTCDataChannelMessage message) {
      if (_isDisposing) {
        return;
      }

      try {
        final data = jsonDecode(message.text);
        onMessageReceived?.call(data);
      } catch (e) {
        // 오류 무시
      }
    };
  }

  /// 메시지 전송
  bool sendMessage(dynamic message) {
    try {
      if (_isDisposing) {
        return false;
      }

      if (_dataChannel == null) {
        return false;
      }

      // 현재 데이터 채널 상태 확인
      final RTCDataChannelState? state = _dataChannel?.state;

      if (state != RTCDataChannelState.RTCDataChannelOpen) {
        return false;
      }

      // JSON으로 변환
      final messageStr = message is String ? message : jsonEncode(message);

      // 메시지 전송
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

  /// 세션 세팅 메시지 전송
  bool sendSessionUpdate() {
    return sendMessage({
      "type": "session.update",
      "session": {
        "modalities": ["text", "audio"],
        "tools": [],
        "input_audio_transcription": {
          "model": "whisper-1",
        },
      },
    });
  }

  /// 시스템 메시지 전송
  bool sendSystemMessage(String content) {
    return sendMessage({
      "type": "conversation.item.create",
      "item": {
        "type": "message",
        "role": "system",
        "content": [
          {"type": "input_text", "text": content}
        ],
      }
    });
  }

  /// 사용자 메시지 전송
  bool sendUserMessage(String content) {
    return sendMessage({
      "type": "conversation.item.create",
      "item": {
        "type": "message",
        "role": "user",
        "content": [
          {"type": "input_text", "text": content}
        ],
      }
    });
  }

  /// 세션 종료 메시지 전송
  bool sendSessionClose() {
    return sendMessage({
      "type": "session.close",
    });
  }

  /// 연결 상태 업데이트
  void _updateConnectionState(String state) {
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }

  /// 오디오 렌더러 설정
  void setAudioRenderer(RTCVideoRenderer renderer) {
    _audioElement = renderer;
  }

  /// 리소스 정리
  Future<void> cleanup() async {
    _isDisposing = true;

    // 데이터 채널 닫기
    try {
      if (_dataChannel != null) {
        _dataChannel!.onDataChannelState = null;
        _dataChannel!.onMessage = null;
        _dataChannel!.close();
      }
    } catch (e) {
      // 오류 무시
    } finally {
      _dataChannel = null;
    }

    // Peer Connection 닫기
    try {
      if (_peerConnection != null) {
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
      _localStream = null;
    }

    _isDataChannelOpen = false;
  }

  /// 객체 소멸
  void dispose() {
    cleanup();
    _audioElement = null;
  }
}
