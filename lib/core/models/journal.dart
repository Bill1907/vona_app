import 'package:uuid/uuid.dart';

class Journal {
  final String id;
  final String? userId;
  final List<String> keywords;
  final String emotion;
  final String title;
  final String content;
  final String conversationId;
  final String? iv;
  final DateTime createdAt;
  final DateTime updatedAt;

  Journal({
    String? id,
    this.userId,
    required this.keywords,
    required this.emotion,
    required this.title,
    required this.content,
    required this.conversationId,
    this.iv,
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
        'title': title,
        'content': content,
        'conversation_id': conversationId,
        'iv': iv,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // JSON 역직렬화
  factory Journal.fromJson(Map<String, dynamic> json) => Journal(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        keywords: List<String>.from(json['keywords']),
        emotion: json['emotion'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        conversationId: json['conversation_id'] as String,
        iv: json['iv'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  // 복사본 생성 with 메서드
  Journal copyWith({
    String? id,
    String? userId,
    List<String>? keywords,
    String? emotion,
    String? title,
    String? content,
    String? conversationId,
    String? iv,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Journal(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        keywords: keywords ?? this.keywords,
        emotion: emotion ?? this.emotion,
        title: title ?? this.title,
        content: content ?? this.content,
        conversationId: conversationId ?? this.conversationId,
        iv: iv ?? this.iv,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
