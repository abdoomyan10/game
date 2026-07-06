import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_one/data/constants/p2p_constants.dart';
import 'package:game/features/game_one/data/datasources/network_datasource.dart';
import 'package:game/features/game_one/data/exceptions/p2p_exceptions.dart';
import 'package:game/features/game_one/data/repositories/game_repository_impl.dart';
import 'package:game/features/game_one/data/services/encryption_service.dart';
import 'package:game/features/game_one/data/services/p2p_permission_service.dart';
import 'package:game/features/game_one/domain/entities/discovered_room.dart';
import 'package:game/features/game_one/domain/entities/game_payload.dart';
import 'package:game/features/game_one/domain/entities/game_session_event.dart';
import 'package:game/features/game_one/domain/entities/player_role.dart';
import 'package:game/features/game_one/domain/entities/p2p_permission.dart';
import 'package:mocktail/mocktail.dart';

class MockNetworkDataSource extends Mock implements NetworkDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

class MockP2pPermissionService extends Mock implements P2pPermissionService {}

void main() {
  late MockNetworkDataSource network;
  late MockEncryptionService encryption;
  late MockP2pPermissionService permissions;
  late GameRepositoryImpl repository;

  late StreamController<P2pPayload> payloadController;
  late StreamController<P2pEndpoint> endpointFoundController;
  late StreamController<Set<String>> connectedController;
  late StreamController<String> disconnectedController;
  late StreamController<String> endpointLostController;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    network = MockNetworkDataSource();
    encryption = MockEncryptionService();
    permissions = MockP2pPermissionService();
    repository = GameRepositoryImpl(network, encryption, permissions);

    payloadController = StreamController<P2pPayload>.broadcast();
    endpointFoundController = StreamController<P2pEndpoint>.broadcast();
    connectedController = StreamController<Set<String>>.broadcast();
    disconnectedController = StreamController<String>.broadcast();
    endpointLostController = StreamController<String>.broadcast();

    when(() => network.onPayloadReceived)
        .thenAnswer((_) => payloadController.stream);
    when(() => network.onEndpointFound)
        .thenAnswer((_) => endpointFoundController.stream);
    when(() => network.connectedEndpoints)
        .thenAnswer((_) => connectedController.stream);
    when(() => network.onEndpointDisconnected)
        .thenAnswer((_) => disconnectedController.stream);
    when(() => network.onEndpointLost)
        .thenAnswer((_) => endpointLostController.stream);
    when(() => network.disconnectAll()).thenAnswer((_) async {});
    when(() => network.startHosting(userName: any(named: 'userName')))
        .thenAnswer((_) async {});
    when(() => network.startDiscovery(userName: any(named: 'userName')))
        .thenAnswer((_) async {});
    when(() => network.connectToHost(endpointId: any(named: 'endpointId')))
        .thenAnswer((_) async {});
    when(() => network.sendPayload(
          endpointId: any(named: 'endpointId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});
    when(() => permissions.ensureGranted()).thenAnswer((_) async {});
    when(() => encryption.generateSessionKey()).thenReturn('session-key-base64');
    when(() => encryption.setSessionKey(any())).thenReturn(null);
    when(() => encryption.clearSessionKey()).thenReturn(null);
    when(() => encryption.hasSessionKey).thenReturn(true);
    when(() => encryption.encryptData(any())).thenReturn('iv:cipher');
    when(() => encryption.decryptData(any())).thenReturn(
      jsonEncode({'role': 'normal', 'word': 'تفاحة'}),
    );
  });

  tearDown(() async {
    await payloadController.close();
    await endpointFoundController.close();
    await connectedController.close();
    await disconnectedController.close();
    await endpointLostController.close();
  });

  test('startHosting generates session key and starts advertising', () async {
    final result = await repository.startHosting('أحمد');

    expect(result.isRight(), isTrue);
    verify(() => encryption.generateSessionKey()).called(1);
    verify(() => encryption.setSessionKey('session-key-base64')).called(1);
    verify(() => network.startHosting(userName: 'أحمد')).called(1);
    expect(repository.isHost, isTrue);
  });

  test('ensurePermissions maps permission exception to PermissionFailure', () async {
    when(() => permissions.ensureGranted()).thenThrow(
      const P2pPermissionException(
        message: 'يجب تفعيل Bluetooth والموقع للعب عبر الشبكة المحلية',
        denied: [P2pPermission.bluetooth],
      ),
    );

    final result = await repository.ensurePermissions();

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure.message, contains('Bluetooth'));
      },
      (_) => fail('Expected failure'),
    );
  });

  test('sendGamePayload encrypts json before sending bytes', () async {
    const payload = GamePayload(
      role: PlayerRole.normal,
      word: 'تفاحة',
    );

    final result = await repository.sendGamePayload(
      payload: payload,
      endpointId: 'peer-1',
    );

    expect(result.isRight(), isTrue);
    verify(() => encryption.encryptData(any())).called(1);
    verify(
      () => network.sendPayload(
        endpointId: 'peer-1',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test('handshake payload sets session key without emitting game payload', () async {
    when(() => encryption.hasSessionKey).thenReturn(false);

    final incoming = <GamePayload>[];
    final subscription = repository.incomingPayloads.listen(incoming.add);

    await repository.joinRoom(endpointId: 'host-1', userName: 'لاعب');

    final handshake = jsonEncode({
      'type': P2pMessageType.handshake.value,
      'sessionKey': 'client-session-key',
    });

    payloadController.add(
      P2pPayload(
        endpointId: 'host-1',
        bytes: Uint8List.fromList(utf8.encode(handshake)),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    verify(() => encryption.setSessionKey('client-session-key')).called(1);
    expect(incoming, isEmpty);

    await subscription.cancel();
  });

  test('scanForRooms emits discovered room from network endpoint', () async {
    final rooms = <DiscoveredRoom>[];
    final subscription = repository.discoveredRooms.listen(rooms.add);

    await repository.scanForRooms('سارة');

    endpointFoundController.add(
      const P2pEndpoint(id: 'host-99', userName: 'مضيف'),
    );

    await Future<void>.delayed(Duration.zero);

    expect(rooms, hasLength(1));
    expect(rooms.first.hostName, 'مضيف');

    await subscription.cancel();
  });

  test('host removes guest and emits ClientDisconnected when peer drops', () async {
    final sessionEvents = <GameSessionEvent>[];
    final playersHistory = <List<dynamic>>[];

    final sessionSub = repository.sessionEvents.listen(sessionEvents.add);
    final playersSub = repository.players.listen(playersHistory.add);

    await repository.startHosting('أحمد');

    connectedController.add({'guest-1'});
    await Future<void>.delayed(Duration.zero);

    connectedController.add({});
    await Future<void>.delayed(Duration.zero);

    expect(
      sessionEvents.whereType<ClientDisconnected>().map((e) => e.endpointId),
      contains('guest-1'),
    );
    expect(playersHistory.last, hasLength(1));
    expect(playersHistory.last.first.id, 'local');

    await sessionSub.cancel();
    await playersSub.cancel();
  });

  test('client emits HostDisconnected when connection drops', () async {
    final sessionEvents = <GameSessionEvent>[];
    final sessionSub = repository.sessionEvents.listen(sessionEvents.add);

    await repository.joinRoom(endpointId: 'host-1', userName: 'لاعب');

    connectedController.add({'host-1'});
    await Future<void>.delayed(Duration.zero);

    connectedController.add({});
    await Future<void>.delayed(Duration.zero);

    expect(sessionEvents.whereType<HostDisconnected>(), hasLength(1));
    verify(() => network.disconnectAll()).called(1);

    await sessionSub.cancel();
  });

  test('client applies player roster from host control payload', () async {
    final sessionEvents = <GameSessionEvent>[];
    final playersHistory = <List<dynamic>>[];

    final sessionSub = repository.sessionEvents.listen(sessionEvents.add);
    final playersSub = repository.players.listen(playersHistory.add);

    await repository.joinRoom(endpointId: 'host-1', userName: 'لاعب');

    when(() => encryption.decryptData(any())).thenReturn(
      jsonEncode({
        'type': P2pMessageType.playerRoster.value,
        'players': [
          {'id': 'local', 'name': 'لاعب', 'isHost': false},
          {'id': 'host-1', 'name': 'أحمد', 'isHost': true},
          {'id': 'guest-2', 'name': 'ضيف', 'isHost': false},
        ],
      }),
    );

    payloadController.add(
      P2pPayload(
        endpointId: 'host-1',
        bytes: Uint8List.fromList(utf8.encode('iv:cipher')),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(sessionEvents.whereType<RosterUpdated>(), hasLength(1));
    expect(playersHistory.last, hasLength(3));

    await sessionSub.cancel();
    await playersSub.cancel();
  });
}
