import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/push_notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationExample extends StatefulWidget {
  const NotificationExample({super.key});

  @override
  State<NotificationExample> createState() => _NotificationExampleState();
}

class _NotificationExampleState extends State<NotificationExample> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _pushService = PushNotificationService();
  bool _isLoading = false;
  String _resultMessage = '';
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializePushNotifications();
  }

  Future<void> _initializePushNotifications() async {
    await _pushService.initialize();
    // 모든 알림을 받기 위해 'all' 토픽 구독
    await _pushService.subscribeToTopic('all');
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
      _resultMessage = '';
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // Supabase 함수 URL (배포 후 올바른 URL로 변경 필요)
      final url = 'http://127.0.0.1:54321/functions/v1/send-notification';

      // Supabase 함수 호출
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${supabase.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'userId': userId,
          'title': _titleController.text,
          'body': _bodyController.text,
          'data': {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _resultMessage = '알림이 성공적으로 전송되었습니다';
          _titleController.clear();
          _bodyController.clear();
        });
      } else {
        throw Exception('알림 전송 실패: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _resultMessage = '에러: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTopicNotification() async {
    setState(() {
      _isLoading = true;
      _resultMessage = '';
    });

    try {
      // Supabase 함수 URL (배포 후 올바른 URL로 변경 필요)
      final url =
          'https://<SUPABASE_PROJECT_ID>.functions.supabase.co/send-notification';

      // Supabase 함수 호출
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${supabase.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'topic': 'all',
          'title': _titleController.text,
          'body': _bodyController.text,
          'data': {
            'type': 'topic',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _resultMessage = '토픽 알림이 성공적으로 전송되었습니다';
          _titleController.clear();
          _bodyController.clear();
        });
      } else {
        throw Exception('토픽 알림 전송 실패: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _resultMessage = '에러: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('푸시 알림 테스트'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '알림 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '알림 내용',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendTestNotification,
              child: const Text('본인에게 알림 보내기'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendTopicNotification,
              child: const Text('모든 사용자에게 알림 보내기'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_resultMessage.isNotEmpty)
              Text(
                _resultMessage,
                style: TextStyle(
                  color: _resultMessage.startsWith('에러')
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
