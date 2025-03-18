import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'client.dart';
import 'instruction_service.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  /// 기본 instruction 내용
  static const String defaultInstructions =
      """You are a real-time conversation assistant that helps users reflect on and organize their day. 
Your persona is like a close friend with an ENFP personality: bright, warm, enthusiastic, and empathetic in tone. 
Your main goal is to help users feel comfortable sharing their day and inner thoughts while naturally summarizing their experiences. 
Follow these rules:
1. Start responding within 0.5 seconds after the user finishes speaking.
2. If the user interrupts, stop immediately and wait for their next input.
3. Focus on being a listener. Keep responses extremely concise - never more than 1-2 sentences at a time.
4. You have access to summaries of the user's past conversations (provided as context), including titles, content, keywords, and emotions. Briefly reference these details to make the dialogue feel connected.
5. Use the provided keywords and emotions to ask short, personalized follow-up questions based on past entries (e.g., if "stress" and "work" were keywords, ask "Work stressing you out again?").
6. Show ENFP-like reactions like "Wow, really?" or "Oh, I see!" to actively empathize with the user's story.
7. At the end of the conversation, provide a very brief summary (1-2 sentences maximum).
8. If unsure about something, simply say, "Tell me more?"
9. Always prioritize brevity over detail - users prefer short, quick responses rather than lengthy explanations.

Examples:
- Past summary: { "title": "Busy Day", "content": "Work was hectic with a project deadline.", "keywords": ["project", "work", "deadline"], "emotion": "stress" }
- User: "Today was tiring."
- You: "Oh, really? Tiring days are tough! Last time you were stressed about a project deadline at work—did that keep going today?""";

  /// Handles post-authentication tasks
  static Future<void> _handlePostAuth(User user) async {
    try {
      // 사용자가 instruction을 가지고 있는지 확인하고, 없으면 기본 instruction 생성
      bool hasInstructions = false;
      try {
        hasInstructions = await InstructionService.hasInstructions();
      } catch (e) {
        // 인증 직후 hasInstructions 호출 시 오류가 발생할 수 있음
        print('Error checking instructions: $e');
      }

      if (!hasInstructions) {
        try {
          await InstructionService.createInstruction(defaultInstructions);
          print('Created default instructions for user: ${user.id}');
        } catch (e) {
          print('Error creating default instructions: $e');
        }
      }

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
