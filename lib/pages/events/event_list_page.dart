import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/providers/event_provider.dart';
import '../../core/models/event.dart';
import 'event_form_page.dart';
import '../../widgets/empty_calendar_view.dart';

class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Event>> _groupedEvents = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<EventProvider>().loadEvents();
      }
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _groupedEvents[normalizedDay] ?? [];
  }

  void _groupEvents(List<Event> events) {
    _groupedEvents = {};
    for (var event in events) {
      final normalizedDay = DateTime(
          event.startTime.year, event.startTime.month, event.startTime.day);
      if (_groupedEvents[normalizedDay] != null) {
        _groupedEvents[normalizedDay]!.add(event);
      } else {
        _groupedEvents[normalizedDay] = [event];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EventFormPage(),
                ),
              ).then((_) {
                if (mounted) {
                  context.read<EventProvider>().loadEvents();
                }
              });
            },
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.error}'),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) {
                        provider.loadEvents();
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          _groupEvents(provider.events);

          return Column(
            children: [
              _buildCalendar(),
              const Divider(height: 1),
              Expanded(
                child: _buildEventList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      eventLoader: _getEventsForDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      calendarStyle: const CalendarStyle(
        markersMaxCount: 3,
        markerDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
      ),
    );
  }

  Widget _buildEventList() {
    final selectedEvents = _getEventsForDay(_selectedDay);

    if (selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              size: 50,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '${DateFormat('yyyy년 MM월 dd일').format(_selectedDay)}에 일정이 없습니다',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: selectedEvents.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        return EventListTile(event: event);
      },
    );
  }
}

class EventListTile extends StatelessWidget {
  final Event event;

  const EventListTile({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (event.location != null && event.location!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      event.location!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('Edit'),
              onTap: () {
                final currentContext = context;
                Navigator.push(
                  currentContext,
                  MaterialPageRoute(
                    builder: (context) => EventFormPage(event: event),
                  ),
                ).then((_) {
                  if (currentContext.mounted) {
                    Provider.of<EventProvider>(currentContext, listen: false)
                        .loadEvents();
                  }
                });
              },
            ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () {
                final currentContext = context;
                showDialog(
                  context: currentContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete Event'),
                    content: const Text(
                        'Are you sure you want to delete this event?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Provider.of<EventProvider>(currentContext,
                                  listen: false)
                              .deleteEvent(event.id);
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
