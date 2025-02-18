import 'package:flutter/material.dart';

/// FadeBottomScrollView 위젯은 주어진 자식 위젯(SingleChildScrollView 등)의 하단에
/// 자동으로 쉐이딩(fade out) 효과를 오버레이합니다.
class FadeBottomScrollView extends StatelessWidget {
  final Widget child;
  final double fadeHeight;

  const FadeBottomScrollView({
    super.key,
    required this.child,
    this.fadeHeight = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    // Scaffold 등의 배경색과 일치하도록 배경색을 가져옵니다.
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        child,
        // IgnorePointer를 사용하여 터치 이벤트가 차단되지 않도록 합니다.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: fadeHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    bgColor, // 하단은 배경색
                    bgColor.withAlpha(0), // 위로 갈수록 투명
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
