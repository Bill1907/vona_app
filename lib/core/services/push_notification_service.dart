import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

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

  // 일기 알림 채널
  static const AndroidNotificationChannel diaryChannel =
      AndroidNotificationChannel(
    'diary_reminders_channel',
    '일기 알림',
    description: '매일 일기 작성을 위한 알림입니다.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // 타임존 초기화
    _initializeTimeZone();

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

    // 일기 알림 채널 생성
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(diaryChannel);

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

  // 일기 알림 초기화
  Future<void> initializeDiaryReminders() async {
    // 이미 타임존이 초기화되어 있는지 확인하고, 필요하면 초기화
    if (tz.local.name == 'UTC') {
      await _initializeTimeZone();
    }

    // 매일 저녁 9시 일기 알림 예약
    await scheduleDailyDiaryReminder();
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

  // 타임존 초기화
  Future<void> _initializeTimeZone() async {
    try {
      tz_data.initializeTimeZones();
      final String timeZoneName =
          await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Error initializing timezone: $e');
      // 기본 시간대 설정 (UTC)
      tz.setLocalLocation(tz.UTC);
    }
  }

  // 매일 저녁 9시에 일기 작성 알림 예약
  Future<void> scheduleDailyDiaryReminder() async {
    // 기존 알림 취소
    await cancelDiaryReminder();

    // 오늘 저녁 9시 시간 계산
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21, // 저녁 9시
      0, // 0분
    );

    // 만약 지정된 시간이 이미 지났다면 다음 날로 설정
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1, // ID
      '일기 작성 시간입니다',
      '오늘 하루를 기록해보세요!',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          diaryChannel.id,
          diaryChannel.name,
          channelDescription: diaryChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시간에 반복
    );

    print('일기 알림 예약 완료: 매일 저녁 9시');
  }

  // 일기 알림 취소
  Future<void> cancelDiaryReminder() async {
    await _flutterLocalNotificationsPlugin.cancel(1);
  }
}
