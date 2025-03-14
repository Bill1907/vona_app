import '../models/instruction.dart';
import 'client.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class InstructionService {
  static final _client = SupabaseClientWrapper.client;

  /// 사용자의 모든 instruction 목록을 가져옵니다.
  static Future<List<Instruction>> getInstructions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('user_instructions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final instructions = (response as List)
        .map((json) => Instruction.fromJson(json as Map<String, dynamic>))
        .toList();

    return instructions;
  }

  /// 사용자가 instruction을 가지고 있는지 확인합니다.
  static Future<bool> hasInstructions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('user_instructions')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    return response != null;
  }

  /// 특정 ID의 instruction을 가져옵니다.
  static Future<String?> getInstruction(String userId) async {
    try {
      final response = await _client
          .from('user_instructions')
          .select('instructions')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return response['instructions'] as String?;
    } catch (e) {
      print('Error fetching instruction: $e');
      return null;
    }
  }

  /// 새로운 instruction을 생성합니다.
  static Future<String> createInstruction(String instructions) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final instructionData = {
      // ID 필드 제거 - 데이터베이스가 자동으로 생성
      'user_id': userId,
      'instructions': instructions,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 응답에서 생성된 ID 반환
    final response = await _client
        .from('user_instructions')
        .insert(instructionData)
        .select('id')
        .single();

    return response['id'].toString();
  }

  /// 기존 instruction을 업데이트합니다.
  static Future<void> updateInstruction(Instruction instruction) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // 업데이트 시에는 현재 시간으로 updated_at 갱신
    final updatedInstruction = instruction.copyWith(
      updatedAt: DateTime.now(),
    );

    await _client
        .from('user_instructions')
        .update(updatedInstruction.toJson())
        .eq('id', instruction.id)
        .eq('user_id', userId);
  }

  /// 특정 ID의 instruction을 삭제합니다.
  static Future<void> deleteInstruction(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('user_instructions')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
