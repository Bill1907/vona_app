import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ProfileService {
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    return await _client.from('profiles').select().eq('id', userId).single();
  }

  static Future<void> updateProfile({
    required String userId,
    required String username,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateEncryptionKey({
    required String userId,
    required String encryptionKey,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'encryption_key': encryptionKey,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
  }) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = 'avatar.$fileExt';
    final filePath = '$userId/$fileName';

    try {
      // Upload image to storage
      await _client.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL with the correct path structure
      final String imageUrl = await _client.storage
          .from('avatars')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365); // 1 year expiry

      // Update profile with new avatar URL
      await updateAvatar(userId: userId, avatarUrl: imageUrl);

      return imageUrl;
    } catch (e) {
      throw 'Failed to upload avatar: $e';
    }
  }
}
