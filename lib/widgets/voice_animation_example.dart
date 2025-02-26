import 'package:flutter/material.dart';
import 'lottie_voice_animation.dart';

/// VoiceAnimationExample 위젯은 LottieVoiceAnimation 위젯의 사용 예시를 보여줍니다.
class VoiceAnimationExample extends StatelessWidget {
  const VoiceAnimationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              '음성 애니메이션 예제',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            const Text(
              '기본 애니메이션',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              height: 250,
              width: 250,
              child: LottieVoiceAnimation(
                backgroundColor: Colors.black,
                ringColor: Color(0xFF3A70EF),
                useDarkBackground: true,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              '음성 녹음 버튼',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const SimpleVoiceButton(),
          ],
        ),
      ),
    );
  }
}

/// SimpleVoiceButton 위젯은 간단한 음성 버튼 예시입니다.
class SimpleVoiceButton extends StatefulWidget {
  const SimpleVoiceButton({super.key});

  @override
  State<SimpleVoiceButton> createState() => _SimpleVoiceButtonState();
}

class _SimpleVoiceButtonState extends State<SimpleVoiceButton> {
  bool _isActive = false;

  // Define the ring color as a constant
  static const Color ringBlueColor = Color(0xFF3A70EF);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isActive = !_isActive;
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ringBlueColor.withAlpha(60),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                // Add a second, more intense inner glow
                BoxShadow(
                  color: ringBlueColor.withAlpha(100),
                  blurRadius: 7,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: LottieVoiceAnimation(
                  backgroundColor: Colors.black,
                  ringColor: ringBlueColor,
                  useDarkBackground: true,
                  autoPlay: _isActive,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isActive ? '녹음 중...' : '탭하여 녹음',
          style: TextStyle(
            fontSize: 14,
            fontWeight: _isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
