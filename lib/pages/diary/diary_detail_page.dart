import 'package:flutter/material.dart';
import 'package:vona_app/core/models/journal.dart';
import 'package:vona_app/core/models/conversation.dart';
import 'package:vona_app/core/supabase/conversation_service.dart';
import 'package:vona_app/core/supabase/profile_service.dart';
import 'package:vona_app/core/supabase/auth_service.dart';
import 'dart:convert';

class DiaryDetailPage extends StatefulWidget {
  final Journal journal;
  final ScrollController? scrollController;

  const DiaryDetailPage({
    super.key,
    required this.journal,
    this.scrollController,
  });

  @override
  State<DiaryDetailPage> createState() => _DiaryDetailPageState();
}

class _DiaryDetailPageState extends State<DiaryDetailPage> {
  Conversation? _conversation;
  bool _isLoading = true;
  String? _userAvatarUrl;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _loadUserAvatar();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadUserAvatar() async {
    if (_disposed) return;

    try {
      final userId = AuthService.currentUserId;
      if (userId == null || _disposed) return;

      final profile = await ProfileService.getProfile(userId);
      if (_disposed) return;

      _safeSetState(() {
        _userAvatarUrl = profile['avatar_url'];
      });
    } catch (e) {
      print('Error loading user avatar: $e');
    }
  }

  Future<void> _loadConversation() async {
    if (_disposed) return;

    try {
      final conversation = await ConversationService.getConversation(
          widget.journal.conversationId);

      if (_disposed) return;

      _safeSetState(() {
        _conversation = conversation;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversation: $e');
      if (_disposed) return;

      _safeSetState(() {
        _isLoading = false;
      });

      if (!_disposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load conversation.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF353535),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF747474),
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.journal.createdAt.toString().split(' ')[0],
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF353535),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Keywords',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF747474),
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: widget.journal.keywords
                              .map((keyword) => Text(
                                    keyword,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                      letterSpacing: -0.3,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF353535),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emotion',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF747474),
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.journal.emotion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF353535),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF747474),
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.journal.summary,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF353535),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conversation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF747474),
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_conversation != null)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                (jsonDecode(_conversation!.contents) as List)
                                    .length,
                            itemBuilder: (context, index) {
                              final messages =
                                  jsonDecode(_conversation!.contents) as List;
                              final message =
                                  messages[index] as Map<String, dynamic>;
                              final role = message['role'] as String;
                              final content = message['content'] as String;

                              return Center(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  margin: const EdgeInsets.only(bottom: 24),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: role == 'user'
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (role != 'user')
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF404040),
                                            image: const DecorationImage(
                                              image: AssetImage(
                                                  'assets/icons/vona_logo.png'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: role == 'user'
                                                ? const Color(0xFF3A70EF)
                                                : const Color(0xFF404040),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Text(
                                            content,
                                            style: const TextStyle(
                                              color: Color(0xFFE2E2E2),
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (role == 'user')
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF404040),
                                            image: DecorationImage(
                                              image: _userAvatarUrl != null
                                                  ? NetworkImage(
                                                      _userAvatarUrl!)
                                                  : const AssetImage(
                                                          'assets/images/user_profile.png')
                                                      as ImageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
