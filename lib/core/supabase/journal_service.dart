import '../models/journal.dart';
import 'client.dart';
import 'package:uuid/uuid.dart';

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

    final journals = (response as List)
        .map((json) {
          try {
            // Skip invalid entries
            if (json['content'] == null) {
              return null;
            }

            // Ensure required fields are present and handle null values
            final Map<String, dynamic> safeJson = {
              'id': json['id'] ?? const Uuid().v4(),
              'content': json['content'], // Don't provide default for content
              'title': json['title'] ?? 'Untitled',
              'emotion': json['emotion'] ?? 'neutral',
              'keywords':
                  (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
              'conversation_id': json['conversation_id'] ?? '',
              'created_at':
                  json['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at':
                  json['updated_at'] ?? DateTime.now().toIso8601String(),
              'user_id': json['user_id'] ?? '',
              'iv': json['iv'],
            };

            final journal = Journal.fromJson(safeJson);
            return journal;
          } catch (e, stackTrace) {
            print('Error processing journal entry: $e');
            print('Stack trace: $stackTrace');
            print('Problematic journal data: $json');
            return null; // Skip problematic entries instead of throwing
          }
        })
        .where((journal) => journal != null) // Filter out null entries
        .cast<Journal>() // Cast the non-null entries to Journal
        .toList();

    return journals;
  }

  static Future<List<Journal>> getRecentJournals({int days = 7}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // 최근 N일 이후의 날짜 계산
    final DateTime now = DateTime.now();
    final DateTime cutoffDate = now.subtract(Duration(days: days));
    final String cutoffDateStr = cutoffDate.toIso8601String();

    final response = await _client
        .from('journals')
        .select()
        .eq('user_id', userId)
        .gte('created_at', cutoffDateStr) // 최근 N일 이후의 데이터만 가져옴
        .order('created_at', ascending: false);

    final journals = (response as List)
        .map((json) {
          try {
            // Skip invalid entries
            if (json['content'] == null) {
              return null;
            }

            // Ensure required fields are present and handle null values
            final Map<String, dynamic> safeJson = {
              'id': json['id'] ?? const Uuid().v4(),
              'content': json['content'], // Don't provide default for content
              'title': json['title'] ?? 'Untitled',
              'emotion': json['emotion'] ?? 'neutral',
              'keywords':
                  (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
              'conversation_id': json['conversation_id'] ?? '',
              'created_at':
                  json['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at':
                  json['updated_at'] ?? DateTime.now().toIso8601String(),
              'user_id': json['user_id'] ?? '',
              'iv': json['iv'],
            };

            final journal = Journal.fromJson(safeJson);
            return journal;
          } catch (e, stackTrace) {
            print('Error processing recent journal entry: $e');
            print('Stack trace: $stackTrace');
            print('Problematic recent journal data: $json');
            return null; // Skip problematic entries instead of throwing
          }
        })
        .where((journal) => journal != null) // Filter out null entries
        .cast<Journal>() // Cast the non-null entries to Journal
        .toList();

    print('Returning ${journals.length} valid recent journals');
    return journals;
  }

  static Future<Journal> createJournal(Journal journal) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    print('Creating journal for user: $userId');

    // Validate content
    if (journal.content.isEmpty) {
      throw Exception('Journal content cannot be empty');
    }

    // Generate new ID if not present
    final id = journal.id.isEmpty ? const Uuid().v4() : journal.id;
    print('Using journal ID: $id');

    try {
      print('Original content length: ${journal.content.length}');

      final journalData = {
        ...journal.toJson(),
        'id': id,
        'user_id': userId,
      };
      print('Prepared journal data for database');

      print('Inserting journal into database...');
      final response =
          await _client.from('journals').insert(journalData).select().single();
      print('Database response received');

      final createdJournal = Journal.fromJson(response as Map<String, dynamic>);
      print('Created journal object from response');

      return createdJournal;
    } catch (e) {
      print('Error in journal creation: $e');
      rethrow;
    }
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
    final journal = Journal.fromJson(response as Map<String, dynamic>);
    return journal;
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

    print('Fetching journals for conversation: $conversationId');

    final response = await _client
        .from('journals')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    print('Raw conversation journals response: $response');

    final journals = (response as List)
        .map((json) {
          print('Processing conversation journal data: $json');
          try {
            // Skip invalid entries
            if (json['content'] == null) {
              print(
                  'Skipping invalid conversation journal entry: missing content');
              return null;
            }

            // Ensure required fields are present and handle null values
            final Map<String, dynamic> safeJson = {
              'id': json['id'] ?? const Uuid().v4(),
              'content': json['content'], // Don't provide default for content
              'title': json['title'] ?? 'Untitled',
              'emotion': json['emotion'] ?? 'neutral',
              'keywords':
                  (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
              'conversation_id': json['conversation_id'] ?? '',
              'created_at':
                  json['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at':
                  json['updated_at'] ?? DateTime.now().toIso8601String(),
              'user_id': json['user_id'] ?? '',
              'iv': json['iv'],
            };

            print('Safe conversation JSON prepared: $safeJson');
            final journal = Journal.fromJson(safeJson);
            print('Conversation journal object created successfully');

            return journal;
          } catch (e, stackTrace) {
            print('Error processing conversation journal entry: $e');
            print('Stack trace: $stackTrace');
            print('Problematic conversation journal data: $json');
            return null; // Skip problematic entries instead of throwing
          }
        })
        .where((journal) => journal != null) // Filter out null entries
        .cast<Journal>() // Cast the non-null entries to Journal
        .toList();

    print('Returning ${journals.length} valid conversation journals');
    return journals;
  }

  static Future<void> batchUpdateJournal(List<Journal> journals) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // upsert 메서드를 사용하여 일괄 업데이트
    final journalData = journals.map((journal) {
      // user_id를 포함시켜 올바른 레코드가 업데이트되도록 함
      return {
        ...journal.toJson(),
        'user_id': userId,
      };
    }).toList();

    await _client.from('journals').upsert(journalData, onConflict: 'id');
  }
}
