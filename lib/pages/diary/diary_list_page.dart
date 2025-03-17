import 'package:flutter/material.dart';

import '../../core/models/journal.dart';
import '../../core/supabase/journal_service.dart';
import '../../core/language/extensions.dart';
import 'components/date_selector.dart';
import 'components/journal_card.dart';
import 'diary_detail_page.dart';
import '../../widgets/fade_bottom_scroll_view.dart';

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
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    print('Starting to load journals in DiaryListPage');
    try {
      print('Calling JournalService.getJournals()');
      final journals = await JournalService.getJournals();
      print('Received ${journals.length} journals from service');
      setState(() {
        _journals = journals;
        _isLoading = false;
      });
      print('State updated with journals');
    } catch (e) {
      print('Error loading journals: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('failedToDeleteJournal'))),
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
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            context.tr('myJournals'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              fontFamily: 'Poppins',
              letterSpacing: -0.3,
            ),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiaryDetailPage(
                      journal: Journal(
                        id: '',
                        title: '',
                        content: '',
                        emotion: '',
                        createdAt: DateTime.now(),
                        keywords: [],
                        conversationId: '',
                      ),
                    ),
                  ),
                ).then((_) => _loadJournals());
              },
              tooltip: context.tr('createNewJournal'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeBottomScrollView(
                fadeHeight: 50,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            context.tr('history'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadJournals,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _journals.length,
                            itemBuilder: (context, index) {
                              final journal = _journals[index];
                              final isSelected = journal.createdAt.year ==
                                      _selectedDate.year &&
                                  journal.createdAt.month ==
                                      _selectedDate.month &&
                                  journal.createdAt.day == _selectedDate.day;
                              return JournalCard(
                                journal: journal,
                                isSelected: isSelected,
                                onTap: () {
                                  // Scroll the card to top first
                                  _scrollController.animateTo(
                                    index *
                                        200.0, // Approximate height of a card including margins
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );

                                  // Show modal after scrolling
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    enableDrag: true,
                                    showDragHandle: false,
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.95,
                                    ),
                                    builder: (context) =>
                                        DraggableScrollableSheet(
                                      initialChildSize: 0.5,
                                      minChildSize: 0.5,
                                      maxChildSize: 0.95,
                                      expand: false,
                                      controller: _dragController,
                                      builder: (context, scrollController) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                _dragController.animateTo(
                                                  0.95,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  curve: Curves.easeInOut,
                                                );
                                              },
                                              child: Container(
                                                width: 40,
                                                height: 4,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF585858),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: DiaryDetailPage(
                                                journal: journal,
                                                scrollController:
                                                    scrollController,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
              ));
  }
}
