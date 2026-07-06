import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_one/data/services/encryption_service.dart';
import 'package:game/features/game_one/data/services/encryption_service_impl.dart';

void main() {
  late EncryptionService encryptionService;

  setUp(() {
    encryptionService = EncryptionServiceImpl();
  });

  test('generateSessionKey setSessionKey encrypt decrypt round-trip', () {
    final sessionKey = encryptionService.generateSessionKey();
    encryptionService.setSessionKey(sessionKey);

    expect(encryptionService.hasSessionKey, isTrue);

    const plainText = '{"role":"imposter","word":"تفاحة"}';
    final encrypted = encryptionService.encryptData(plainText);
    final decrypted = encryptionService.decryptData(encrypted);

    expect(decrypted, plainText);
    expect(encrypted, isNot(plainText));
    expect(encrypted.contains(':'), isTrue);
  });

  test('encryptData throws when session key is not set', () {
    expect(
      () => encryptionService.encryptData('hello'),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('clearSessionKey removes session', () {
    encryptionService.setSessionKey(encryptionService.generateSessionKey());
    encryptionService.clearSessionKey();
    expect(encryptionService.hasSessionKey, isFalse);
  });
}
