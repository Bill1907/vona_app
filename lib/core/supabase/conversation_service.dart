import '../models/conversation.dart';
import 'client.dart';

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

    return (response as List)
        .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<String> createConversation(List<dynamic> contents) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final conversationData = {
      'contents': contents,
      'user_id': userId,
    };

    final response = await _client
        .from('conversations')
        .insert(conversationData)
        .select()
        .single();

    return (response as Map<String, dynamic>)['id'] as String;
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

    print('Conversation response: $response');

    if (response == null) return null;
    return Conversation.fromJson(response as Map<String, dynamic>);
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
