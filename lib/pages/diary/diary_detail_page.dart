import 'package:flutter/material.dart';
import '../../core/models/journal.dart';
import '../../core/models/conversation.dart';
import '../../core/supabase/conversation_service.dart';
import '../../core/supabase/profile_service.dart';
import '../../core/supabase/auth_service.dart';
import 'dart:convert';
import '../../core/crypt/encrypt.dart';
import 'package:provider/provider.dart';
import 'dart:math' show min;

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
  String _decryptedContent = '';

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _loadUserAvatar();
    _decryptJournalContent();
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

  Future<void> _decryptJournalContent() async {
    if (_disposed) return;

    try {
      // Get the EncryptService from provider
      final encryptService =
          Provider.of<EncryptService>(context, listen: false);

      // Get the encrypted content and IV from the journal
      final encryptedContent = widget.journal.content;
      final iv = widget.journal.iv;

      // IV가 null이거나 비어있으면 암호화되지 않은 콘텐츠로 간주
      if (iv == null || iv.isEmpty) {
        print('Journal ${widget.journal.id} is not encrypted (no IV)');
        _safeSetState(() {
          _decryptedContent = encryptedContent;
        });
        return;
      }

      print('Decrypting journal ${widget.journal.id} in detail view');
      // Decrypt the content
      final decryptedContent = encryptService.decryptData(encryptedContent, iv);

      _safeSetState(() {
        _decryptedContent = decryptedContent;
      });
    } catch (e, stackTrace) {
      print('Error decrypting journal content: $e');
      print('Stack trace: $stackTrace');

      _safeSetState(() {
        // On error, show the encrypted content with an error note
        _decryptedContent =
            'Failed to decrypt content: ${widget.journal.content}';
      });
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

    // Get encryptService at the beginning, before any async gaps
    final encryptService = Provider.of<EncryptService>(context, listen: false);

    try {
      print(
          'Loading conversation for journal ID: ${widget.journal.conversationId}');
      final conversation = await ConversationService.getConversation(
          widget.journal.conversationId);

      if (_disposed) return;

      if (conversation != null) {
        try {
          String contentsToUse = conversation.contents;
          bool isDecrypted = false;

          // 1. 먼저 직접 JSON 파싱 시도 (IV가 없거나 이미 복호화된 경우)
          try {
            print('Trying to parse conversation contents directly');
            final directParsed = jsonDecode(contentsToUse);
            if (directParsed is List) {
              print('Successfully parsed conversation directly as list');
              isDecrypted = true;
            }
          } catch (directParseErr) {
            print('Direct parsing failed: $directParseErr');
          }

          // 2. 직접 파싱 실패했고 IV가 있으면 복호화 시도
          if (!isDecrypted &&
              conversation.iv != null &&
              conversation.iv.isNotEmpty) {
            try {
              print(
                  'Attempting to decrypt conversation with IV: ${conversation.iv}');
              final decryptedContents = encryptService.decryptData(
                  conversation.contents, conversation.iv);

              // 복호화된 내용 파싱 시도
              final decryptedParsed = jsonDecode(decryptedContents);
              if (decryptedParsed is List) {
                print('Successfully decrypted and parsed as list');
                contentsToUse = decryptedContents;
                isDecrypted = true;
              }
            } catch (decryptErr) {
              print('Decryption failed: $decryptErr');
            }
          }

          // 3. 파싱 또는 복호화 성공한 경우 대화 내용 업데이트
          if (isDecrypted) {
            _safeSetState(() {
              _conversation = Conversation(
                id: conversation.id,
                contents: contentsToUse,
                userId: conversation.userId,
                createdAt: conversation.createdAt,
                iv: conversation.iv,
              );
              _isLoading = false;
            });
            return;
          }

          // 4. 모든 방법 실패 시 빈 대화로 초기화
          print(
              'All parsing/decryption attempts failed, initializing empty conversation');
          _safeSetState(() {
            _conversation = Conversation(
              id: conversation.id,
              contents: '[]',
              userId: conversation.userId,
              createdAt: conversation.createdAt,
              iv: conversation.iv,
            );
            _isLoading = false;
          });
        } catch (e) {
          print('Error handling conversation: $e');
          if (!_disposed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not process conversation data'),
                backgroundColor: Colors.red,
              ),
            );
          }

          _safeSetState(() {
            _conversation = Conversation(
              id: conversation.id,
              contents: '[]',
              userId: conversation.userId,
              createdAt: conversation.createdAt,
              iv: conversation.iv,
            );
            _isLoading = false;
          });
          return;
        }
      } else {
        _safeSetState(() {
          _conversation = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading conversation: $e');
      if (_disposed) return;

      _safeSetState(() {
        _isLoading = false;
      });

      if (!_disposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load conversation.'),
            backgroundColor: Colors.red,
          ),
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
                          'Title',
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
                          widget.journal.title,
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
                          'Content',
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
                          _decryptedContent.isNotEmpty
                              ? _decryptedContent
                              : widget.journal.content,
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
                            itemCount: _conversation != null
                                ? (() {
                                    try {
                                      final decoded =
                                          jsonDecode(_conversation!.contents);
                                      return (decoded is List)
                                          ? decoded.length
                                          : 0;
                                    } catch (e) {
                                      print('Error in itemCount: $e');
                                      return 0;
                                    }
                                  })()
                                : 0,
                            itemBuilder: (context, index) {
                              List<dynamic> messages = [];
                              try {
                                final decoded =
                                    jsonDecode(_conversation!.contents);
                                messages = decoded is List ? decoded : [];
                              } catch (e) {
                                print(
                                    'Error decoding conversation contents: $e');
                                return const Center(
                                  child: Text(
                                      'Error: Could not decode conversation data',
                                      style: TextStyle(color: Colors.red)),
                                );
                              }

                              if (index >= messages.length) {
                                return const SizedBox.shrink();
                              }

                              final message =
                                  messages[index] as Map<String, dynamic>;
                              final role = message['role'] as String? ?? 'user';
                              final content = message['text'] as String? ?? '';

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
                                                : const Color(0xFF2A2A2A),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            content,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              height: 1.5,
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
                                            image: DecorationImage(
                                              image: _userAvatarUrl != null
                                                  ? NetworkImage(
                                                      _userAvatarUrl!)
                                                  : const AssetImage(
                                                          'assets/images/user_default_photo.png')
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
