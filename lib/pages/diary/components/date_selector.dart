import 'package:flutter/material.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: 372,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: 2 - index));
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  width: 55,
                  height: 130,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3A70EF)
                        : const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF262626),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        _getMonthName(date.month),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                            ),
                      ),
                      Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: 28,
                              fontFamily: 'Pretendard',
                              letterSpacing: -0.3,
                            ),
                      ),
                      Text(
                        _getWeekdayName(date.weekday),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : _getWeekdayColor(context, date.weekday),
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Left gradient overlay
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withAlpha(0),
                    Colors.black.withAlpha(204),
                  ],
                ),
              ),
            ),
          ),
          // Right gradient overlay
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withAlpha(0),
                    Colors.black.withAlpha(204),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[weekday - 1];
  }

  Color _getWeekdayColor(BuildContext context, int weekday) {
    if (weekday == 6) {
      // Saturday
      return Colors.blue;
    } else if (weekday == 7) {
      // Sunday
      return Colors.red;
    }
    return Theme.of(context).colorScheme.onSurface;
  }
}
