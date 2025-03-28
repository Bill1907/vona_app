import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 싱글톤 패턴
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // Android 알림 채널
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // iOS에서 권한 요청
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('알림 권한: ${settings.authorizationStatus}');

    // Android용 알림 채널 생성
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 초기화 설정
    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // FCM 토큰 가져오기 및 저장
    await _saveTokenToDatabase();

    // 토큰 갱신 시 대응
    _fcm.onTokenRefresh.listen(_saveToken);

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드에서 알림 클릭 시 앱 열기
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  // FCM 토큰을 Supabase에 저장
  Future<void> _saveTokenToDatabase() async {
    try {
      String? token = await _fcm.getToken();
      print('FCM 토큰: $token');

      if (token != null) {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase.from('fcm_tokens').upsert({
            'user_id': userId,
            'token': token,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
        }
      }
    } catch (e) {
      print('토큰 저장 오류: $e');
    }
  }

  // 토큰 업데이트 처리
  Future<void> _saveToken(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      }
    } catch (e) {
      print('토큰 업데이트 오류: $e');
    }
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    print('포그라운드 메시지 수신: ${message.notification?.title}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android?.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  // 알림 클릭 시 처리
  void _handleNotificationOpen(RemoteMessage message) {
    print('알림 클릭으로 앱 실행: ${message.data}');
    // 여기서 특정 페이지로 이동하는 로직 추가 가능
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    print('알림 탭: ${response.payload}');
    // 여기서 특정 페이지로 이동하는 로직 추가 가능
  }

  // 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  // 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
