import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 연결 상태 표시 위젯
///
/// WebRTC 연결 및 초기화 과정에서의 상태를 시각적으로 보여줍니다.
class ConnectionStatusWidget extends StatelessWidget {
  /// 현재 상태 텍스트
  final String status;

  /// 생성자
  const ConnectionStatusWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomProgressIndicator(
                startColor: Color(0xFF3A70EF),
                endColor: Color(0x203A70EF), // 같은 색상에 투명도만 낮게 설정
              ),
            ),
            const SizedBox(height: 48),
            Text(
              status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait a moment...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Poppins',
                    color: Colors.grey[400],
                    letterSpacing: -0.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 커스텀 원형 프로그레스 인디케이터
class CustomProgressIndicator extends StatefulWidget {
  final Color startColor;
  final Color endColor;

  const CustomProgressIndicator({
    super.key,
    required this.startColor,
    required this.endColor,
  });

  @override
  State<CustomProgressIndicator> createState() =>
      _CustomProgressIndicatorState();
}

class _CustomProgressIndicatorState extends State<CustomProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: GradientCircularProgressPainter(
            progress: _controller.value,
            strokeWidth: 6.0,
            startColor: widget.startColor,
            endColor: widget.endColor,
            useStartDot: false,
          ),
        );
      },
    );
  }
}

/// 그라데이션과 원형 시작점을 적용한 원형 프로그레스 페인터
class GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color startColor;
  final Color endColor;
  final bool useStartDot;

  GradientCircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.startColor,
    required this.endColor,
    this.useStartDot = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - strokeWidth / 2;

    final backgroundColor = const Color(0xFF1681FF)
        .withAlpha(64); // 어두운 파란색 배경색 (25% 불투명도 = 0.25 * 255 = 64)

    // 전체 원을 어두운 파란색으로 그림 (배경)
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 그라데이션을 적용한 짧은 호를 그림
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 아크의 시작 각도
    final startAngle = progress * 2 * math.pi;
    // 아크의 크기 (45도)
    final sweepAngle = math.pi / 3;

    // 그라데이션용 쉐이더 생성
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      tileMode: TileMode.clamp,
      colors: [
        startColor, // 밝은 파란색 시작
        startColor.withAlpha(3), // 약간 투명해짐 (1% 불투명도 = 0.01 * 255 = ~3)
        startColor.withAlpha(0), // 완전 투명
      ],
      stops: const [0.0, 0.76, 1.0],
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 짧은 호를 그림 (약 45도)
    canvas.drawArc(
      rect,
      startAngle, // 시작 각도
      sweepAngle, // 45도의 호
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant GradientCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
