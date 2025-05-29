import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/conversation_message.dart';
import '../models/journal.dart';
import '../supabase/journal_service.dart';
import '../supabase/conversation_service.dart';
import '../network/http_service.dart';
import 'webrtc_service.dart';
import '../crypt/encrypt.dart';
import 'calendar_function_handler.dart';
import '../models/function_tool.dart';

/// 대화 상태 변경 콜백 타입
typedef ConversationStateCallback = void Function(bool isActive);

/// 대화 메시지 업데이트 콜백 타입
typedef ConversationUpdateCallback = void Function(
    List<ConversationMessage> messages);

/// 대화 관리 서비스 클래스
///
/// WebRTC를 통한 대화 메시지 처리 및 대화 저장을 담당합니다.
class ConversationManager {
  // WebRTC 서비스
  final WebRTCService _webRTCService;

  // 암호화 서비스
  final EncryptService? _encryptService;

  // 대화 관련 상태
  final List<ConversationMessage> _conversation = [];
  String? _ephemeralMessageId;
  bool _isConversationActive = false;
  bool _isConversationStarted = false;

  // 세션 설정 상태
  bool _isWaitingForSessionUpdate = false;
  String? _pendingSystemMessage;

  // 언어 설정
  String _languageCode = 'en'; // 기본값은 영어

  // 콜백 함수들
  ConversationStateCallback? onConversationStateChanged;
  ConversationUpdateCallback? onConversationUpdated;
  VoidCallback? onSaved;
  VoidCallback? onError;

  /// 대화 목록 반환
  List<ConversationMessage> get conversation =>
      List.unmodifiable(_conversation);

  /// 대화 활성화 여부
  bool get isConversationActive => _isConversationActive;

  /// 대화 시작 여부
  bool get isConversationStarted => _isConversationStarted;

  /// 현재 언어 코드 설정
  set languageCode(String code) {
    _languageCode = code;
  }

  /// 현재 언어 코드 반환
  String get languageCode => _languageCode;

  /// 대화 관리자 생성자
  ConversationManager(
    this._webRTCService, {
    this.onConversationStateChanged,
    this.onConversationUpdated,
    this.onSaved,
    this.onError,
    String? languageCode,
    EncryptService? encryptService,
  }) : _encryptService = encryptService {
    // 언어 코드가 제공되면 설정
    if (languageCode != null) {
      _languageCode = languageCode;
    }

    // WebRTC 메시지 수신 콜백 설정
    _webRTCService.onMessageReceived = _handleDataChannelMessage;

    // WebRTC 데이터 채널 열림 콜백 설정
    _webRTCService.onDataChannelOpened = () {
      _startConversation();
    };
  }

  /// 대화 시작
  void _startConversation() {
    if (!_webRTCService.isDataChannelOpen || _isConversationActive) {
      return;
    }

    _isConversationActive = true;
    onConversationStateChanged?.call(_isConversationActive);

    // **새로운 접근법: 세션 업데이트를 건너뛰고 바로 시스템 메시지 전송**
    print('=== EXPERIMENTAL APPROACH ===');
    print('Skipping session updates, sending system message directly...');

    _experimentalDirectApproach();

    // 백업: 기존 방법도 3초 후 시도
    Future.delayed(Duration(milliseconds: 3000), () {
      if (_conversation.isEmpty) {
        print('Direct approach failed, trying session-based approach...');
        _fetchAndSendSessionUpdate();
      }
    });
  }

  /// 실험적 직접 접근법
  Future<void> _experimentalDirectApproach() async {
    try {
      print('=== EXPERIMENTAL DIRECT APPROACH ===');

      // 연결 진단 정보 출력
      final diagnostics = _webRTCService.getConnectionDiagnostics();
      print('📊 CONNECTION DIAGNOSTICS:');
      diagnostics.forEach((key, value) {
        print('  $key: $value');
      });

      if (!_webRTCService.isDataChannelOpen) {
        print('❌ Data channel not open for direct approach');
        print('Attempting to wait for data channel...');

        // 데이터 채널이 열릴 때까지 잠시 대기
        bool opened = await _waitForDataChannelReady(maxWaitTime: 5000);
        if (!opened) {
          print('❌ Data channel did not open within 5 seconds');
          return;
        }
      }

      print('✅ Data channel is ready, proceeding with direct approach');

      // **1단계: Function Tools 설정 테스트**
      await _testFunctionToolsSetup();

      // **2단계: 아주 간단한 시스템 메시지 전송**
      final simpleSystemMessage =
          "You are a helpful AI assistant. Please respond in ${_getLanguageName(_languageCode)} language.";

      print('📤 Sending minimal system message directly...');
      bool sent = _webRTCService.sendSystemMessage(simpleSystemMessage);

      if (sent) {
        print('✅ SUCCESS: Direct system message sent!');

        // 연결 상태 모니터링
        _monitorConnectionAfterMessage();

        // 잠시 대기 후 사용자 인사말 전송
        Future.delayed(Duration(milliseconds: 2000), () {
          if (_webRTCService.isDataChannelOpen) {
            print('📤 Sending user greeting...');
            bool greetingSent =
                _webRTCService.sendUserMessage("안녕하세요! 오늘 하루는 어떠셨나요?");
            if (greetingSent) {
              print('✅ Greeting sent successfully');
            } else {
              print('❌ Failed to send greeting');
            }
          } else {
            print('❌ Data channel closed before sending greeting');
          }
        });
      } else {
        print('❌ FAILED: Could not send direct system message');

        // 실패 후 진단 정보 다시 출력
        final failDiagnostics = _webRTCService.getConnectionDiagnostics();
        print('📊 POST-FAILURE DIAGNOSTICS:');
        failDiagnostics.forEach((key, value) {
          print('  $key: $value');
        });
      }
    } catch (e) {
      print('❌ Error in experimental direct approach: $e');
    }
  }

  /// Function Tools 설정 테스트
  Future<void> _testFunctionToolsSetup() async {
    print('🛠️ TESTING FUNCTION TOOLS SETUP');

    try {
      // Function Tools JSON 생성 테스트
      final toolsJson = CalendarFunctionTools.toJsonList();
      print('📋 Available Function Tools:');
      for (int i = 0; i < toolsJson.length; i++) {
        final tool = toolsJson[i];
        print('  ${i + 1}. ${tool['name']}: ${tool['description']}');
      }

      print(
          '🔧 Function Tools JSON size: ${jsonEncode(toolsJson).length} bytes');

      // **JSON 구조 상세 확인**
      print('📝 DETAILED TOOLS JSON STRUCTURE:');
      print(jsonEncode(toolsJson.take(2).toList())); // 처음 2개만 출력

      // 세션 업데이트 with tools 테스트
      print('📤 Testing session update with function tools...');
      bool toolsSessionSent =
          _webRTCService.sendSessionUpdate(includeCalendarTools: true);

      if (toolsSessionSent) {
        print('✅ Function tools session update sent successfully');

        // 연결 상태 모니터링 (tools 설정 후)
        await Future.delayed(Duration(milliseconds: 1000));

        if (_webRTCService.isDataChannelOpen) {
          print('✅ Data channel still open after tools setup');

          // 테스트 function call 시뮬레이션 (실제로는 AI가 호출)
          Future.delayed(Duration(milliseconds: 3000), () {
            _testManualFunctionCall();
          });
        } else {
          print('❌ Data channel closed after tools setup');
        }
      } else {
        print('❌ Failed to send function tools session update');
      }
    } catch (e) {
      print('❌ Error in function tools setup test: $e');
    }
  }

  /// 수동 Function Call 테스트
  void _testManualFunctionCall() {
    print('🧪 TESTING MANUAL FUNCTION CALL');

    try {
      // 간단한 list_events 테스트
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      final testArguments = {
        'start_date': today.toIso8601String().split('T')[0],
        'end_date': tomorrow.toIso8601String().split('T')[0],
        'status': 'active',
      };

      print('📋 Testing list_events function with arguments: $testArguments');

      // 직접 function handler 테스트
      CalendarFunctionHandler.executeFunction('list_events', testArguments)
          .then((result) {
        print('📊 Function test result:');
        print('  Success: ${result.success}');
        print('  Message: ${result.message}');
        if (result.data != null) {
          print('  Data: ${result.data}');
        }

        if (result.success) {
          print('✅ Function tools are working correctly!');

          // Function tools가 작동하면 AI에게 테스트 요청
          _requestAIToTestFunctionTools();
        } else {
          print('❌ Function tools test failed: ${result.message}');
        }
      }).catchError((e) {
        print('❌ Function test error: $e');
      });
    } catch (e) {
      print('❌ Error in manual function call test: $e');
    }
  }

  /// AI에게 Function Tools 테스트 요청
  void _requestAIToTestFunctionTools() {
    print('🤖 REQUESTING AI TO TEST FUNCTION TOOLS');

    Future.delayed(Duration(milliseconds: 2000), () {
      if (_webRTCService.isDataChannelOpen) {
        final testMessage = "오늘과 내일의 일정을 확인해주세요. list_events 함수를 사용해서 보여주세요.";

        print('📤 Sending function test request to AI: $testMessage');
        bool sent = _webRTCService.sendUserMessage(testMessage);

        if (sent) {
          print('✅ Function test request sent to AI');
        } else {
          print('❌ Failed to send function test request');
        }
      } else {
        print('❌ Cannot send test request - data channel closed');
      }
    });
  }

  /// Function Tools 연결 상태 진단
  Map<String, dynamic> getFunctionToolsDiagnostics() {
    try {
      final toolsJson = CalendarFunctionTools.toJsonList();

      return {
        'tools_available': toolsJson.length,
        'tools_list': toolsJson.map((tool) {
          return tool['name'];
        }).toList(),
        'tools_json_size': jsonEncode(toolsJson).length,
        'data_channel_open': _webRTCService.isDataChannelOpen,
        'conversation_active': _isConversationActive,
        'conversation_started': _isConversationStarted,
      };
    } catch (e) {
      return {
        'error': 'Failed to generate diagnostics: $e',
      };
    }
  }

  /// 메시지 전송 후 연결 상태 모니터링
  void _monitorConnectionAfterMessage() {
    print('🔍 Starting connection monitoring after message...');

    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (timer.tick > 20) {
        // 10초 후 중지
        timer.cancel();
        print('⏰ Connection monitoring ended');
        return;
      }

      if (!_webRTCService.isDataChannelOpen) {
        print('⚠️ Connection lost at ${timer.tick * 500}ms after message');
        timer.cancel();

        // 상세 진단 정보
        final diagnostics = _webRTCService.getConnectionDiagnostics();
        print('📊 CONNECTION LOSS DIAGNOSTICS:');
        diagnostics.forEach((key, value) {
          print('  $key: $value');
        });
        return;
      }

      if (timer.tick % 4 == 0) {
        // 2초마다
        print('✅ Connection stable at ${timer.tick * 500}ms');
      }
    });
  }

  /// 저널 데이터 가져와서 세션 업데이트 전송
  Future<void> _fetchAndSendSessionUpdate() async {
    try {
      // 최근 7일간의 저널 가져오기
      final journals = await JournalService.getRecentJournals(days: 7);

      // 현재 날짜와 시간 정보
      final now = DateTime.now();
      final dateFormatter = DateTime(now.year, now.month, now.day);
      final timeFormatter =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final weekday = _getWeekdayName(now.weekday);

      // 시스템 메시지 내용 준비
      String systemContent =
          "You are a helpful AI assistant that provides thoughtful responses and helps with calendar management. ";

      // 현재 언어 설정 사용
      systemContent +=
          "Please respond to the user in ${_getLanguageName(_languageCode)} ";
      systemContent += "language (code: $_languageCode). ";

      // 현재 날짜/시간 정보 추가
      systemContent += "\n\nCURRENT TIME INFORMATION:\n";
      systemContent +=
          "- Current date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ($weekday)\n";
      systemContent += "- Current time: $timeFormatter\n";
      systemContent += "- Timezone: ${now.timeZoneName}\n";

      // 일정 관리 기능 안내
      systemContent += "\nCALENDAR MANAGEMENT CAPABILITIES:\n";
      systemContent +=
          "You have access to calendar management functions. You can:\n";
      systemContent +=
          "- Create new events with create_event (title, description, start_time, end_time, location, priority)\n";
      systemContent +=
          "- Update existing events with update_event (event_id, and any fields to update)\n";
      systemContent += "- Delete events with delete_event (event_id)\n";
      systemContent +=
          "- List events in a date range with list_events (start_date, end_date, status)\n";
      systemContent += "- Search for events with find_events (query, limit)\n";
      systemContent +=
          "Use these functions when the user asks about scheduling, calendar, appointments, or events.\n";
      systemContent +=
          "Always use the current date/time as reference for relative dates (today, tomorrow, next week, etc.).\n";

      if (journals.isNotEmpty) {
        // 저널 개수 제한 (최대 5개)
        final limitedJournals = journals.take(5).toList();

        systemContent +=
            "\nPAST CONVERSATIONS:\nYou have access to these summaries of the user's past conversations: ";

        for (int i = 0; i < limitedJournals.length; i++) {
          final journal = limitedJournals[i];

          // 저널 내용 길이 제한 (최대 30자)
          String limitedContent = journal.content;
          if (limitedContent.length > 30) {
            limitedContent = "${limitedContent.substring(0, 27)}...";
          }

          // 간결한 형식으로 저널 정보 포함
          systemContent +=
              "[${journal.createdAt.month}/${journal.createdAt.day}: ${journal.title}, emotion: ${journal.emotion}] ";
        }

        systemContent += "\nConnect with these past experiences when relevant.";
      }

      print('System message length: ${systemContent.length} characters');

      // **새로운 접근법: 데이터 채널 상태 모니터링 강화**
      print('=== DETAILED CONNECTION ANALYSIS ===');
      print('Initial data channel state: ${_webRTCService.isDataChannelOpen}');

      // 방법 1: 세션 업데이트 전에 연결 상태 완전히 확인
      if (!_webRTCService.isDataChannelOpen) {
        print('WARNING: Data channel is closed before session update!');
        // 잠시 대기해서 연결이 복구되는지 확인
        for (int i = 0; i < 10; i++) {
          await Future.delayed(Duration(milliseconds: 500));
          if (_webRTCService.isDataChannelOpen) {
            print('Data channel recovered after ${(i + 1) * 500}ms');
            break;
          }
          print('Waiting for data channel... ${(i + 1) * 500}ms');
        }
      }

      if (!_webRTCService.isDataChannelOpen) {
        print('CRITICAL: Data channel still closed, cannot proceed');
        return;
      }

      // Function Tools 없이 기본 세션 먼저 설정
      print('Sending basic session update (no function tools)...');
      bool sessionSent =
          _webRTCService.sendSessionUpdate(includeCalendarTools: false);

      if (!sessionSent) {
        print('FAILED: Basic session update not sent');
        return;
      }

      print('Basic session update sent successfully');
      print(
          'Data channel state after basic session: ${_webRTCService.isDataChannelOpen}');

      // **핵심 분석: 세션 업데이트 후 연결 상태 실시간 모니터링**
      print('Starting real-time connection monitoring...');
      bool connectionLost = false;
      int monitoringDuration = 0;

      while (monitoringDuration < 5000 && !connectionLost) {
        await Future.delayed(Duration(milliseconds: 100));
        monitoringDuration += 100;

        if (!_webRTCService.isDataChannelOpen) {
          connectionLost = true;
          print(
              'CONNECTION LOST at ${monitoringDuration}ms after session update!');
          break;
        }

        if (monitoringDuration % 1000 == 0) {
          print('Connection stable at ${monitoringDuration}ms');
        }
      }

      if (connectionLost) {
        print('ANALYSIS: Connection lost during session processing');
        print('Attempting immediate recovery...');

        // 즉시 재연결 시도
        bool recovered = await _attemptImmediateRecovery();
        if (!recovered) {
          print('RECOVERY FAILED: Cannot establish stable connection');
          return;
        }
      }

      // Function Tools 포함 세션 업데이트 (연결이 안정적인 경우에만)
      if (_webRTCService.isDataChannelOpen) {
        print('Sending session update with function tools...');
        sessionSent =
            _webRTCService.sendSessionUpdate(includeCalendarTools: true);

        if (sessionSent) {
          print('Function tools session sent successfully');
          print(
              'Data channel state after function tools: ${_webRTCService.isDataChannelOpen}');

          // 다시 모니터링
          await Future.delayed(Duration(milliseconds: 1000));
          if (!_webRTCService.isDataChannelOpen) {
            print('CONNECTION LOST after function tools session update!');
          }
        } else {
          print('Function tools session failed to send');
        }
      }

      // 시스템 메시지 크기 확인 및 제한
      final maxMessageSize = 8000;
      if (systemContent.length > maxMessageSize) {
        print(
            'System message too large (${systemContent.length} chars), truncating...');
        systemContent = systemContent.substring(0, maxMessageSize - 100) +
            "\n[Message truncated due to size limits]";
      }

      // 최종 연결 확인 후 시스템 메시지 전송
      if (!_webRTCService.isDataChannelOpen) {
        print('Data channel closed before system message, trying recovery...');
        bool finalRecovery = await _attemptImmediateRecovery();
        if (!finalRecovery) {
          print('FINAL FAILURE: Cannot send system message');
          return;
        }
      }

      print('Sending system message...');
      bool messageSent = _webRTCService.sendSystemMessage(systemContent);

      if (messageSent) {
        print('System message sent successfully');
      } else {
        print('System message failed to send');
      }

      // 응답이 없는 경우를 위한 백업 메시지
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!_webRTCService.isDataChannelOpen) return;

        if (_conversation.isEmpty) {
          print("No response detected after 3s, sending follow-up message");
          _webRTCService.sendUserMessage("Can you help me reflect on my day?");
        }
      });
    } catch (e) {
      print('Error in _fetchAndSendSessionUpdate: $e');
      // 기본 방식으로 시도
      try {
        print('Attempting basic session update as fallback...');
        _webRTCService.sendSessionUpdate(includeCalendarTools: false);

        // 기본 시스템 메시지 전송
        await Future.delayed(Duration(milliseconds: 2000));
        final basicMessage =
            "You are a helpful AI assistant. Please respond in ${_getLanguageName(_languageCode)}.";

        if (_webRTCService.isDataChannelOpen) {
          _webRTCService.sendSystemMessage(basicMessage);
        }
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
      }
    }
  }

  /// 즉시 재연결 시도
  Future<bool> _attemptImmediateRecovery() async {
    print('Attempting immediate data channel recovery...');

    for (int attempt = 1; attempt <= 5; attempt++) {
      print('Recovery attempt $attempt/5');

      await Future.delayed(Duration(milliseconds: attempt * 200));

      if (_webRTCService.isDataChannelOpen) {
        print('Data channel recovered on attempt $attempt');
        return true;
      }

      // WebRTC 서비스에 재연결 신호 보내기 (만약 메서드가 있다면)
      // _webRTCService.attemptReconnection();
    }

    print('All recovery attempts failed');
    return false;
  }

  /// 데이터 채널이 준비될 때까지 대기
  Future<bool> _waitForDataChannelReady({required int maxWaitTime}) async {
    print('Waiting for data channel to be ready (max ${maxWaitTime}ms)...');
    final startTime = DateTime.now().millisecondsSinceEpoch;

    while (DateTime.now().millisecondsSinceEpoch - startTime < maxWaitTime) {
      if (_webRTCService.isDataChannelOpen) {
        print('Data channel is now ready!');
        return true;
      }

      await Future.delayed(Duration(milliseconds: 100)); // 100ms마다 체크
    }

    print('Data channel not ready after ${maxWaitTime}ms');
    return false;
  }

  /// 대안적 접근 방법
  Future<void> _tryAlternativeApproach(String systemContent) async {
    print('Trying alternative approach: simpler message first');

    try {
      // 매우 간단한 메시지부터 시작
      final simpleMessage = "Hello, I'm ready to help you. How are you today?";

      // 데이터 채널이 열릴 때까지 대기
      bool isReady = await _waitForDataChannelReady(maxWaitTime: 3000);

      if (isReady) {
        print('Sending simple greeting message...');
        bool sent = _webRTCService.sendUserMessage(simpleMessage);

        if (sent) {
          print('Simple message sent successfully');

          // 잠시 후 시스템 설정 시도
          Future.delayed(Duration(milliseconds: 2000), () async {
            if (_webRTCService.isDataChannelOpen) {
              print('Attempting to send system configuration...');
              // **매우 간결한 시스템 메시지 (50K 문자 제한 준수)**
              String shortSystemContent =
                  "You are a helpful AI assistant. Please respond in ${_getLanguageName(_languageCode)} language.";
              _webRTCService.sendSystemMessage(shortSystemContent);
            }
          });
        }
      }
    } catch (e) {
      print('Alternative approach failed: $e');
    }
  }

  /// 데이터 채널 메시지 처리
  void _handleDataChannelMessage(Map<String, dynamic> data) {
    try {
      final messageType = data['type'] as String;

      // **Function Call 관련 메시지 특별 처리**
      if (messageType.contains('function_call')) {
        print('🔧 FUNCTION CALL MESSAGE: $messageType');
        print('📋 Full data: ${jsonEncode(data)}');
      }

      switch (messageType) {
        case 'session.updated':
          _handleSessionUpdated(data);
          break;

        case 'input_audio_buffer.speech_started':
          _isInputStarted();
          break;

        case 'input_audio_buffer.speech_stopped':
          _isInputStopped();
          break;

        case 'input_audio_buffer.committed':
          _updateEphemeralMessageStatus('processing');
          break;

        case 'conversation.item.input_audio_transcription':
          _handleTranscription(data);
          break;

        case 'conversation.item.input_audio_transcription.completed':
          _completeTranscription(data);
          break;

        case 'response.audio_transcript.delta':
          _handleResponseDelta(data);
          break;

        case 'response.audio_transcript.done':
          _completeResponse();
          break;

        case 'response.function_call_arguments.delta':
          _handleFunctionCallDelta(data);
          break;

        case 'response.function_call_arguments.done':
          _handleFunctionCallDone(data);
          break;

        // **추가 Function Call 관련 메시지 타입들**
        case 'response.function_call.start':
          _handleFunctionCallStart(data);
          break;

        case 'response.function_call.done':
          _handleFunctionCallComplete(data);
          break;

        case 'error':
          _handleErrorMessage(data);
          break;

        default:
          print('🔍 Unhandled message type: $messageType');
          print('📋 Data: ${jsonEncode(data)}');
      }

      // 대화 업데이트 알림
      onConversationUpdated?.call(_conversation);
    } catch (e) {
      print('Error handling data channel message: $e');
      print('Original data: ${jsonEncode(data)}');
      // 에러 발생 시에도 대화 업데이트 알림
      onConversationUpdated?.call(_conversation);
    }
  }

  /// 세션 업데이트 완료 처리
  void _handleSessionUpdated(Map<String, dynamic> data) {
    print('Session updated received: $data');

    if (_isWaitingForSessionUpdate && _pendingSystemMessage != null) {
      print('Session is ready, sending pending system message...');

      // 잠시 후 시스템 메시지 전송
      Future.delayed(Duration(milliseconds: 500), () {
        if (_webRTCService.isDataChannelOpen && _pendingSystemMessage != null) {
          final success =
              _webRTCService.sendSystemMessage(_pendingSystemMessage!);
          if (success) {
            print('Pending system message sent successfully');
          } else {
            print('Failed to send pending system message');
          }

          _isWaitingForSessionUpdate = false;
          _pendingSystemMessage = null;
        }
      });
    }
  }

  /// 입력 시작 처리
  void _isInputStarted() {
    _ephemeralMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    _conversation.add(ConversationMessage(
      id: _ephemeralMessageId!,
      role: 'user',
      text: '', // 빈 텍스트로 시작
      timestamp: DateTime.now().toIso8601String(),
      status: 'speaking',
    ));

    // 대화가 시작되었음을 표시
    _isConversationStarted = true;
  }

  /// 입력 정지 처리
  void _isInputStopped() {
    // 텍스트는 그대로 유지하고 상태만 변경
    _updateEphemeralMessageStatus('processing');
  }

  /// 메시지 상태만 업데이트하는 헬퍼 함수
  void _updateEphemeralMessageStatus(String? status) {
    if (_ephemeralMessageId == null) return;

    final index =
        _conversation.indexWhere((msg) => msg.id == _ephemeralMessageId);
    if (index != -1) {
      _conversation[index] = _conversation[index].copyWith(
        status: status,
      );
    }
  }

  /// 음성 텍스트 변환 처리
  void _handleTranscription(Map<String, dynamic> data) {
    final transcript =
        (data['transcript'] ?? data['text'] ?? '').toString().trim();
    if (transcript.isNotEmpty) {
      _updateEphemeralMessage(
        transcript,
        status: 'speaking',
        isFinal: false,
      );
    }
  }

  /// 음성 텍스트 변환 완료 처리
  void _completeTranscription(Map<String, dynamic> data) {
    final transcript = (data['transcript'] as String? ?? '').trim();
    if (transcript.isNotEmpty) {
      _updateEphemeralMessage(
        transcript,
        status: null, // 최종 상태에서는 상태 제거
        isFinal: true,
      );
    } else {
      // 전사 내용이 비어 있으면 메시지 제거
      _conversation.removeWhere((msg) => msg.id == _ephemeralMessageId);
    }
    _ephemeralMessageId = null;
  }

  /// 응답 델타 처리
  void _handleResponseDelta(Map<String, dynamic> data) {
    final delta = data['delta'] as String;

    if (_conversation.isNotEmpty &&
        _conversation.last.role == 'assistant' &&
        !_conversation.last.isFinal) {
      final lastMsg = _conversation.last;
      _conversation[_conversation.length - 1] = lastMsg.copyWith(
        text: '${lastMsg.text}$delta',
      );
    } else {
      _conversation.add(ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        text: delta,
        timestamp: DateTime.now().toIso8601String(),
        isFinal: false,
      ));
    }
  }

  /// 응답 완료 처리
  void _completeResponse() {
    if (_conversation.isNotEmpty) {
      final lastMsg = _conversation.last;
      _conversation[_conversation.length - 1] = lastMsg.copyWith(
        isFinal: true,
      );
    }
  }

  /// 임시 메시지 업데이트
  void _updateEphemeralMessage(String? text, {bool? isFinal, String? status}) {
    if (_ephemeralMessageId == null) return;

    final index =
        _conversation.indexWhere((msg) => msg.id == _ephemeralMessageId);
    if (index != -1) {
      final currentMessage = _conversation[index];
      _conversation[index] = currentMessage.copyWith(
        text: text ?? currentMessage.text, // text가 null이면 기존 텍스트 유지
        isFinal: isFinal ?? currentMessage.isFinal, // isFinal이 null이면 기존 값 유지
        status: status, // status는 null 포함 항상 업데이트
      );
    }
  }

  /// Function call 인수 델타 처리
  void _handleFunctionCallDelta(Map<String, dynamic> data) {
    print('Function call delta received: $data');
    // Function call arguments가 스트리밍되는 동안의 처리
    // 현재는 로깅만 하고, 완료 시 실제 처리
  }

  /// Function call 완료 처리
  void _handleFunctionCallDone(Map<String, dynamic> data) async {
    print('Function call done received: $data');

    try {
      final callId = data['call_id'] as String?;
      final functionName = data['name'] as String?;
      final argumentsStr = data['arguments'] as String?;

      if (callId == null || functionName == null || argumentsStr == null) {
        print('Invalid function call data');
        return;
      }

      // Function call을 대화에 추가
      _conversation.add(ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        text: '📅 ${_getFunctionDisplayName(functionName)}...',
        timestamp: DateTime.now().toIso8601String(),
        isFinal: false,
        status: 'executing_function',
      ));

      // 대화 업데이트 알림
      onConversationUpdated?.call(_conversation);

      // Function 실행
      final arguments = jsonDecode(argumentsStr) as Map<String, dynamic>;
      final result = await CalendarFunctionHandler.executeFunction(
        functionName,
        arguments,
      );

      // Function call 결과를 서버에 전송
      _webRTCService.sendFunctionCallResult(callId, result.toJson());

      // 실행 중인 메시지를 완료로 업데이트
      if (_conversation.isNotEmpty &&
          _conversation.last.status == 'executing_function') {
        final lastMsg = _conversation.last;
        _conversation[_conversation.length - 1] = lastMsg.copyWith(
          text: result.success ? '✅ ${result.message}' : '❌ ${result.message}',
          isFinal: true,
          status: null,
        );
      }

      // 대화 업데이트 알림
      onConversationUpdated?.call(_conversation);
    } catch (e) {
      print('Error handling function call: $e');

      // 에러가 발생한 경우 메시지 업데이트
      if (_conversation.isNotEmpty &&
          _conversation.last.status == 'executing_function') {
        final lastMsg = _conversation.last;
        _conversation[_conversation.length - 1] = lastMsg.copyWith(
          text: '❌ Function execution failed: $e',
          isFinal: true,
          status: null,
        );
      }

      // 대화 업데이트 알림
      onConversationUpdated?.call(_conversation);
    }
  }

  /// Function 이름을 사용자 친화적 이름으로 변환
  String _getFunctionDisplayName(String functionName) {
    switch (functionName) {
      case 'create_event':
        return '일정을 생성하고 있습니다';
      case 'update_event':
        return '일정을 수정하고 있습니다';
      case 'delete_event':
        return '일정을 삭제하고 있습니다';
      case 'list_events':
        return '일정 목록을 조회하고 있습니다';
      case 'find_events':
        return '일정을 검색하고 있습니다';
      default:
        return '작업을 실행하고 있습니다';
    }
  }

  /// 대화 중지 및 저장
  Future<void> stopAndSaveConversation(BuildContext context) async {
    if (!_isConversationActive || _conversation.isEmpty) {
      return;
    }

    try {
      // WebRTC 세션 종료 메시지 전송
      if (_webRTCService.isDataChannelOpen) {
        _webRTCService.sendSessionClose();
      }

      // 잠시 대기
      await Future.delayed(const Duration(milliseconds: 500));

      // 대화 데이터를 JSON 형식으로 변환
      final conversationData =
          _conversation.map((msg) => msg.toJson()).toList();

      final ivStringForConversation = _encryptService!.createIV();
      // 대화 암호화 처리
      final encryptedConversationData = _encryptService.encryptData(
        jsonEncode(conversationData),
        ivStringForConversation,
      );

      // 대화 저장
      final conversationId = await ConversationService.createConversation(
        encryptedConversationData,
        ivStringForConversation,
      );

      // 저널 생성
      await HttpService.instance.post(
        'journals',
        body: {
          'conversation': conversationData,
          'lang': _languageCode,
        },
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        onSuccess: (data) async {
          if (data == null) {
            throw Exception('Failed to process conversation');
          }

          try {
            // 한글 텍스트 처리
            final keywords =
                (data['keywords'] as List<dynamic>?)?.map((keyword) {
                      if (keyword is String) {
                        try {
                          return utf8.decode(utf8.encode(keyword));
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

            String content = data['content'] != null
                ? utf8.decode(utf8.encode(data['content'] as String))
                : '';

            // 암호화 관련 변수 초기화
            String? ivString;
            String? encryptedContent;

            // 암호화 서비스가 사용 가능하면 콘텐츠 암호화
            if (_encryptService != null) {
              try {
                ivString = _encryptService!.createIV();
                encryptedContent =
                    _encryptService!.encryptData(content, ivString);
                // 암호화 성공 시 암호화된 콘텐츠로 설정
                content = encryptedContent;
              } catch (e) {
                print('암호화 실패: $e');
                // 암호화 실패 시 원본 콘텐츠 사용 (암호화되지 않음)
                ivString = null;
              }
            }

            // 저널 객체 생성
            final journal = Journal(
              keywords: keywords,
              emotion: data['emotion'] ?? 'neutral',
              title: title,
              content: content,
              conversationId: conversationId,
              iv: ivString, // IV 값 저장
            );

            // 저널 저장
            await JournalService.createJournal(journal);

            // 대화 상태 초기화
            _isConversationActive = false;
            _conversation.clear();

            // 저장 완료 콜백
            onSaved?.call();
          } catch (e) {
            throw Exception('Failed to create journal: $e');
          }
        },
      );
    } catch (e) {
      // 오류 발생 시 콜백
      onError?.call();
    }
  }

  /// 언어 코드에 따른 언어 이름 반환
  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ko':
        return 'Korean';
      case 'ja':
        return 'Japanese';
      case 'es':
        return 'Spanish';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      default:
        return 'English'; // 기본값은 영어
    }
  }

  /// 요일 이름 반환
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// 리소스 정리
  void dispose() {
    _conversation.clear();
    _ephemeralMessageId = null;
    _isConversationActive = false;
  }

  /// 간단한 세션 설정 (서버 응답 기반)
  Future<void> _simpleSessionSetup() async {
    try {
      print('Starting simple session setup...');

      // **매우 간결한 시스템 메시지 (50K 문자 제한)**
      final simpleSystemMessage =
          "You are a helpful AI assistant. Please respond in ${_getLanguageName(_languageCode)} language.";

      // 시스템 메시지를 대기열에 추가
      _pendingSystemMessage = simpleSystemMessage;
      _isWaitingForSessionUpdate = true;

      // 기본 세션 업데이트 전송
      print('Sending basic session update...');
      final sessionSent =
          _webRTCService.sendSessionUpdate(includeCalendarTools: false);

      if (!sessionSent) {
        print('Failed to send basic session update');
        _isWaitingForSessionUpdate = false;
        _pendingSystemMessage = null;
        return;
      }

      print('Basic session update sent, waiting for server response...');

      // 5초 후에도 응답이 없으면 강제로 시도
      Future.delayed(Duration(milliseconds: 5000), () {
        if (_isWaitingForSessionUpdate) {
          print(
              'No session.updated response after 5s, forcing system message...');

          if (_webRTCService.isDataChannelOpen &&
              _pendingSystemMessage != null) {
            _webRTCService.sendSystemMessage(_pendingSystemMessage!);
            _isWaitingForSessionUpdate = false;
            _pendingSystemMessage = null;
          }
        }
      });
    } catch (e) {
      print('Error in simple session setup: $e');
      _isWaitingForSessionUpdate = false;
      _pendingSystemMessage = null;
    }
  }

  /// Function Call 시작 처리
  void _handleFunctionCallStart(Map<String, dynamic> data) {
    print('🚀 Function call started: $data');
  }

  /// Function Call 완료 처리 (다른 타입)
  void _handleFunctionCallComplete(Map<String, dynamic> data) {
    print('🏁 Function call completed: $data');
  }

  /// 에러 메시지 처리
  void _handleErrorMessage(Map<String, dynamic> data) {
    print('❌ ERROR MESSAGE RECEIVED:');
    print('📋 Error data: ${jsonEncode(data)}');

    final error = data['error'];
    if (error != null) {
      print('  Error type: ${error['type']}');
      print('  Error message: ${error['message']}');
      print('  Error code: ${error['code']}');
    }
  }
}
