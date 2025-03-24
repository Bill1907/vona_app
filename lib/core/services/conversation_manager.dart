import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/conversation_message.dart';
import '../models/journal.dart';
import '../supabase/journal_service.dart';
import '../supabase/conversation_service.dart';
import '../network/http_service.dart';
import 'webrtc_service.dart';

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

  // 대화 관련 상태
  final List<ConversationMessage> _conversation = [];
  String? _ephemeralMessageId;
  bool _isConversationActive = false;
  bool _isConversationStarted = false;

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
  }) {
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

    _fetchAndSendSessionUpdate();
  }

  /// 저널 데이터 가져와서 세션 업데이트 전송
  Future<void> _fetchAndSendSessionUpdate() async {
    try {
      // 최근 7일간의 저널 가져오기
      final journals = await JournalService.getRecentJournals(days: 7);

      // 시스템 메시지 내용 준비
      String systemContent =
          "You are a helpful assistant that listens to the user's day and provides thoughtful responses. ";

      // 현재 언어 설정 사용
      systemContent +=
          "Please respond to the user in ${_getLanguageName(_languageCode)} ";
      systemContent += "language (code: $_languageCode). ";

      if (journals.isNotEmpty) {
        // 저널 제한을 제거하고 일주일치 저널을 모두 사용
        systemContent +=
            "You have access to these summaries of the user's past conversations: ";

        for (int i = 0; i < journals.length; i++) {
          final journal = journals[i];

          // 저널 내용 길이 제한 (최대 50자)
          String limitedContent = journal.content;
          if (limitedContent.length > 50) {
            limitedContent = "${limitedContent.substring(0, 47)}...";
          }

          // 간결한 형식으로 저널 정보 포함
          systemContent +=
              "[${journal.createdAt.month}/${journal.createdAt.day}: ${journal.title}, emotion: ${journal.emotion}] ";
        }

        systemContent += "Connect with these past experiences when relevant.";
      }

      // 세션 업데이트 전송
      final bool sessionSent = _webRTCService.sendSessionUpdate();

      if (!sessionSent) {
        print('Failed to send session update, checking connection');
        return;
      }

      // 잠시 기다려서 세션 설정이 적용되도록 함
      await Future.delayed(Duration(milliseconds: 500));
      print(systemContent);
      // 시스템 메시지 전송
      final messageSent = _webRTCService.sendSystemMessage(systemContent);

      if (!messageSent) {
        print('Failed to send first message, checking connection');
        return;
      }

      // 응답이 없는 경우를 위한 백업 메시지
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!_webRTCService.isDataChannelOpen) return;

        if (_conversation.isEmpty) {
          print("No response detected after 2.5s, sending follow-up message");
          _webRTCService.sendUserMessage("Can you help me reflect on my day?");
        }
      });
    } catch (e) {
      print('Error in _fetchAndSendSessionUpdate: $e');
      // 기본 방식으로 시도
      _webRTCService.sendSessionUpdate();
    }
  }

  /// 데이터 채널 메시지 처리
  void _handleDataChannelMessage(Map<String, dynamic> data) {
    final messageType = data['type'] as String;

    switch (messageType) {
      case 'input_audio_buffer.speech_started':
        _isInputStarted();
        break;

      case 'input_audio_buffer.speech_stopped':
        _isInputStopped();
        break;

      case 'input_audio_buffer.committed':
        _updateEphemeralMessage(null, status: 'processing');
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
    }

    // 대화 업데이트 알림
    onConversationUpdated?.call(_conversation);
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
    _updateEphemeralMessage('', status: 'processing');
  }

  /// 음성 텍스트 변환 처리
  void _handleTranscription(Map<String, dynamic> data) {
    final transcript = data['transcript'] ?? data['text'] ?? '';
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
    final transcript = data['transcript'] as String? ?? '';
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
      _conversation[index] = _conversation[index].copyWith(
        text: text ?? '',
        isFinal: isFinal ?? false,
        status: status,
      );
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

      // 대화 저장
      final conversationId = await ConversationService.createConversation(
        conversationData,
      );

      // 저널 생성
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

            final content = data['content'] != null
                ? utf8.decode(utf8.encode(data['content'] as String))
                : '';

            // 저널 객체 생성
            final journal = Journal(
              keywords: keywords,
              emotion: data['emotion'] ?? 'neutral',
              title: title,
              content: content,
              conversationId: conversationId,
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

  /// 리소스 정리
  void dispose() {
    _conversation.clear();
    _ephemeralMessageId = null;
    _isConversationActive = false;
  }
}
