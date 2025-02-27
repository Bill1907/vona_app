import 'package:flutter/material.dart';
import '../../../core/models/journal.dart';

class JournalCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: journal.keywords
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
                journal.title,
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
              Row(
                children: [
                  Text(
                    journal.createdAt.toString().substring(0, 10),
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
