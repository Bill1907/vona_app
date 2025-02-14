import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'client.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  // URL getters
  static String get authRecoveryUrl =>
      '${SupabaseClientWrapper.baseUrl}/auth/v1/verify?type=recovery';

  static String get authVerifyUrl =>
      '${SupabaseClientWrapper.baseUrl}/auth/v1/verify?type=signup';

  // Auth utilities
  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;
  static Session? get currentSession => _client.auth.currentSession;
  static String? get currentUserId => _client.auth.currentUser?.id;
  static String? get currentUserEmail => _client.auth.currentUser?.email;

  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
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

    return await _client.auth.signInWithIdToken(
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

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
