import 'package:flutter/material.dart';
import '../../../widgets/voice_animations.dart';
import '../../../core/models/conversation_message.dart';
import '../../../core/language/extensions.dart';

/// 대화 인터페이스 위젯
///
/// 음성 대화 중 애니메이션과 상태를 표시하는 UI를 제공합니다.
class ConversationInterfaceWidget extends StatefulWidget {
  /// 입력 활성화 여부
  final bool isInputActive;

  /// 출력 활성화 여부
  final bool isOutputActive;

  /// 대화 시작 여부
  final bool isConversationStarted;

  /// 대화 메시지 목록
  final List<ConversationMessage>? messages;

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
    this.messages,
  });

  @override
  State<ConversationInterfaceWidget> createState() =>
      _ConversationInterfaceWidgetState();
}

class _ConversationInterfaceWidgetState
    extends State<ConversationInterfaceWidget> {
  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();
  List<ConversationMessage>? _previousMessages;

  @override
  void initState() {
    super.initState();

    // 이미 메시지가 있는 경우 초기 스크롤 실행
    if (widget.messages != null && widget.messages!.isNotEmpty) {
      _previousMessages = List.of(widget.messages!);
      _scrollToBottom();
    }

    // 스크롤 컨트롤러에 리스너 추가
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 이벤트 처리
  void _onScroll() {
    // 현재 이 리스너는 필요한 작업이 없음
    // 필요 시 사용자의 수동 스크롤에 대한 처리 추가 가능
  }

  @override
  void didUpdateWidget(ConversationInterfaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMessages = widget.messages;
    final oldMessages = _previousMessages;

    // 메시지가 변경된 경우 감지
    bool shouldScroll = false;

    if (currentMessages != null) {
      // 새 메시지가 추가된 경우
      if (oldMessages == null || currentMessages.length != oldMessages.length) {
        shouldScroll = true;
      }
      // 기존 메시지의 내용이 변경된 경우 (특히 마지막 메시지)
      else if (oldMessages != null &&
          currentMessages.isNotEmpty &&
          oldMessages.isNotEmpty) {
        // 마지막 메시지의 변경 확인
        final lastOldMsg = oldMessages.last;
        final lastCurrentMsg = currentMessages.last;

        if (lastOldMsg.text != lastCurrentMsg.text ||
            lastOldMsg.isFinal != lastCurrentMsg.isFinal) {
          shouldScroll = true;
        }
      }

      // 메시지 상태 업데이트
      if (shouldScroll) {
        _previousMessages = List.of(currentMessages);
        _scrollToBottom();
      }
    }
  }

  // 스크롤 위치를 최하단으로 이동
  void _scrollToBottom() {
    // 스크롤 이동은 위젯이 그려진 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 내용이 화면을 넘어갈 경우에만 스크롤 실행
        if (_scrollController.position.maxScrollExtent > 0) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 채팅 메시지 영역
        Expanded(
          child: widget.messages != null && widget.messages!.isNotEmpty
              ? _buildChatMessages()
              : _buildInitialPrompt(),
        ),

        // 하단 애니메이션 및 버튼
        _buildBottomSection(),
      ],
    );
  }

  /// 채팅 메시지 목록을 구성하는 위젯
  Widget _buildChatMessages() {
    // 메시지 리스트의 키 추가 (효율적인 리빌드를 위함)
    final messagesKey = ValueKey('messages-${widget.messages?.length ?? 0}');

    return ListView.builder(
      key: messagesKey,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      reverse: false, // 정방향 리스트 유지
      itemCount: widget.messages?.length ?? 0,
      itemBuilder: (context, index) {
        final message = widget.messages![index];
        return _buildMessageBubble(message);
      },
    );
  }

  /// 초기 프롬프트 화면을 구성하는 위젯
  Widget _buildInitialPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.isConversationStarted
                ? context.tr('initialGreeting')
                : context.tr('howWasYourDay'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('talkFreely'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 각 메시지 버블을 구성하는 위젯
  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';

    // 실시간 상태 표시 (메시지가 처리 중인 경우)
    final bool isProcessing = !message.isFinal;
    final bool isSpeaking = message.status == 'speaking';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: isUser
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A70EF),
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        child: Text(
                          message.text.isEmpty
                              ? context.tr('listening')
                              : message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          message.text.isEmpty
                              ? context.tr('thinking')
                              : message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 32),
              if (isUser) _buildUserAvatar(),
            ],
          ),

          // 상태 표시
          if (isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                isSpeaking ? context.tr('speaking') : context.tr('processing'),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: isUser ? TextAlign.right : TextAlign.left,
              ),
            ),
        ],
      ),
    );
  }

  /// 사용자 아바타 위젯
  Widget _buildUserAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[700],
      backgroundImage: const AssetImage('assets/images/user_default_photo.png'),
    );
  }

  /// 하단 섹션 구성 위젯
  Widget _buildBottomSection() {
    final statusText = widget.isInputActive
        ? context.tr('listening')
        : widget.isOutputActive
            ? context.tr('speaking')
            : context.tr('askAnything');

    return Container(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: Column(
        children: [
          // Save 버튼 - 대화가 시작된 경우에만 표시
          if (widget.isConversationStarted &&
              widget.messages != null &&
              widget.messages!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: widget.onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A70EF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  context.tr('createDiary'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // 3D 모델 애니메이션 (작게 표시)
          SizedBox(
            height: 120,
            width: 120,
            child: LottieVoiceAnimationWithController(
              width: 120,
              height: 120,
              backgroundColor: Colors.transparent,
              useDarkBackground: false,
              ringColor: widget.isInputActive
                  ? Color.fromRGBO(244, 67, 54, 0.8) // 사용자 입력 시 빨간색
                  : widget.isOutputActive
                      ? Color(0xFF3A70EF) // AI 출력 시 파란색
                      : Color(0xFF3A70EF), // 평소에는 파란색
              autoPlay: widget.isConversationStarted,
              onControllerReady: widget.onControllerReady,
            ),
          ),

          const SizedBox(height: 22),

          // 상태 텍스트
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'Poppins',
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 탭바 아이템 위젯
  Widget _buildTabBarItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
        ),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
