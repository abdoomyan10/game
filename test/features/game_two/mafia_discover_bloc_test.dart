import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_discovered_lobby.dart';
import 'package:game/features/game_two/domain/entities/mafia_session_event.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_bloc.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_event.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_state.dart';
import 'package:mocktail/mocktail.dart';

import 'mafia_repository_mock.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockMafiaRepository repository;
  late MafiaBloc bloc;
  late StreamController<MafiaDiscoveredLobby> discoveredController;
  late StreamController<MafiaSessionEvent> sessionController;

  setUp(() {
    repository = MockMafiaRepository();
    discoveredController = StreamController<MafiaDiscoveredLobby>.broadcast();
    sessionController = StreamController<MafiaSessionEvent>.broadcast();

    when(() => repository.sessionEvents)
        .thenAnswer((_) => sessionController.stream);
    when(() => repository.discoveredLobbies)
        .thenAnswer((_) => discoveredController.stream);
    when(() => repository.players).thenAnswer((_) => const Stream.empty());
    when(() => repository.canStartGameUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.isHost).thenReturn(false);
    when(() => repository.localPlayerId).thenReturn('local');
    when(() => repository.activeGameConfig).thenReturn(null);
    when(() => repository.canStartGame).thenReturn(false);
    when(() => repository.setActiveGameConfig(any()))
        .thenAnswer((_) async {});
    when(() => repository.ensurePermissions())
        .thenAnswer((_) async => const Right<Failure, void>(null));
    when(() => repository.disconnect())
        .thenAnswer((_) async => const Right<Failure, void>(null));
    when(() => repository.scanForLobbies(any()))
        .thenAnswer((_) async => const Right<Failure, void>(null));
    when(
      () => repository.joinLobby(
        endpointId: any(named: 'endpointId'),
        userName: any(named: 'userName'),
      ),
    ).thenAnswer((_) async => const Right<Failure, void>(null));

    bloc = MafiaBloc(repository);
  });

  tearDown(() async {
    await discoveredController.close();
    await sessionController.close();
    await bloc.close();
  });

  test('scan emits DiscoveringLobbies and calls scanForLobbies', () async {
    bloc.add(DiscoverLobbyEvent('Guest'));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<DiscoveringLobbies>()
            .having((state) => state.userName, 'userName', 'Guest')
            .having((state) => state.lobbies, 'lobbies', isEmpty),
      ),
    );

    verify(() => repository.scanForLobbies('Guest')).called(1);
    verifyNever(
      () => repository.joinLobby(
        endpointId: any(named: 'endpointId'),
        userName: any(named: 'userName'),
      ),
    );
  });

  test('discovered lobby is appended to DiscoveringLobbies state', () async {
    bloc.add(DiscoverLobbyEvent('Guest'));
    await bloc.stream.firstWhere((state) => state is DiscoveringLobbies);

    discoveredController.add(
      const MafiaDiscoveredLobby(
        endpointId: 'host-1',
        hostName: 'Host Player',
      ),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<DiscoveringLobbies>()
            .having((state) => state.lobbies.length, 'lobbies.length', 1)
            .having(
              (state) => state.lobbies.first.hostName,
              'hostName',
              'Host Player',
            ),
      ),
    );
  });

  test('join with endpointId transitions to MafiaLobby', () async {
    bloc.emit(
      const DiscoveringLobbies(
        userName: 'Guest',
        lobbies: [
          MafiaDiscoveredLobby(
            endpointId: 'host-1',
            hostName: 'Host Player',
          ),
        ],
      ),
    );

    bloc.add(DiscoverLobbyEvent('Guest', endpointId: 'host-1'));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<MafiaLobby>()
            .having((state) => state.isHost, 'isHost', false)
            .having((state) => state.userName, 'userName', 'Guest'),
      ),
    );

    verify(
      () => repository.joinLobby(
        endpointId: 'host-1',
        userName: 'Guest',
      ),
    ).called(1);
  });

  test('HostAdvertiserLost removes lobby from DiscoveringLobbies', () async {
    bloc.emit(
      const DiscoveringLobbies(
        userName: 'Guest',
        lobbies: [
          MafiaDiscoveredLobby(
            endpointId: 'host-1',
            hostName: 'Host Player',
          ),
        ],
      ),
    );

    bloc.add(MafiaSessionEventReceived(HostAdvertiserLost('host-1')));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<DiscoveringLobbies>().having(
          (state) => state.lobbies,
          'lobbies',
          isEmpty,
        ),
      ),
    );
  });
}
