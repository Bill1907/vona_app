import 'dart:convert';
import '../models/conversation.dart';
import 'client.dart';
import 'package:uuid/uuid.dart';

class ConversationService {
  static final _client = SupabaseClientWrapper.client;

  static Future<List<Conversation>> getConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('conversations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final conversations = (response as List)
        .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
        .toList();

    return conversations;
  }

  static Future<String> createConversation(List<dynamic> messages) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final id = const Uuid().v4();

    // Convert messages to JSON string
    final jsonString = jsonEncode(messages);

    final conversationData = {
      'id': id,
      'user_id': userId,
      'contents': jsonString,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('conversations').insert(conversationData);
    return id;
  }

  static Future<Conversation?> getConversation(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('conversations')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    final conversation =
        Conversation.fromJson(response as Map<String, dynamic>);
    return conversation;
  }

  static Future<Map<String, dynamic>> getConversationMessages(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('conversations')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .single();

    final conversation =
        Conversation.fromJson(response as Map<String, dynamic>);

    try {
      // Verify and parse JSON
      if (conversation.contents.isEmpty) {
        return {'messages': []};
      }

      final decodedJson = jsonDecode(conversation.contents);
      if (decodedJson is! List) {
        throw FormatException('Content is not a valid JSON array');
      }

      return {'messages': decodedJson};
    } catch (e) {
      print('Error parsing contents as JSON: $e');
      throw FormatException('Failed to parse contents as JSON');
    }
  }

  static Future<void> updateConversation(Conversation conversation) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('conversations')
        .update(conversation.toJson())
        .eq('id', conversation.id)
        .eq('user_id', userId);
  }

  static Future<void> deleteConversation(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('conversations')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
