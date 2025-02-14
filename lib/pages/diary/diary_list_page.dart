import 'package:flutter/material.dart';

import 'package:vona_app/core/models/journal.dart';
import 'package:vona_app/core/supabase/journal_service.dart';
import 'package:vona_app/pages/diary/components/date_selector.dart';
import 'package:vona_app/pages/diary/components/journal_card.dart';
import 'package:vona_app/pages/diary/diary_detail_page.dart';

import 'dart:math' as math;

class DiaryListPage extends StatefulWidget {
  const DiaryListPage({super.key});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage> {
  List<Journal> _journals = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    try {
      final journals = await JournalService.getJournals();
      setState(() {
        _journals = journals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load journals.')),
        );
      }
    }
  }

  void _scrollToSelectedDate() {
    if (_journals.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final index = _journals.indexWhere((journal) =>
        journal.createdAt.year == _selectedDate.year &&
        journal.createdAt.month == _selectedDate.month &&
        journal.createdAt.day == _selectedDate.day);

    if (index != -1) {
      final screenHeight = MediaQuery.of(context).size.height;
      final cardHeight =
          200.0; // Approximate height of a card including margins
      final offset = index * cardHeight;
      final screenCenter = screenHeight / 2;
      final scrollOffset = offset - screenCenter + cardHeight / 2;

      _scrollController.animateTo(
        math.max(0, scrollOffset),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_journals.isEmpty) {
      return const Center(
        child: Text('No journals written yet.'),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            DateSelector(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _scrollToSelectedDate();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadJournals,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _journals.length,
                  itemBuilder: (context, index) {
                    final journal = _journals[index];
                    final isSelected =
                        journal.createdAt.year == _selectedDate.year &&
                            journal.createdAt.month == _selectedDate.month &&
                            journal.createdAt.day == _selectedDate.day;
                    return JournalCard(
                      journal: journal,
                      isSelected: isSelected,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DiaryDetailPage(journal: journal),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
