import 'package:encrypt/encrypt.dart';
import 'package:injectable/injectable.dart';

import 'encryption_service.dart';

/// AES-256-CBC implementation of [EncryptionService].
@LazySingleton(as: EncryptionService)
class EncryptionServiceImpl implements EncryptionService {
  Key? _sessionKey;

  @override
  bool get hasSessionKey => _sessionKey != null;

  @override
  String generateSessionKey() => Key.fromSecureRandom(32).base64;

  @override
  void setSessionKey(String base64Key) {
    _sessionKey = Key.fromBase64(base64Key);
  }

  @override
  void clearSessionKey() => _sessionKey = null;

  @override
  String encryptData(String plainText) {
    final key = _requireKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  @override
  String decryptData(String encryptedPayload) {
    final key = _requireKey();
    final parts = encryptedPayload.split(':');
    if (parts.length != 2) {
      throw const EncryptionException('Invalid encrypted payload format');
    }

    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Key _requireKey() {
    final key = _sessionKey;
    if (key == null) {
      throw const EncryptionException('Session key is not set');
    }
    return key;
  }
}
