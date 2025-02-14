import 'package:flutter/material.dart';
import 'package:vona_app/core/models/journal.dart';
import 'package:vona_app/pages/diary/components/emotion_helper.dart';

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
              Row(
                children: [
                  Icon(
                    EmotionHelper.getEmotionIcon(journal.emotion),
                    color: EmotionHelper.getEmotionColor(journal.emotion),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    journal.createdAt.toString().substring(0, 10),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                journal.summary,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: journal.keywords
                    .map((keyword) => Chip(
                          label: Text(keyword),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
