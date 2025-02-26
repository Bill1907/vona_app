import 'package:flutter/material.dart';
import 'lottie_voice_animation.dart';

/// VoiceRecordingButton 위젯은 음성 녹음 버튼을 제공합니다.
/// 이 버튼은 누르고 있는 동안 음성 애니메이션을 표시하고,
/// 녹음 시작/중지 콜백을 제공합니다.
class VoiceRecordingButton extends StatefulWidget {
  /// 버튼의 크기
  final double size;

  /// 녹음 시작 시 호출되는 콜백
  final VoidCallback? onRecordingStarted;

  /// 녹음 중지 시 호출되는 콜백
  final VoidCallback? onRecordingStopped;

  /// 버튼의 배경색
  final Color? backgroundColor;

  /// 버튼의 아이콘 색상
  final Color? iconColor;

  /// 애니메이션 링 색상
  final Color? ringColor;

  /// 녹음 중일 때 표시할 텍스트
  final String recordingText;

  /// 녹음 중이 아닐 때 표시할 텍스트
  final String idleText;

  /// 어두운 배경을 사용할지 여부
  final bool useDarkBackground;

  const VoiceRecordingButton({
    super.key,
    this.size = 80.0,
    this.onRecordingStarted,
    this.onRecordingStopped,
    this.backgroundColor,
    this.iconColor,
    this.ringColor = LottieVoiceAnimation.defaultRingColor,
    this.recordingText = '녹음 중...',
    this.idleText = '눌러서 녹음',
    this.useDarkBackground = true,
  });

  @override
  State<VoiceRecordingButton> createState() => _VoiceRecordingButtonState();
}

class _VoiceRecordingButtonState extends State<VoiceRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Add this field
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    _animationController.forward();
    if (widget.onRecordingStarted != null) {
      widget.onRecordingStarted!();
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _animationController.reverse();
    if (widget.onRecordingStopped != null) {
      widget.onRecordingStopped!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final iconColor = widget.iconColor ?? theme.colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => _startRecording(),
          onTapUp: (_) => _stopRecording(),
          onTapCancel: () => _stopRecording(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isRecording ? widget.size * 1.2 : widget.size,
            height: _isRecording ? widget.size * 1.2 : widget.size,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.ringColor!.withAlpha(60),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: widget.ringColor!.withAlpha(100),
                  blurRadius: 7,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: _isRecording
                  ? LottieVoiceAnimation(
                      width: widget.size * 0.8,
                      height: widget.size * 0.8,
                      ringColor: widget.ringColor!,
                      backgroundColor: Colors.black,
                      useDarkBackground: widget.useDarkBackground,
                    )
                  : Container(
                      width: widget.size * 0.8,
                      height: widget.size * 0.8,
                      decoration: BoxDecoration(
                        color: widget.useDarkBackground
                            ? Colors.black
                            : backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic,
                        color: iconColor,
                        size: widget.size * 0.5,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRecording ? widget.recordingText : widget.idleText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// PulsatingVoiceButton 위젯은 음성 인식 중에 맥박처럼 박동하는 버튼을 제공합니다.
class PulsatingVoiceButton extends StatefulWidget {
  /// 버튼의 크기
  final double size;

  /// 버튼을 탭했을 때 호출되는 콜백
  final VoidCallback? onTap;

  /// 버튼이 활성화되어 있는지 여부
  final bool isActive;

  /// 버튼의 배경색
  final Color? backgroundColor;

  /// 버튼의 활성 배경색
  final Color? activeBackgroundColor;

  /// 애니메이션 링 색상
  final Color? ringColor;

  /// 어두운 배경을 사용할지 여부
  final bool useDarkBackground;

  const PulsatingVoiceButton({
    super.key,
    this.size = 80.0,
    this.onTap,
    this.isActive = false,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.ringColor = LottieVoiceAnimation.defaultRingColor,
    this.useDarkBackground = true,
  });

  @override
  State<PulsatingVoiceButton> createState() => _PulsatingVoiceButtonState();
}

class _PulsatingVoiceButtonState extends State<PulsatingVoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsatingVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final activeBackgroundColor =
        widget.activeBackgroundColor ?? theme.colorScheme.secondary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isActive ? _pulseAnimation.value : 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.ringColor!.withAlpha(60),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: widget.ringColor!.withAlpha(100),
                    blurRadius: 7,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: widget.isActive
                    ? LottieVoiceAnimation(
                        width: widget.size * 0.7,
                        height: widget.size * 0.7,
                        backgroundColor: Colors.black,
                        ringColor: widget.ringColor!,
                        useDarkBackground: widget.useDarkBackground,
                      )
                    : Container(
                        width: widget.size * 0.7,
                        height: widget.size * 0.7,
                        decoration: BoxDecoration(
                          color: widget.useDarkBackground
                              ? Colors.black
                              : backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mic,
                          color: theme.colorScheme.onPrimary,
                          size: widget.size * 0.5,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
