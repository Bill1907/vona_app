import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'client.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  /// Handles post-authentication tasks
  static Future<void> _handlePostAuth(User user) async {
    try {
      // Any other post-auth tasks can be added here
    } catch (e) {
      print('Error in post-auth handling: $e');
      rethrow;
    }
  }

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
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _handlePostAuth(response.user!);
    }

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _handlePostAuth(response.user!);
    }

    return response;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRecoveryUrl,
    );
  }

  static Future<UserResponse> updatePassword(String password) async {
    return await _client.auth.updateUser(
      UserAttributes(
        password: password,
      ),
    );
  }

  static Future<AuthResponse> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS
            ? dotenv.env['IOS_GOOGLE_CLIENT_ID']
            : dotenv.env['WEB_GOOGLE_CLIENT_ID'],
        serverClientId: dotenv.env['WEB_GOOGLE_CLIENT_ID'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No Access Token found.');
      }
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _handlePostAuth(response.user!);
      }

      return response;
    } catch (error) {
      print('Error signing in with Google: $error');
      rethrow;
    }
  }

  static Future<AuthResponse> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user != null) {
        await _handlePostAuth(response.user!);
      }

      return response;
    } catch (error) {
      print('Error signing in with Apple: $error');
      rethrow;
    }
  }
}
