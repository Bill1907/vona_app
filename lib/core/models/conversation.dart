import 'dart:convert';
import 'package:uuid/uuid.dart';

class Conversation {
  final String id;
  final String? userId;
  final String contents; // JSON 형태의 문자열로 저장
  final DateTime createdAt;
  final String iv;

  Conversation({
    String? id,
    this.userId,
    required this.contents,
    DateTime? createdAt,
    String? iv,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        iv = iv ?? '';

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'contents': contents,
        'created_at': createdAt.toIso8601String(),
        'iv': iv,
      };

  // JSON 역직렬화
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id']?.toString() ?? const Uuid().v4(),
        userId: json['user_id']?.toString(),
        contents: json['contents'] == null
            ? '[]'
            : json['contents'] is List
                ? jsonEncode(json['contents'])
                : json['contents'].toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        iv: json['iv']?.toString() ?? '',
      );

  // contents를 Map으로 변환
  Map<String, dynamic> get contentsAsMap =>
      json.decode(contents) as Map<String, dynamic>;

  // 복사본 생성 with 메서드
  Conversation copyWith({
    String? id,
    String? userId,
    String? contents,
    DateTime? createdAt,
    String? iv,
  }) =>
      Conversation(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        contents: contents ?? this.contents,
        createdAt: createdAt ?? this.createdAt,
        iv: iv ?? this.iv,
      );
}
