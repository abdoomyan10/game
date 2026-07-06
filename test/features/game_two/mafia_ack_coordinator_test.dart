import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/data/datasources/mafia_p2p_protocol.dart';
import 'package:game/features/game_two/data/exceptions/mafia_p2p_exceptions.dart';

void main() {
  test('removeEndpointFromAllExpectations completes when set empties', () async {
    final coordinator = MafiaAckCoordinator();
    coordinator.registerExpectation(
      correlationId: 'phase-1',
      endpointIds: {'a', 'b'},
      timeout: const Duration(seconds: 5),
    );

    final future = coordinator.waitForAcks('phase-1');
    coordinator.recordAck(correlationId: 'phase-1', endpointId: 'a');
    coordinator.removeEndpointFromAllExpectations('b');

    await future;
  });

  test('removeEndpointFromAllExpectations drops missing endpoint only', () {
    final coordinator = MafiaAckCoordinator();
    coordinator.registerExpectation(
      correlationId: 'phase-1',
      endpointIds: {'a', 'b'},
      timeout: const Duration(seconds: 5),
    );

    coordinator.removeEndpointFromAllExpectations('missing');
    expect(coordinator.pendingFor('phase-1'), {'a', 'b'});
  });

  test('ACK timeout still throws when endpoints remain', () async {
    final coordinator = MafiaAckCoordinator();
    coordinator.registerExpectation(
      correlationId: 'phase-1',
      endpointIds: {'a', 'b'},
      timeout: const Duration(milliseconds: 20),
    );

    coordinator.removeEndpointFromAllExpectations('a');

    await expectLater(
      coordinator.waitForAcks('phase-1'),
      throwsA(isA<MafiaAckTimeoutException>()),
    );
  });
}
