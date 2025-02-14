import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/models/journal.dart';
import '../../core/supabase/conversation_service.dart';
import '../../core/supabase/journal_service.dart';
import '../../core/network/http_service.dart';

class AiVoiceChatPage extends StatefulWidget {
  const AiVoiceChatPage({super.key});

  @override
  State<AiVoiceChatPage> createState() => _AiVoiceChatPageState();
}

class _AiVoiceChatPageState extends State<AiVoiceChatPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final Map<String, dynamic> parsedMessage =
                jsonDecode(message.message);
            handleWebMessage(parsedMessage);
          } catch (e) {
            print('Error parsing message from web: $e');
          }
        },
      )
      ..loadRequest(Uri.parse(
          '${dotenv.env['WEB_VIEW_URL']}/voice-chat/${Supabase.instance.client.auth.currentUser?.id}'));
  }

  Future<void> handleWebMessage(Map<String, dynamic> data) async {
    try {
      switch (data['type']) {
        case 'message':
          print(data['data']);
          final conversationId = await ConversationService.createConversation(
              data['data'] as List<dynamic>);
          print('Conversation created: $conversationId');

          // Call API with the conversation ID
          try {
            await HttpService.instance.post(
              'createJournals',
              body: {
                'conversation': data['data'],
              },
              onSuccess: (data) async {
                print('API response: $data');

                // Create journal from API response
                final journal = Journal(
                  keywords: List<String>.from(data['keywords']),
                  emotion: data['emotion'],
                  summary: data['summary'],
                  conversationId: conversationId,
                );

                try {
                  final createdJournal =
                      await JournalService.createJournal(journal);
                  print('Journal created: ${createdJournal.id}');
                } catch (e) {
                  print('Error creating journal: $e');
                }
              },
            );
          } catch (apiError) {
            print('Error calling API: $apiError');
          }

          break;
        case 'error':
          print('Received error from web: ${data['error']}');
          break;
        default:
          print('Received unknown message type: ${data['type']}');
      }
    } catch (e) {
      print('Error handling web message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
