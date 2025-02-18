import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase/client.dart';
import 'core/supabase/auth_service.dart';
import 'core/theme/theme_service.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (this includes loading env variables)
  await SupabaseClientWrapper.initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

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

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(prefs),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Vona App',
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            theme: ThemeData(
              fontFamily: 'Poppins',
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            darkTheme: ThemeData.dark(
              useMaterial3: true,
            ).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
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
                    title: '비밀번호 재설정',
                  ),
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
      if (!mounted) return;

      if (session != null) {
        _navigateToHome();
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
