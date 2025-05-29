import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class EmptyCalendarView extends StatelessWidget {
  const EmptyCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: DateTime.now(),
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(color: Colors.transparent),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'No events scheduled yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const Text(
          'Tap the \'+\' button to add a new event.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
