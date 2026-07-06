import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/data/constants/mafia_p2p_constants.dart';
import 'package:game/features/game_two/data/datasources/mafia_p2p_protocol.dart';
import 'package:game/features/game_two/data/exceptions/mafia_p2p_exceptions.dart';
import 'package:game/features/game_two/data/models/mafia_connection_health.dart';
import 'package:game/features/game_two/data/models/mafia_payload_transfer_event.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  group('MafiaP2pProtocol', () {
    test('parses ping and builds pong response bytes', () {
      final ping = MafiaP2pProtocol.buildPing(
        pingId: 'ping-1',
        sentAtMs: 1000,
      );

      final parsed = MafiaP2pProtocol.tryParseControlPayload(ping);
      expect(parsed?.type, MafiaControlMessageType.ping);
      expect(parsed?.pingId, 'ping-1');

      final pong = MafiaP2pProtocol.buildPong(
        pingId: parsed!.pingId!,
        sentAtMs: 1500,
      );
      final pongParsed = MafiaP2pProtocol.tryParseControlPayload(pong);
      expect(pongParsed?.type, MafiaControlMessageType.pong);
    });

    test('parses phaseSync and ack control frames', () {
      final phaseSync = MafiaP2pProtocol.buildPhaseSync(
        correlationId: 'phase-42',
      );
      final parsed = MafiaP2pProtocol.tryParseControlPayload(phaseSync);
      expect(parsed?.type, MafiaControlMessageType.phaseSync);
      expect(parsed?.correlationId, 'phase-42');

      final ack = MafiaP2pProtocol.buildAck(correlationId: 'phase-42');
      final ackParsed = MafiaP2pProtocol.tryParseControlPayload(ack);
      expect(ackParsed?.type, MafiaControlMessageType.ack);
      expect(ackParsed?.correlationId, 'phase-42');
    });

    test('returns null for non-control opaque bytes', () {
      final opaque = MafiaP2pProtocol.buildPing(
        pingId: 'x',
        sentAtMs: 1,
      );
      final corrupted = [...opaque, 0xFF, 0xFE];
      expect(
        MafiaP2pProtocol.tryParseControlPayload(corrupted),
        isNull,
      );
    });
  });

  group('MafiaAckCoordinator', () {
    late MafiaAckCoordinator coordinator;

    setUp(() {
      coordinator = MafiaAckCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('completes when all endpoints ack', () async {
      coordinator.registerExpectation(
        correlationId: 'sync-1',
        endpointIds: {'a', 'b'},
        timeout: const Duration(seconds: 2),
      );

      expect(coordinator.recordAck(
        correlationId: 'sync-1',
        endpointId: 'a',
      ), isTrue);
      final future = coordinator.waitForAcks('sync-1');

      expect(coordinator.recordAck(
        correlationId: 'sync-1',
        endpointId: 'b',
      ), isTrue);

      await expectLater(future, completes);
      expect(coordinator.pendingFor('sync-1'), isEmpty);
    });

    test('buffers early acks registered before expectation', () async {
      expect(coordinator.recordAck(
        correlationId: 'sync-early',
        endpointId: 'a',
      ), isTrue);

      coordinator.registerExpectation(
        correlationId: 'sync-early',
        endpointIds: {'a', 'b'},
        timeout: const Duration(seconds: 2),
      );

      final future = coordinator.waitForAcks('sync-early');
      coordinator.recordAck(correlationId: 'sync-early', endpointId: 'b');

      await expectLater(future, completes);
    });

    test('throws MafiaAckTimeoutException with missing endpoint ids', () async {
      coordinator.registerExpectation(
        correlationId: 'sync-timeout',
        endpointIds: {'a', 'b'},
        timeout: const Duration(milliseconds: 50),
      );

      coordinator.recordAck(correlationId: 'sync-timeout', endpointId: 'a');

      await expectLater(
        coordinator.waitForAcks('sync-timeout'),
        throwsA(
          isA<MafiaAckTimeoutException>().having(
            (error) => error.missingEndpointIds,
            'missingEndpointIds',
            {'b'},
          ),
        ),
      );
    });
  });

  group('MafiaConnectionHealthTracker', () {
    test('marks degraded after transfer failure', () {
      final tracker = MafiaConnectionHealthTracker(
        staleThreshold: const Duration(seconds: 12),
      );

      tracker.markConnected('peer-1');
      final degraded = tracker.recordTransferFailure('peer-1');

      expect(degraded.quality, MafiaConnectionQuality.degraded);
      expect(degraded.failedTransferCount, 1);
    });

    test('records RTT from ping and pong', () {
      final tracker = MafiaConnectionHealthTracker(
        staleThreshold: const Duration(seconds: 12),
      );

      tracker.markConnected('peer-1');
      tracker.registerPing('peer-1', 1000);
      final health = tracker.recordPong(
        endpointId: 'peer-1',
        pongSentAtMs: 1042,
      );

      expect(health?.roundTripMs, 42);
      expect(health?.quality, MafiaConnectionQuality.healthy);
    });

    test('evaluateStale marks peer degraded when silent too long', () {
      final tracker = MafiaConnectionHealthTracker(
        staleThreshold: const Duration(seconds: 5),
      );

      final connected = tracker.markConnected('peer-1');
      final staleAt = connected.lastPayloadAt!.add(const Duration(seconds: 6));
      final stale = tracker.evaluateStale(staleAt);

      expect(stale, hasLength(1));
      expect(stale.first.quality, MafiaConnectionQuality.degraded);
    });
  });

  group('MafiaPayloadTransferEvent', () {
    test('detects failure and success statuses', () {
      const failure = MafiaPayloadTransferEvent(
        endpointId: 'x',
        payloadId: 1,
        status: PayloadStatus.FAILURE,
        bytesTransferred: 0,
        totalBytes: 10,
      );
      const success = MafiaPayloadTransferEvent(
        endpointId: 'x',
        payloadId: 2,
        status: PayloadStatus.SUCCESS,
        bytesTransferred: 10,
        totalBytes: 10,
      );

      expect(failure.isFailure, isTrue);
      expect(success.isSuccess, isTrue);
    });
  });
}
