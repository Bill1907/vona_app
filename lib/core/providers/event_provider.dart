import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../supabase/event_service.dart';

class EventProvider with ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  EventProvider();

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents({String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await EventService.getEvents(userId: userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEvent(Event event) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    print('Creating event: $event');

    try {
      final newEvent = await EventService.createEvent(event);
      _events.add(newEvent);
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      _error = null;
    } catch (e) {
      print('Error creating event: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEvent(Event event) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedEvent = await EventService.updateEvent(event);
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await EventService.deleteEvent(id);
      _events.removeWhere((event) => event.id == id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Event>> getUpcomingEvents({String? userId, int limit = 5}) async {
    try {
      return await EventService.getUpcomingEvents(userId: userId, limit: limit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
}
