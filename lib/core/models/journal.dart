import 'package:uuid/uuid.dart';

class Journal {
  final String id;
  final String? userId;
  final List<String> keywords;
  final String emotion;
  final String summary;
  final String conversationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Journal({
    String? id,
    this.userId,
    required this.keywords,
    required this.emotion,
    required this.summary,
    required this.conversationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'keywords': keywords,
        'emotion': emotion,
        'summary': summary,
        'conversation_id': conversationId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // JSON 역직렬화
  factory Journal.fromJson(Map<String, dynamic> json) => Journal(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        keywords: List<String>.from(json['keywords']),
        emotion: json['emotion'] as String,
        summary: json['summary'] as String,
        conversationId: json['conversation_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  // 복사본 생성 with 메서드
  Journal copyWith({
    String? id,
    String? userId,
    List<String>? keywords,
    String? emotion,
    String? summary,
    String? conversationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Journal(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        keywords: keywords ?? this.keywords,
        emotion: emotion ?? this.emotion,
        summary: summary ?? this.summary,
        conversationId: conversationId ?? this.conversationId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
