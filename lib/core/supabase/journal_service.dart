import '../models/journal.dart';
import 'client.dart';

class JournalService {
  static final _client = SupabaseClientWrapper.client;

  static Future<List<Journal>> getJournals() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('journals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Journal.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<Journal> createJournal(Journal journal) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final journalData = {
      ...journal.toJson(),
      'user_id': userId,
    };

    final response =
        await _client.from('journals').insert(journalData).select().single();

    return Journal.fromJson(response as Map<String, dynamic>);
  }

  static Future<Journal?> getJournal(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('journals')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Journal.fromJson(response as Map<String, dynamic>);
  }

  static Future<void> updateJournal(Journal journal) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('journals')
        .update(journal.toJson())
        .eq('id', journal.id)
        .eq('user_id', userId);
  }

  static Future<void> deleteJournal(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('journals').delete().eq('id', id).eq('user_id', userId);
  }

  static Future<List<Journal>> getJournalsByConversationId(
      String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('journals')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Journal.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
