import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/supabase/client.dart';
import 'core/supabase/auth_service.dart';
import 'core/theme/theme_service.dart';
import 'core/language/language_service.dart';
import 'core/language/app_localizations.dart';
import 'core/services/push_notification_service.dart';
import 'pages/auth/auth_page.dart';
import 'pages/auth/verify_email_page.dart';
import 'pages/auth/email_verification_success_page.dart';
import 'pages/auth/email_sign_in_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/sign_up_page.dart';
import 'pages/home_page.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'utils/web_stub.dart' if (dart.library.html) 'utils/web.dart';
import 'pages/webview_page.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/settings/language_settings_page.dart';
import 'utils/notification_example.dart';
import 'firebase_options.dart';

// 백그라운드 메시지 핸들러 설정
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('백그라운드 메시지 처리: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Supabase (this includes loading env variables)
  await SupabaseClientWrapper.initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize timezone
  try {
    await FlutterNativeTimezone.getLocalTimezone();
  } catch (e) {
    print('Error initializing timezone: $e');
  }

  // 시스템 언어 설정 확인 (non-deprecated method)
  final Locale systemLocale = PlatformDispatcher.instance.locale;
  print(
      'System locale: ${systemLocale.languageCode}${systemLocale.countryCode != null ? '_${systemLocale.countryCode}' : ''}');

  // 웹에서 딥링크 처리
  if (kIsWeb) {
    final url = getWebUrl();
    if (url != null) {
      final uri = Uri.parse(url);
      if (uri.hasFragment && uri.fragment.contains('type=recovery')) {
        // 웹 전용 로직
      }
    }
  }

  runApp(MyApp(prefs: prefs, systemLocale: systemLocale));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final Locale systemLocale;

  const MyApp({super.key, required this.prefs, required this.systemLocale});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService(prefs)),
        ChangeNotifierProvider(
            create: (_) => LanguageService(prefs, systemLocale)),
      ],
      child: Consumer2<ThemeService, LanguageService>(
        builder: (context, themeService, languageService, _) {
          return MaterialApp(
            title:
                AppLocalizations(languageService.locale).translate('appName'),
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            // 언어 서비스에서 로케일 설정 가져오기
            locale: languageService.locale,
            // 지원하는 로케일 목록
            supportedLocales: LanguageService.supportedLocales,
            // 로컬라이제이션 대리자 설정
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              const AppLocalizationsDelegate(),
            ],
            theme: ThemeData(
              fontFamily: 'Poppins',
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF3A70EF)),
              useMaterial3: true,
            ),
            darkTheme: ThemeData.dark(
              useMaterial3: true,
            ).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3A70EF),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: Colors.black,
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Colors.black,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthStateScreen(),
              '/auth': (context) => const AuthPage(),
              '/home': (context) => const HomePage(),
              '/verify-email': (context) => const VerifyEmailPage(),
              '/email-sign-in': (context) => const EmailSignInPage(),
              '/forgot-password': (context) => const ForgotPasswordPage(),
              '/sign-up': (context) => const SignUpPage(),
              '/auth/verify-email/confirmation': (context) =>
                  const EmailVerificationSuccessPage(),
              '/reset-password': (context) => WebViewPage(
                    url: AuthService.authRecoveryUrl,
                    title: AppLocalizations(languageService.locale)
                        .translate('resetPassword'),
                  ),
              '/settings/language': (context) => const LanguageSettingsPage(),
              '/notification-example': (context) => const NotificationExample(),
              // '/journals': (context) => const DiaryListPage(),
            },
          );
        },
      ),
    );
  }
}

class AuthStateScreen extends StatefulWidget {
  const AuthStateScreen({super.key});

  @override
  State<AuthStateScreen> createState() => _AuthStateScreenState();
}

class _AuthStateScreenState extends State<AuthStateScreen> {
  late final StreamSubscription<AuthState> _authStateSubscription;
  final _appLinks = AppLinks();
  final _pushNotificationService = PushNotificationService();

  @override
  void initState() {
    super.initState();

    // 웹에서 비밀번호 재설정 링크로 접근한 경우 처리
    if (kIsWeb) {
      final url = getWebUrl();
      if (url != null) {
        final uri = Uri.parse(url);
        if (uri.hasFragment && uri.fragment.contains('type=recovery')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamed('/reset-password');
          });
        }
      }
    }

    _authStateSubscription = AuthService.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn) {
        // 로그인 시 푸시 알림 서비스 초기화
        await _pushNotificationService.initialize();
        // 매일 저녁 9시 일기 알림 설정
        await _pushNotificationService.initializeDiaryReminders();
        _navigateToHome();
      } else if (event == AuthChangeEvent.signedOut) {
        _navigateToAuth();
      }
    });

    // 초기 상태 확인
    _checkCurrentSession();

    _handleIncomingLinks();
  }

  void _navigateToHome() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  void _navigateToAuth() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/auth');
    });
  }

  Future<void> _checkCurrentSession() async {
    try {
      final session = AuthService.currentSession;

      print('Current session: $session');

      if (!mounted) return;

      if (session != null) {
        _navigateToHome();
        // 기존 세션이 있는 경우 일기 알림 초기화
        await _pushNotificationService.initialize();
        await _pushNotificationService.initializeDiaryReminders();
      } else {
        _navigateToAuth();
      }
    } catch (e) {
      if (mounted) {
        _navigateToAuth();
      }
    }
  }

  void _handleIncomingLinks() {
    _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (!mounted) return;
      if (uri != null) {
        if (uri.host == 'reset-callback') {
          Navigator.of(context).pushNamed('/reset-password');
        }
      }
    }, onError: (err) {
      debugPrint('Error handling incoming links: $err');
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
