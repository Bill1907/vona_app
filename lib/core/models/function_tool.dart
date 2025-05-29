/// Function tool 타입 열거형
enum FunctionToolType {
  createEvent,
  updateEvent,
  deleteEvent,
  listEvents,
  findEvents,
}

/// Function tool 정의 클래스
class FunctionTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final FunctionToolType type;

  const FunctionTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': 'function',
        'description': description,
        'parameters': parameters,
      };
}

/// 일정 관리 Function Tools
class CalendarFunctionTools {
  static const List<FunctionTool> tools = [
    FunctionTool(
      name: 'create_event',
      type: FunctionToolType.createEvent,
      description:
          'Create a new calendar event with title, description, start time, end time, and optional location',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'The title of the event',
          },
          'description': {
            'type': 'string',
            'description': 'Detailed description of the event',
          },
          'start_time': {
            'type': 'string',
            'format': 'date-time',
            'description':
                'Start time in ISO 8601 format (e.g., "2024-01-15T14:00:00")',
          },
          'end_time': {
            'type': 'string',
            'format': 'date-time',
            'description':
                'End time in ISO 8601 format (e.g., "2024-01-15T15:00:00")',
          },
          'location': {
            'type': 'string',
            'description': 'Location of the event (optional)',
          },
          'priority': {
            'type': 'string',
            'enum': ['low', 'medium', 'high'],
            'description': 'Priority level of the event (optional)',
          },
        },
        'required': ['title', 'description', 'start_time', 'end_time'],
      },
    ),
    FunctionTool(
      name: 'update_event',
      type: FunctionToolType.updateEvent,
      description: 'Update an existing calendar event',
      parameters: {
        'type': 'object',
        'properties': {
          'event_id': {
            'type': 'string',
            'description': 'The ID of the event to update',
          },
          'title': {
            'type': 'string',
            'description': 'The new title of the event',
          },
          'description': {
            'type': 'string',
            'description': 'New detailed description of the event',
          },
          'start_time': {
            'type': 'string',
            'format': 'date-time',
            'description': 'New start time in ISO 8601 format',
          },
          'end_time': {
            'type': 'string',
            'format': 'date-time',
            'description': 'New end time in ISO 8601 format',
          },
          'location': {
            'type': 'string',
            'description': 'New location of the event',
          },
          'priority': {
            'type': 'string',
            'enum': ['low', 'medium', 'high'],
            'description': 'New priority level of the event',
          },
          'status': {
            'type': 'string',
            'enum': ['active', 'completed', 'cancelled'],
            'description': 'New status of the event',
          },
        },
        'required': ['event_id'],
      },
    ),
    FunctionTool(
      name: 'delete_event',
      type: FunctionToolType.deleteEvent,
      description: 'Delete a calendar event',
      parameters: {
        'type': 'object',
        'properties': {
          'event_id': {
            'type': 'string',
            'description': 'The ID of the event to delete',
          },
        },
        'required': ['event_id'],
      },
    ),
    FunctionTool(
      name: 'list_events',
      type: FunctionToolType.listEvents,
      description: 'List calendar events within a specific date range',
      parameters: {
        'type': 'object',
        'properties': {
          'start_date': {
            'type': 'string',
            'format': 'date',
            'description':
                'Start date in YYYY-MM-DD format (e.g., "2024-01-15")',
          },
          'end_date': {
            'type': 'string',
            'format': 'date',
            'description': 'End date in YYYY-MM-DD format (e.g., "2024-01-20")',
          },
          'status': {
            'type': 'string',
            'enum': ['active', 'completed', 'cancelled', 'all'],
            'description': 'Filter events by status (default: active)',
          },
        },
        'required': ['start_date', 'end_date'],
      },
    ),
    FunctionTool(
      name: 'find_events',
      type: FunctionToolType.findEvents,
      description: 'Search for events by title, description, or location',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search query to find events',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of events to return (default: 10)',
          },
        },
        'required': ['query'],
      },
    ),
  ];

  /// Function tool을 이름으로 찾기
  static FunctionTool? findByName(String name) {
    try {
      return tools.firstWhere((tool) => tool.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 모든 function tools를 JSON 배열로 변환
  static List<Map<String, dynamic>> toJsonList() {
    return tools.map((tool) => tool.toJson()).toList();
  }
}
