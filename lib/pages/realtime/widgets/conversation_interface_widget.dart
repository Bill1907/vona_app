import 'package:flutter/material.dart';
import '../../../widgets/voice_animations.dart';

/// 대화 인터페이스 위젯
///
/// 음성 대화 중 애니메이션과 상태를 표시하는 UI를 제공합니다.
class ConversationInterfaceWidget extends StatelessWidget {
  /// 입력 활성화 여부
  final bool isInputActive;

  /// 출력 활성화 여부
  final bool isOutputActive;

  /// 대화 시작 여부
  final bool isConversationStarted;

  /// 애니메이션 컨트롤러 콜백
  final Function(AnimationController controller) onControllerReady;

  /// 저장 버튼 클릭 콜백
  final VoidCallback onSave;

  /// 생성자
  const ConversationInterfaceWidget({
    super.key,
    required this.isInputActive,
    required this.isOutputActive,
    required this.isConversationStarted,
    required this.onControllerReady,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상단 공간
              const Spacer(flex: 1),

              // 음성 애니메이션
              Center(
                child: LottieVoiceAnimationWithController(
                  width: 210,
                  height: 210,
                  backgroundColor: Colors.transparent,
                  useDarkBackground: false,
                  ringColor: isInputActive
                      ? Color.fromRGBO(244, 67, 54, 0.8) // 사용자 입력 시 빨간색
                      : isOutputActive
                          ? Color(0xFF3A70EF) // AI 출력 시 파란색
                          : Color(0xFF3A70EF), // 평소에는 파란색
                  autoPlay: isConversationStarted && !isInputActive,
                  onControllerReady: onControllerReady,
                ),
              ),

              // 상태 텍스트
              const SizedBox(height: 86),
              Text(
                isConversationStarted
                    ? (isInputActive
                        ? "Listening..."
                        : isOutputActive
                            ? "Speaking..."
                            : "How can I help?")
                    : "How was your day today?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'poppins',
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              // 설명 텍스트
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  isConversationStarted
                      ? "Your conversation will be saved when you press the Save button"
                      : "Talk freely about your feelings and feel the feelings you felt today, check your emotions and see what you have spent.",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 하단 공간
              const Spacer(flex: 1),

              // 저장 버튼
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A70EF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
