import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/data/services/mafia_reconnect_grace_manager.dart';

void main() {
  test('grace timer fires onExpired callback', () async {
    String? expiredId;
    final manager = MafiaReconnectGraceManager(
      gracePeriod: const Duration(milliseconds: 50),
      onExpired: (playerId) => expiredId = playerId,
    );

    manager.startGrace('player-1');
    expect(manager.isGraceActive('player-1'), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(expiredId, 'player-1');
    expect(manager.isGraceActive('player-1'), isFalse);
  });

  test('cancelGrace prevents expiry', () async {
    String? expiredId;
    final manager = MafiaReconnectGraceManager(
      gracePeriod: const Duration(milliseconds: 50),
      onExpired: (playerId) => expiredId = playerId,
    );

    manager.startGrace('player-1');
    manager.cancelGrace('player-1');

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(expiredId, isNull);
  });

  test('duplicate startGrace resets timer', () async {
    var callCount = 0;
    final manager = MafiaReconnectGraceManager(
      gracePeriod: const Duration(milliseconds: 40),
      onExpired: (_) => callCount++,
    );

    manager.startGrace('player-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    manager.startGrace('player-1');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(callCount, 1);
  });
}
