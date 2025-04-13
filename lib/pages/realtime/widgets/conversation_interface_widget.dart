import 'package:flutter/material.dart';
import '../../../core/models/conversation_message.dart';
import '../../../core/language/extensions.dart';
import '../../../widgets/animated_gradient_background.dart';

class ConversationInterfaceWidget extends StatefulWidget {
  final bool isInputActive;
  final bool isOutputActive;
  final bool isConversationStarted;
  final List<ConversationMessage>? messages;
  final Function(AnimationController controller) onControllerReady;
  final VoidCallback onSave;

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
  final ScrollController _scrollController = ScrollController();
  List<ConversationMessage>? _previousMessages;

  @override
  void initState() {
    super.initState();

    if (widget.messages != null && widget.messages!.isNotEmpty) {
      _previousMessages = List.of(widget.messages!);
      _scrollToBottom();
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 필요 시 사용자의 수동 스크롤에 대한 처리 추가 가능
  }

  @override
  void didUpdateWidget(ConversationInterfaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMessages = widget.messages;
    final oldMessages = _previousMessages;

    bool shouldScroll = false;

    if (currentMessages != null) {
      if (oldMessages == null || currentMessages.length != oldMessages.length) {
        shouldScroll = true;
      } else if (oldMessages != null &&
          currentMessages.isNotEmpty &&
          oldMessages.isNotEmpty) {
        final lastOldMsg = oldMessages.last;
        final lastCurrentMsg = currentMessages.last;

        if (lastOldMsg.text != lastCurrentMsg.text ||
            lastOldMsg.isFinal != lastCurrentMsg.isFinal) {
          shouldScroll = true;
        }
      }

      if (shouldScroll) {
        _previousMessages = List.of(currentMessages);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.isInputActive
        ? context.tr('listening')
        : widget.isOutputActive
            ? context.tr('speaking')
            : context.tr('askAnything');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBackground(
              isActive: widget.isConversationStarted,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            bottom: 330,
            child: widget.messages != null && widget.messages!.isNotEmpty
                ? _buildChatMessages()
                : _buildInitialPrompt(),
          ),
          if (!widget.isConversationStarted ||
              widget.messages == null ||
              widget.messages!.isEmpty)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          if (widget.isConversationStarted &&
              widget.messages != null &&
              widget.messages!.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A70EF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    context.tr('createDiary'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    final messagesKey = ValueKey('messages-${widget.messages?.length ?? 0}');

    return ListView.builder(
      key: messagesKey,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      reverse: true,
      itemCount: widget.messages?.length ?? 0,
      itemBuilder: (context, index) {
        final message = widget.messages![widget.messages!.length - 1 - index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildInitialPrompt() {
    String fontFam = 'Poppins';
    if (Localizations.localeOf(context).languageCode == 'ko') {
      fontFam = 'Pretendard';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr('initialGreeting'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: fontFam,
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
              fontFamily: fontFam,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';
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
                          color: Color(0xFF262626),
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        child: Text(
                          message.text.isEmpty
                              ? context.tr('listening')
                              : message.text,
                          style: const TextStyle(
                            color: Color(0xFFE2E2E2),
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
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
              const SizedBox(width: 10),
              if (isUser) _buildUserAvatar(),
            ],
          ),
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

  Widget _buildUserAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[700],
      backgroundImage: const AssetImage('assets/images/user_default_photo.png'),
    );
  }
}
