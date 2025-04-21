import 'package:flutter/material.dart';
import '../../../core/models/journal.dart';
import '../../../core/crypt/encrypt.dart';
import 'package:provider/provider.dart';

class JournalCard extends StatefulWidget {
  final Journal journal;
  final bool isSelected;
  final VoidCallback? onTap;

  const JournalCard({
    super.key,
    required this.journal,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<JournalCard> createState() => _JournalCardState();
}

class _JournalCardState extends State<JournalCard> {
  String _decryptedContent = '';
  bool _isDecrypting = true;

  @override
  void initState() {
    super.initState();
    _decryptJournalContent();
  }

  Future<void> _decryptJournalContent() async {
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
        if (mounted) {
          setState(() {
            _decryptedContent = encryptedContent;
            _isDecrypting = false;
          });
        }
        return;
      }

      print('Decrypting journal ${widget.journal.id}');
      // Decrypt the content
      final decryptedContent = encryptService.decryptData(encryptedContent, iv);

      if (mounted) {
        setState(() {
          _decryptedContent = decryptedContent;
          _isDecrypting = false;
        });
      }
    } catch (e) {
      print('Error decrypting journal content in card: $e');
      if (mounted) {
        setState(() {
          _decryptedContent = widget.journal.content;
          _isDecrypting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: widget.isSelected ? 8 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: widget.journal.keywords
                    .map((keyword) => Chip(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 4,
                          ),
                          label: Text(keyword,
                              style: const TextStyle(
                                color: Color(0xFFE2E2E2),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Poppins',
                                letterSpacing: -0.03,
                              )),
                          labelStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          side: BorderSide(
                            color: Color(0xFF3A70EF),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                widget.journal.title,
                style: const TextStyle(
                  color: Color(0xFFE2E2E2),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Poppins',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (_isDecrypting)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Text(
                  _decryptedContent.isNotEmpty
                      ? _decryptedContent.length > 50
                          ? '${_decryptedContent.substring(0, 50)}...'
                          : _decryptedContent
                      : widget.journal.content,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    widget.journal.createdAt.toString().substring(0, 10),
                    style: const TextStyle(
                      color: Color(0xFF7F7F7F),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
