import 'package:flutter/foundation.dart';

/// 실시간 대화 메시지 모델
/// 실시간 통신 중 주고 받는 메시지의 구조를 정의합니다.
class ConversationMessage {
  final String id;
  final String role;
  final String text;
  final String timestamp;
  final bool isFinal;
  final String? status;

  const ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isFinal = false,
    this.status,
  });

  /// JSON 직렬화
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'timestamp': timestamp,
        'isFinal': isFinal,
        'status': status,
      };

  /// JSON 역직렬화
  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        text: json['text'] as String,
        timestamp: json['timestamp'] as String,
        isFinal: json['isFinal'] as bool? ?? false,
        status: json['status'] as String?,
      );

  /// 복사본 생성 메서드
  ConversationMessage copyWith({
    String? text,
    bool? isFinal,
    String? status,
  }) {
    return ConversationMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      timestamp: timestamp,
      isFinal: isFinal ?? this.isFinal,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ConversationMessage &&
        other.id == id &&
        other.role == role &&
        other.text == text &&
        other.timestamp == timestamp &&
        other.isFinal == isFinal &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, role, text, timestamp, isFinal, status);
}
