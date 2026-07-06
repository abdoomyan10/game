/// Thrown when encryption/decryption fails in the data layer.
/// Repositories should map this to a domain [Failure].
class EncryptionException implements Exception {
  const EncryptionException(this.message);

  final String message;

  @override
  String toString() => 'EncryptionException: $message';
}

/// AES session encryption used by repositories before sending game payloads.
///
/// Handshake flow (repository layer, next step):
/// 1. Host: [generateSessionKey] + [setSessionKey] locally
/// 2. Host sends plaintext handshake JSON with key over Nearby link
/// 3. Client: [setSessionKey] from received handshake
/// 4. Both sides use [encryptData] / [decryptData] for game messages
abstract class EncryptionService {
  /// Host calls this to create a fresh AES-256 key per game session.
  String generateSessionKey();

  /// Both sides call after handshake payload is received (host sets locally too).
  void setSessionKey(String base64Key);

  void clearSessionKey();

  bool get hasSessionKey;

  /// Returns `ivBase64:cipherBase64` — IV is random per message.
  String encryptData(String plainText);

  String decryptData(String encryptedPayload);
}
