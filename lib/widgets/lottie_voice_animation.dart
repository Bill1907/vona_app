import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// LottieVoiceAnimation 위젯은 voice_animation.json Lottie 파일을 표시하는 위젯입니다.
/// 이 위젯은 음성 녹음이나 음성 인식 중에 시각적 피드백을 제공하는 데 사용할 수 있습니다.
class LottieVoiceAnimation extends StatelessWidget {
  /// 애니메이션의 너비
  final double? width;

  /// 애니메이션의 높이
  final double? height;

  /// 애니메이션이 반복되어야 하는지 여부
  final bool repeat;

  /// 애니메이션이 자동으로 시작되어야 하는지 여부
  final bool autoPlay;

  /// 애니메이션 컨트롤러 (선택 사항)
  final AnimationController? controller;

  /// 애니메이션 배경색
  final Color backgroundColor;

  /// 애니메이션 링 색상
  final Color ringColor;

  /// 배경을 어둡게 표시할지 여부
  final bool useDarkBackground;

  /// 기본 링 색상 (피그마에서 사용된 파란색)
  static const Color defaultRingColor = Color(0xFF3A70EF);

  const LottieVoiceAnimation({
    super.key,
    this.width,
    this.height,
    this.repeat = true,
    this.autoPlay = true,
    this.controller,
    this.backgroundColor = Colors.black,
    this.ringColor = defaultRingColor,
    this.useDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: useDarkBackground ? backgroundColor : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 기본 배경
          if (useDarkBackground)
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
            ),

          // 로티 애니메이션 - 원본 그대로 표시
          Lottie.asset(
            'assets/animations/voice_model.json',
            width: width,
            height: height,
            repeat: repeat,
            animate: autoPlay,
            controller: controller,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Lottie error: $error');
              return Container(
                width: width,
                height: height,
                color: Colors.grey.withAlpha(50),
                child: const Center(
                  child: Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// LottieVoiceAnimationWithController 위젯은 AnimationController가 필요한 경우 사용할 수 있는
/// StatefulWidget 버전의 LottieVoiceAnimation입니다.
class LottieVoiceAnimationWithController extends StatefulWidget {
  /// 애니메이션의 너비
  final double? width;

  /// 애니메이션의 높이
  final double? height;

  /// 애니메이션이 반복되어야 하는지 여부
  final bool repeat;

  /// 애니메이션이 자동으로 시작되어야 하는지 여부
  final bool autoPlay;

  /// 애니메이션 컨트롤러가 준비되었을 때 호출되는 콜백
  final void Function(AnimationController controller)? onControllerReady;

  /// 애니메이션 배경색
  final Color backgroundColor;

  /// 애니메이션 링 색상
  final Color ringColor;

  /// 배경을 어둡게 표시할지 여부
  final bool useDarkBackground;

  const LottieVoiceAnimationWithController({
    super.key,
    this.width,
    this.height,
    this.repeat = true,
    this.autoPlay = true,
    this.onControllerReady,
    this.backgroundColor = Colors.black,
    this.ringColor = LottieVoiceAnimation.defaultRingColor,
    this.useDarkBackground = true,
  });

  @override
  State<LottieVoiceAnimationWithController> createState() =>
      _LottieVoiceAnimationWithControllerState();
}

class _LottieVoiceAnimationWithControllerState
    extends State<LottieVoiceAnimationWithController>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // 애니메이션 지속 시간 (JSON 파일 기반)
    );

    if (widget.autoPlay) {
      _controller.repeat(reverse: false);
    }

    if (widget.onControllerReady != null) {
      widget.onControllerReady!(_controller);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.useDarkBackground
            ? widget.backgroundColor
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 기본 배경
          if (widget.useDarkBackground)
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.backgroundColor,
              ),
            ),

          // 로티 애니메이션 - 원본 그대로 표시
          Lottie.asset(
            'assets/animations/voice_model.json',
            width: widget.width,
            height: widget.height,
            controller: _controller,
            repeat: widget.repeat,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Lottie error: $error');
              return Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.withAlpha(50),
                child: const Center(
                  child: Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
