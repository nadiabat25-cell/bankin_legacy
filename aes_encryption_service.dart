import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'dart:convert';
import 'dart:math';

class AESEncryptionService {
  static String generateKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static String keyToString(String key) {
    return key;
  }

  String encrypt(String plainText, String keyString) {
    try {
      final keyBytes = utf8.encode(keyString.padRight(32).substring(0, 32));
      final key = encrypt_lib.Key(keyBytes);

      // ✅ Random IV every time = more secure
      final iv = encrypt_lib.IV.fromSecureRandom(16);
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // ✅ Store IV + ciphertext together so we can decrypt later
      // Format: base64(iv):base64(ciphertext)
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  String decrypt(String encryptedText, String keyString) {
    try {
      final keyBytes = utf8.encode(keyString.padRight(32).substring(0, 32));
      final key = encrypt_lib.Key(keyBytes);
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key));

      // ✅ Handle both old format (no IV prefix) and new format (iv:ciphertext)
      if (encryptedText.contains(':')) {
        // New format — extract IV and ciphertext
        final parts = encryptedText.split(':');
        final iv = encrypt_lib.IV.fromBase64(parts[0]);
        final decrypted = encrypter.decrypt64(parts[1], iv: iv);
        return decrypted;
      } else {
        // Old format — fall back to fixed IV (for existing stored data)
        final ivBytes = keyBytes.sublist(0, 16);
        final iv = encrypt_lib.IV(ivBytes);
        return encrypter.decrypt64(encryptedText, iv: iv);
      }
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
}
