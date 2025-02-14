import 'package:flutter/material.dart';

class EmotionHelper {
  static IconData getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_very_dissatisfied;
      case 'angry':
        return Icons.mood_bad;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.emoji_emotions;
    }
  }

  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'neutral':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }
}
