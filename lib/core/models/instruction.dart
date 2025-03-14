import 'package:uuid/uuid.dart';

class Instruction {
  final String id;
  final String? userId;
  final String instructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Instruction({
    String? id,
    this.userId,
    required this.instructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'instructions': instructions,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // JSON 역직렬화
  factory Instruction.fromJson(Map<String, dynamic> json) => Instruction(
        id: json['id']?.toString() ?? const Uuid().v4(),
        userId: json['user_id']?.toString(),
        instructions: json['instructions']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : DateTime.now(),
      );

  // 복사본 생성 with 메서드
  Instruction copyWith({
    String? id,
    String? userId,
    String? instructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Instruction(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        instructions: instructions ?? this.instructions,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
