import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/data/datasources/mafia_network_datasource.dart';
import 'package:game/features/game_two/data/exceptions/mafia_p2p_exceptions.dart';
import 'package:game/features/game_two/data/repositories/mafia_repository_impl.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/entities/mafia_session_event.dart';
import 'package:game/features/game_one/data/services/encryption_service.dart';
import 'package:game/features/game_one/data/services/p2p_permission_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMafiaNetworkDataSource extends Mock implements MafiaNetworkDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

class MockP2pPermissionService extends Mock implements P2pPermissionService {}

void main() {
  late MockMafiaNetworkDataSource network;
  late MockEncryptionService encryption;
  late MockP2pPermissionService permissions;
  late MafiaRepositoryImpl repository;

  late StreamController<Set<String>> connectedController;
  late StreamController<MafiaP2pPayload> payloadController;
  late StreamController<MafiaP2pEndpoint> endpointFoundController;
  late StreamController<String> disconnectedController;
  late StreamController<String> endpointLostController;

  setUp(() {
    network = MockMafiaNetworkDataSource();
    encryption = MockEncryptionService();
    permissions = MockP2pPermissionService();
    repository = MafiaRepositoryImpl(network, encryption, permissions);

    connectedController = StreamController<Set<String>>.broadcast();
    payloadController = StreamController<MafiaP2pPayload>.broadcast();
    endpointFoundController = StreamController<MafiaP2pEndpoint>.broadcast();
    disconnectedController = StreamController<String>.broadcast();
    endpointLostController = StreamController<String>.broadcast();

    when(() => network.connectedEndpoints)
        .thenAnswer((_) => connectedController.stream);
    when(() => network.onPayloadReceived)
        .thenAnswer((_) => payloadController.stream);
    when(() => network.onEndpointFound)
        .thenAnswer((_) => endpointFoundController.stream);
    when(() => network.onEndpointDisconnected)
        .thenAnswer((_) => disconnectedController.stream);
    when(() => network.onEndpointLost)
        .thenAnswer((_) => endpointLostController.stream);
    when(() => network.onRejoinRequested).thenAnswer((_) => const Stream.empty());
    when(() => network.onSessionControl).thenAnswer((_) => const Stream.empty());
    when(() => network.connectionHealth).thenAnswer((_) => const Stream.empty());
    when(() => network.payloadTransferUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => network.startHosting(userName: any(named: 'userName')))
        .thenAnswer((_) async {});
    when(() => network.disconnectAll()).thenAnswer((_) async {});
    when(() => network.sendIsolatedPayload(
          endpointId: any(named: 'endpointId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});
    when(() => network.startHealthMonitoring()).thenReturn(null);
    when(() => network.stopDiscovery()).thenAnswer((_) async {});
    when(() => encryption.generateSessionKey()).thenReturn('session-key');
    when(() => encryption.setSessionKey(any())).thenReturn(null);
    when(() => encryption.clearSessionKey()).thenReturn(null);
    when(() => encryption.hasSessionKey).thenReturn(true);
    when(() => encryption.encryptData(any())).thenReturn('encrypted');
  });

  tearDown(() async {
    await connectedController.close();
    await payloadController.close();
    await endpointFoundController.close();
    await disconnectedController.close();
    await endpointLostController.close();
    await repository.disconnect();
  });

  test('canStartGame is false with only host', () async {
    await repository.startHosting('Host');

    expect(repository.canStartGame, isFalse);
  });

  test('canStartGame becomes true only after connected endpoints update', () async {
    final updates = <bool>[];
    final subscription = repository.canStartGameUpdates.listen(updates.add);

    await repository.startHosting('Host');
    connectedController.add({'guest-endpoint'});
    await Future<void>.delayed(Duration.zero);

    expect(repository.canStartGame, isTrue);
    expect(updates.where((ready) => ready).length, greaterThanOrEqualTo(1));

    await subscription.cancel();
  });

  test('emits GameStarted to clients on gameConfigSync payload', () async {
    final events = <MafiaSessionEvent>[];
    final subscription = repository.sessionEvents.listen(events.add);

    when(() => encryption.decryptData(any())).thenReturn(
      '{"type":"gameConfigSync","config":{"state":"inProgress","phase":"night","players":[{"id":"local","name":"Host","isHost":true,"role":"mafiaBoss","isAlive":true,"isSilenced":false},{"id":"guest-1","name":"Guest","isHost":false,"role":"citizen","isAlive":true,"isSilenced":false}]}}',
    );

    await repository.scanForLobbies('Guest');
    payloadController.add(
      MafiaP2pPayload(
        endpointId: 'host-endpoint',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<GameStarted>(), hasLength(1));
    expect(events.whereType<GameStarted>().first.config.players, hasLength(2));

    await subscription.cancel();
  });

  test('failed initial game start broadcast retries without throwing', () async {
    await repository.startHosting('Host');
    connectedController.add({'guest-endpoint'});
    await Future<void>.delayed(Duration.zero);

    expect(repository.canStartGame, isTrue);

    when(
      () => network.sendIsolatedPayload(
        endpointId: any(named: 'endpointId'),
        data: any(named: 'data'),
      ),
    ).thenThrow(
      const MafiaTransportException(message: 'send failed'),
    );

    final config = MafiaGameConfig(
      state: MafiaGameState.inProgress,
      phase: MafiaPhase.night,
      players: const [
        MafiaPlayerEntity(
          id: 'local',
          name: 'Host',
          isHost: true,
          role: MafiaRole.mafiaBoss,
          isAlive: true,
          isSilenced: false,
        ),
        MafiaPlayerEntity(
          id: 'guest-endpoint',
          name: 'Guest',
          isHost: false,
          role: MafiaRole.citizen,
          isAlive: true,
          isSilenced: false,
        ),
      ],
    );

    await repository.setActiveGameConfig(config);

    expect(repository.activeGameConfig?.state, MafiaGameState.inProgress);
    expect(repository.canStartGame, isFalse);
  });
}
