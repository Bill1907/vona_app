import 'package:flutter/material.dart';
import '../../core/models/journal.dart';
import '../../core/supabase/journal_service.dart';
import '../../widgets/fade_bottom_scroll_view.dart';
import '../../core/language/extensions.dart';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMonthlyJournals();
    _createBannerAd();
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

  void _createBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: Platform.isAndroid
          ? dotenv.get('GOOGLE_ADMOB_BANNER_ANDROID_ID')
          : dotenv.get('GOOGLE_ADMOB_BANNER_IOS_ID'),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('dashboard'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            fontFamily: 'Poppins',
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: FadeBottomScrollView(
              fadeHeight: 100,
              child: SafeArea(
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
              ),
            ),
          ),
          if (_isAdLoaded)
            Container(
              alignment: Alignment.center,
              width: _bannerAd?.size.width.toDouble(),
              height: _bannerAd?.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            child: IconButton(
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
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: GestureDetector(
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
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _getMonthName(_selectedDate.month),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF1F1F1)
                            : const Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextSpan(
                      text: ' ${_selectedDate.year}',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF1F1F1)
                            : const Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
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
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('yourProgress'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            fontFamily: 'Poppins',
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
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    fontFamily: 'Pretendard',
                  ),
                );
              },
            ),
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                child: Text(
                  context.tr('ofTheMonthlyJournalCompleted'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.3,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(
            begin: 0,
            end: progress / 100,
          ),
          builder: (context, value, child) {
            return Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF787880),
                borderRadius: BorderRadius.circular(25),
              ),
              child: FractionallySizedBox(
                widthFactor: value,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF3A70EF),
                        Color(0xFF6290FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('history'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            _buildCalendarGrid(),
          ],
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    final monthKeys = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december'
    ];
    return context.tr(monthKeys[month - 1]);
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
                width: 42,
                child: Text(context.tr('mon'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('tue'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('wed'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('thu'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('fri'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('sat'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
            SizedBox(width: 6),
            SizedBox(
                width: 42,
                child: Text(context.tr('sun'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF747474),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ))),
          ],
        ),
        const SizedBox(height: 12),
        ...weeks.map((week) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: week.map((day) {
              if (day == null) {
                return Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 6, bottom: 8),
                );
              }
              final isCompleted = _monthlyJournals
                  .any((journal) => journal.createdAt.day == day);
              return Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 6, bottom: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF3A70EF)
                      : const Color(0xFF787880),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isCompleted
                          ? const Color(0xFFFEFEFE)
                          : const Color(0xFFA3A3A3),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard',
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildJournalStatsCard() {
    final emotions = _monthlyJournals.map((j) => j.emotion).toSet().toList();

    final emotionCounts = {
      for (final e in emotions)
        e: _monthlyJournals.where((j) => j.emotion == e).length
    };

    final maxCount = emotionCounts.isEmpty
        ? 0
        : emotionCounts.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('journalStats'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Column(
          children: emotionCounts.entries.map((entry) {
            return _buildEmotionBar(
                entry.key,
                Color((Random().nextDouble() * 0xFFFFFF).toInt())
                    .withAlpha(255),
                maxCount == 0 ? 0 : entry.value / maxCount);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmotionBar(String emotion, Color color, double percentage) {
    final count = _monthlyJournals.where((j) => j.emotion == emotion).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                emotion,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF747474),
                  fontFamily: 'Poppins',
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                context
                    .tr('journalsCount')
                    .replaceAll('{count}', count.toString()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF747474),
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 24,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF787880),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                height: 24,
                width: _showBarAnimation ? 300 * percentage : 0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      color,
                      color.withAlpha(170),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
