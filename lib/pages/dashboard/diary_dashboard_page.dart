import 'package:flutter/material.dart';
import 'package:vona_app/core/models/journal.dart';
import 'package:vona_app/core/supabase/journal_service.dart';

class DiaryDashboardPage extends StatefulWidget {
  const DiaryDashboardPage({super.key});

  @override
  State<DiaryDashboardPage> createState() => _DiaryDashboardPageState();
}

class _DiaryDashboardPageState extends State<DiaryDashboardPage> {
  List<Journal> _monthlyJournals = [];
  bool _isLoading = true;
  bool _showBarAnimation = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlyJournals();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showBarAnimation = true;
        });
      }
    });
  }

  Future<void> _loadMonthlyJournals() async {
    setState(() {
      _isLoading = true;
    });

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    try {
      final journals = await JournalService.getJournals();
      final monthlyJournals = journals.where((journal) {
        return journal.createdAt.isAfter(startOfMonth) &&
            journal.createdAt.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();

      setState(() {
        _monthlyJournals = monthlyJournals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onMonthChanged(DateTime newDate) async {
    setState(() {
      _selectedDate = newDate;
      _showBarAnimation = false;
    });
    await _loadMonthlyJournals();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showBarAnimation = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMonthSelector(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Column(
                  children: [
                    _buildProgressCard(),
                    const SizedBox(height: 16),
                    _buildJournalStatsCard(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                _onMonthChanged(
                  DateTime(
                    _selectedDate.year,
                    _selectedDate.month - 1,
                    1,
                  ),
                );
              },
            ),
            GestureDetector(
              onTap: () async {
                final lastDate = DateTime(2025, 12, 31);
                final firstDate = DateTime(2020, 1, 1);

                // Ensure initialDate is within the valid range
                DateTime initialDate = _selectedDate;
                if (initialDate.isAfter(lastDate)) {
                  initialDate = lastDate;
                } else if (initialDate.isBefore(firstDate)) {
                  initialDate = firstDate;
                }

                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null) {
                  _onMonthChanged(picked);
                }
              },
              child: Text(
                '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                _onMonthChanged(
                  DateTime(
                    _selectedDate.year,
                    _selectedDate.month + 1,
                    1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;

    // Count unique dates instead of total journals
    final uniqueDates = _monthlyJournals
        .map((journal) => DateTime(
              journal.createdAt.year,
              journal.createdAt.month,
              journal.createdAt.day,
            ))
        .toSet();

    final completedDays = uniqueDates.length;
    final progress = ((completedDays / daysInMonth) * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your progress',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(
                    begin: 0,
                    end: progress.toDouble(),
                  ),
                  builder: (context, value, child) {
                    return Text(
                      '${value.toInt()}%',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Of the monthly\njournal completed',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Text(
                    _getMonthName(_selectedDate.month),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildCalendarGrid(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth =
        DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday;

    final List<List<int?>> weeks = [];
    List<int?> currentWeek = [];

    // Add empty spaces for days before the first day of month
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(null);
    }

    for (int day = 1; day <= daysInMonth; day++) {
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
      currentWeek.add(day);
    }

    while (currentWeek.length < 7) {
      currentWeek.add(null);
    }
    weeks.add(currentWeek);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              SizedBox(
                  width: 20,
                  child: Text('M',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12))),
              SizedBox(
                  width: 24,
                  child: Text('T',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12))),
              SizedBox(
                  width: 24,
                  child: Text('W',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12))),
              SizedBox(
                  width: 24,
                  child: Text('T',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12))),
              SizedBox(
                  width: 24,
                  child: Text('F',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12))),
              SizedBox(
                  width: 24,
                  child: Text('S',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.blue))),
              SizedBox(
                  width: 20,
                  child: Text('S',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.red))),
            ],
          ),
        ),
        ...weeks.map((week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: week.map((day) {
                if (day == null) {
                  return Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 4),
                  );
                }
                final isCompleted = _monthlyJournals
                    .any((journal) => journal.createdAt.day == day);
                return Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color.fromARGB(200, 58, 112, 239)
                        : const Color.fromARGB(40, 58, 112, 239),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJournalStatsCard() {
    final emotions = ['neutral', 'happy', 'sad', 'angry'];
    final emotionCounts = {
      for (final e in emotions)
        e: _monthlyJournals.where((j) => j.emotion == e).length
    };

    final maxCount = emotionCounts.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Journal Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'for ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildEmotionBar('neutral', Colors.lightGreen,
                      maxCount == 0 ? 0 : emotionCounts['neutral']! / maxCount),
                  _buildEmotionBar('happy', Colors.yellow,
                      maxCount == 0 ? 0 : emotionCounts['happy']! / maxCount),
                  _buildEmotionBar('sad', Colors.blue[200]!,
                      maxCount == 0 ? 0 : emotionCounts['sad']! / maxCount),
                  _buildEmotionBar('angry', Colors.red[200]!,
                      maxCount == 0 ? 0 : emotionCounts['angry']! / maxCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionBar(String emotion, Color color, double percentage) {
    final count = _monthlyJournals.where((j) => j.emotion == emotion).length;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  height: _showBarAnimation ? 200 * percentage : 0,
                  width: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 1000),
                  opacity: _showBarAnimation ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          emotion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
