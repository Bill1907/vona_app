import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptService {
  Encrypter? _encrypter;

  void init(String userKeyString) {
    // 표준 키 길이(32바이트, 256비트)의 키 생성
    final key = _generateKey(userKeyString);
    _encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  }

  Key _generateKey(String input) {
    // SHA-256 해시를 사용하여 키 생성 (항상 32바이트)
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    // 해시의 바이트를 base64로 인코딩하여 Key 객체 생성
    return Key.fromBase64(base64Encode(digest.bytes));
  }

  String createUserKey(String userId) {
    final key = _generateKey(userId);
    return key.base64;
  }

  String createIV() {
    final iv = IV.fromSecureRandom(16);
    return iv.base64;
  }

  String encryptData(String plainText, String ivString) {
    if (_encrypter == null) {
      throw Exception(
          'Encrypter is not initialized (user key might be missing)');
    }
    final iv = IV.fromBase64(ivString);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decryptData(String encryptedData, String ivString) {
    if (_encrypter == null) {
      throw Exception(
          'Encrypter is not initialized (user key might be missing)');
    }
    final iv = IV.fromBase64(ivString);
    final decrypted =
        _encrypter!.decrypt(Encrypted.fromBase64(encryptedData), iv: iv);

    return decrypted;
  }
}
