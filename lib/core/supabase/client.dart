import 'package:supabase_flutter/supabase_flutter.dart' hide SupabaseClient;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

class SupabaseClientWrapper {
  static SupabaseClientWrapper? _instance;

  SupabaseClientWrapper._();

  static Future<void> initialize() async {
    await dotenv.load();

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  static SupabaseClientWrapper get instance {
    _instance ??= SupabaseClientWrapper._();
    return _instance!;
  }

  static dynamic get client => Supabase.instance.client;

  // Base URL getters
  static String get baseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  // URL getters
  static String get authRecoveryUrl => '$baseUrl/auth/v1/verify?type=recovery';
  static String get authVerifyUrl => '$baseUrl/auth/v1/verify?type=signup';

  // Auth utilities
  static Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;
  static Session? get currentSession => client.auth.currentSession;

  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<AuthResponse> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: Platform.isIOS
          ? dotenv.env['GOOGLE_IOS_CLIENT_ID']
          : dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      scopes: ['email', 'profile'],
    );

    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw 'Google Sign In was cancelled';

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw 'No ID Token found.';

    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  static Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    if (credential.identityToken == null) {
      throw 'No Identity Token found.';
    }

    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
    );
  }

  // Profile methods
  static String? get currentUserId => client.auth.currentUser?.id;
  static String? get currentUserEmail => client.auth.currentUser?.email;

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    return await client.from('profiles').select().eq('id', userId).single();
  }

  static Future<void> updateProfile({
    required String userId,
    required String username,
  }) async {
    await client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
