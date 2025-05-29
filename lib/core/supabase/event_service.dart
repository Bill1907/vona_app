import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import 'client.dart'; // Assuming SupabaseClientWrapper is here

class EventService {
  static final _client = SupabaseClientWrapper.client;

  static Future<List<Event>> getEvents({String? userId}) async {
    final currentUserId = userId ?? _client.auth.currentUser?.id;
    if (currentUserId == null)
      throw Exception('User not authenticated and no userId provided');

    try {
      PostgrestFilterBuilder queryBuilder = _client.from('events').select();

      queryBuilder = queryBuilder.eq('user_id', currentUserId);

      final List<dynamic> responseData =
          await queryBuilder.order('start_time', ascending: true);
      return responseData
          .map<Event>((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print(e); // Keep for debugging, consider removing for production
      throw Exception('Failed to fetch events: $e');
    }
  }

  static Future<Event> getEvent(String id) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('id', id)
          .eq('user_id', currentUserId)
          .single();
      return Event.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch event: $e');
    }
  }

  static Future<Event> createEvent(Event event) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Ensure the event has the correct user_id
    final eventData = event.copyWith(userId: currentUserId).toJson();

    try {
      final response =
          await _client.from('events').insert(eventData).select().single();
      return Event.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  static Future<Event> updateEvent(Event event) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');
    try {
      // Update event with current user ID to ensure it's correct
      final eventData = event.copyWith(userId: currentUserId).toJson();

      final response = await _client
          .from('events')
          .update(eventData)
          .eq('id', event.id)
          .eq('user_id', currentUserId) // Ensure only owner can update
          .select()
          .single();
      return Event.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  static Future<void> deleteEvent(String id) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');
    try {
      await _client
          .from('events')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  static Future<List<Event>> getUpcomingEvents(
      {String? userId, int limit = 5}) async {
    final currentUserId = userId ?? _client.auth.currentUser?.id;
    if (currentUserId == null)
      throw Exception('User not authenticated and no userId provided');

    try {
      final now = DateTime.now().toIso8601String();
      PostgrestFilterBuilder queryBuilder =
          _client.from('events').select().gte('start_time', now);

      queryBuilder = queryBuilder.eq('user_id', currentUserId);

      final List<dynamic> responseData =
          await queryBuilder.order('start_time', ascending: true).limit(limit);
      return responseData
          .map<Event>((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch upcoming events: $e');
    }
  }
}
