import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/function_tool.dart';
import '../supabase/event_service.dart';

/// 일정 관리 Function 처리 결과
class FunctionResult {
  final bool success;
  final String message;
  final dynamic data;

  const FunctionResult({
    required this.success,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'data': data,
      };
}

/// 일정 관리 Function Tools 처리 서비스
class CalendarFunctionHandler {
  /// Function call 실행
  static Future<FunctionResult> executeFunction(
    String functionName,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final tool = CalendarFunctionTools.findByName(functionName);
      if (tool == null) {
        return FunctionResult(
          success: false,
          message: 'Unknown function: $functionName',
        );
      }

      switch (tool.type) {
        case FunctionToolType.createEvent:
          return await _createEvent(arguments);
        case FunctionToolType.updateEvent:
          return await _updateEvent(arguments);
        case FunctionToolType.deleteEvent:
          return await _deleteEvent(arguments);
        case FunctionToolType.listEvents:
          return await _listEvents(arguments);
        case FunctionToolType.findEvents:
          return await _findEvents(arguments);
      }
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Error executing function: $e',
      );
    }
  }

  /// 새 이벤트 생성
  static Future<FunctionResult> _createEvent(
      Map<String, dynamic> arguments) async {
    try {
      final title = arguments['title'] as String?;
      final description = arguments['description'] as String?;
      final startTimeStr = arguments['start_time'] as String?;
      final endTimeStr = arguments['end_time'] as String?;
      final location = arguments['location'] as String?;
      final priority = arguments['priority'] as String?;

      if (title == null ||
          description == null ||
          startTimeStr == null ||
          endTimeStr == null) {
        return const FunctionResult(
          success: false,
          message:
              'Missing required fields: title, description, start_time, end_time',
        );
      }

      final startTime = DateTime.parse(startTimeStr);
      final endTime = DateTime.parse(endTimeStr);

      if (endTime.isBefore(startTime)) {
        return const FunctionResult(
          success: false,
          message: 'End time cannot be before start time',
        );
      }

      final event = Event(
        id: const Uuid().v4(),
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        userId: '', // EventService가 자동으로 설정
        status: 'active',
        priority: priority,
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdEvent = await EventService.createEvent(event);

      return FunctionResult(
        success: true,
        message: 'Event created successfully: ${createdEvent.title}',
        data: {
          'event_id': createdEvent.id,
          'title': createdEvent.title,
          'start_time': createdEvent.startTime.toIso8601String(),
          'end_time': createdEvent.endTime.toIso8601String(),
        },
      );
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Failed to create event: $e',
      );
    }
  }

  /// 이벤트 업데이트
  static Future<FunctionResult> _updateEvent(
      Map<String, dynamic> arguments) async {
    try {
      final eventId = arguments['event_id'] as String?;
      if (eventId == null) {
        return const FunctionResult(
          success: false,
          message: 'Missing required field: event_id',
        );
      }

      // 기존 이벤트 조회
      final existingEvent = await EventService.getEvent(eventId);

      // 업데이트할 필드들
      final title = arguments['title'] as String?;
      final description = arguments['description'] as String?;
      final startTimeStr = arguments['start_time'] as String?;
      final endTimeStr = arguments['end_time'] as String?;
      final location = arguments['location'] as String?;
      final priority = arguments['priority'] as String?;
      final status = arguments['status'] as String?;

      DateTime? startTime;
      DateTime? endTime;

      if (startTimeStr != null) {
        startTime = DateTime.parse(startTimeStr);
      }

      if (endTimeStr != null) {
        endTime = DateTime.parse(endTimeStr);
      }

      // 시간 유효성 검사
      final finalStartTime = startTime ?? existingEvent.startTime;
      final finalEndTime = endTime ?? existingEvent.endTime;

      if (finalEndTime.isBefore(finalStartTime)) {
        return const FunctionResult(
          success: false,
          message: 'End time cannot be before start time',
        );
      }

      final updatedEvent = existingEvent.copyWith(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        location: location,
        priority: priority,
        status: status,
        updatedAt: DateTime.now(),
      );

      final result = await EventService.updateEvent(updatedEvent);

      return FunctionResult(
        success: true,
        message: 'Event updated successfully: ${result.title}',
        data: {
          'event_id': result.id,
          'title': result.title,
          'start_time': result.startTime.toIso8601String(),
          'end_time': result.endTime.toIso8601String(),
        },
      );
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Failed to update event: $e',
      );
    }
  }

  /// 이벤트 삭제
  static Future<FunctionResult> _deleteEvent(
      Map<String, dynamic> arguments) async {
    try {
      final eventId = arguments['event_id'] as String?;
      if (eventId == null) {
        return const FunctionResult(
          success: false,
          message: 'Missing required field: event_id',
        );
      }

      // 삭제 전에 이벤트 정보 조회 (제목 확인용)
      final event = await EventService.getEvent(eventId);
      await EventService.deleteEvent(eventId);

      return FunctionResult(
        success: true,
        message: 'Event deleted successfully: ${event.title}',
        data: {'event_id': eventId},
      );
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Failed to delete event: $e',
      );
    }
  }

  /// 이벤트 목록 조회
  static Future<FunctionResult> _listEvents(
      Map<String, dynamic> arguments) async {
    try {
      final startDateStr = arguments['start_date'] as String?;
      final endDateStr = arguments['end_date'] as String?;
      final status = arguments['status'] as String? ?? 'active';

      if (startDateStr == null || endDateStr == null) {
        return const FunctionResult(
          success: false,
          message: 'Missing required fields: start_date, end_date',
        );
      }

      final startDate = DateTime.parse('${startDateStr}T00:00:00');
      final endDate = DateTime.parse('${endDateStr}T23:59:59');

      // 모든 이벤트 조회 (EventService는 현재 날짜 범위 필터링을 지원하지 않으므로 클라이언트에서 필터링)
      final allEvents = await EventService.getEvents();

      // 날짜 범위와 상태로 필터링
      final filteredEvents = allEvents.where((event) {
        final isInDateRange = event.startTime
                .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            event.startTime.isBefore(endDate.add(const Duration(seconds: 1)));

        final statusMatch = status == 'all' || event.status == status;

        return isInDateRange && statusMatch;
      }).toList();

      // 시작 시간순으로 정렬
      filteredEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      final eventList = filteredEvents
          .map((event) => {
                'id': event.id,
                'title': event.title,
                'description': event.description,
                'start_time': event.startTime.toIso8601String(),
                'end_time': event.endTime.toIso8601String(),
                'location': event.location,
                'priority': event.priority,
                'status': event.status,
              })
          .toList();

      return FunctionResult(
        success: true,
        message:
            'Found ${filteredEvents.length} events between $startDateStr and $endDateStr',
        data: {
          'events': eventList,
          'count': filteredEvents.length,
        },
      );
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Failed to list events: $e',
      );
    }
  }

  /// 이벤트 검색
  static Future<FunctionResult> _findEvents(
      Map<String, dynamic> arguments) async {
    try {
      final query = arguments['query'] as String?;
      final limit = arguments['limit'] as int? ?? 10;

      if (query == null || query.isEmpty) {
        return const FunctionResult(
          success: false,
          message: 'Missing required field: query',
        );
      }

      // 모든 이벤트 조회
      final allEvents = await EventService.getEvents();

      // 제목, 설명, 위치에서 검색
      final searchResults = allEvents.where((event) {
        final lowerQuery = query.toLowerCase();
        return event.title.toLowerCase().contains(lowerQuery) ||
            event.description.toLowerCase().contains(lowerQuery) ||
            (event.location?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();

      // 관련성순으로 정렬 (제목에 포함된 것을 우선)
      searchResults.sort((a, b) {
        final aInTitle =
            a.title.toLowerCase().contains(query.toLowerCase()) ? 0 : 1;
        final bInTitle =
            b.title.toLowerCase().contains(query.toLowerCase()) ? 0 : 1;

        if (aInTitle != bInTitle) return aInTitle.compareTo(bInTitle);

        // 제목에 같이 포함되어 있다면 시작 시간순
        return a.startTime.compareTo(b.startTime);
      });

      // 제한 개수만큼 자르기
      final limitedResults = searchResults.take(limit).toList();

      final eventList = limitedResults
          .map((event) => {
                'id': event.id,
                'title': event.title,
                'description': event.description,
                'start_time': event.startTime.toIso8601String(),
                'end_time': event.endTime.toIso8601String(),
                'location': event.location,
                'priority': event.priority,
                'status': event.status,
              })
          .toList();

      return FunctionResult(
        success: true,
        message: 'Found ${limitedResults.length} events matching "$query"',
        data: {
          'events': eventList,
          'count': limitedResults.length,
          'total_matches': searchResults.length,
        },
      );
    } catch (e) {
      return FunctionResult(
        success: false,
        message: 'Failed to find events: $e',
      );
    }
  }
}
