import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_lobby_player.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
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

  const hostPlayer = MafiaLobbyPlayer(id: 'local', name: 'Host', isHost: true);
  const guestPlayer = MafiaLobbyPlayer(
    id: 'guest-1',
    name: 'Guest',
    isHost: false,
  );

  final twoPlayerLobby = [hostPlayer, guestPlayer];

  final twoPlayerConfig = MafiaGameConfig(
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
        id: 'guest-1',
        name: 'Guest',
        isHost: false,
        role: MafiaRole.citizen,
        isAlive: true,
        isSilenced: false,
      ),
    ],
  );

  setUp(() {
    repository = MockMafiaRepository();
    when(() => repository.sessionEvents).thenAnswer((_) => const Stream.empty());
    when(() => repository.players).thenAnswer((_) => const Stream.empty());
    when(() => repository.canStartGameUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.discoveredLobbies)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.isHost).thenReturn(true);
    when(() => repository.localPlayerId).thenReturn('local');
    when(() => repository.activeGameConfig).thenReturn(null);
    when(() => repository.lobbyPlayers).thenReturn(twoPlayerLobby);
    when(() => repository.canStartGame).thenReturn(true);
    when(() => repository.setActiveGameConfig(any()))
        .thenAnswer((_) async {});
    when(() => repository.disconnect())
        .thenAnswer((_) async => const Right<Failure, void>(null));
    bloc = MafiaBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
  });

  test('host starts game with two connected players', () async {
    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer, guestPlayer],
        isHost: true,
        userName: 'Host',
        canStartGame: true,
      ),
    );

    bloc.add(StartMafiaGame());

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<MafiaNightPhase>()
            .having((state) => state.config.players.length, 'players', 2)
            .having((state) => state.isHost, 'isHost', true)
            .having(
              (state) => state.activeWakeRole,
              'activeWakeRole',
              MafiaRole.mafiaBoss,
            ),
      ),
    );

    verify(() => repository.setActiveGameConfig(any())).called(1);
  });

  test('host starts using repository lobbyPlayers when bloc has one player', () async {
    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer],
        isHost: true,
        userName: 'Host',
        canStartGame: true,
      ),
    );

    bloc.add(StartMafiaGame());

    await expectLater(
      bloc.stream,
      emitsThrough(isA<MafiaNightPhase>()),
    );

    verify(() => repository.lobbyPlayers).called(greaterThan(0));
    verify(() => repository.setActiveGameConfig(any())).called(1);
  });

  test('host cannot start with fewer than two players', () async {
    when(() => repository.lobbyPlayers).thenReturn([hostPlayer]);

    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer],
        isHost: true,
        userName: 'Host',
        canStartGame: false,
      ),
    );

    bloc.add(StartMafiaGame());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, isA<MafiaLobby>());
    expect(
      (bloc.state as MafiaLobby).startErrorMessage,
      isNotNull,
    );
    verifyNever(() => repository.setActiveGameConfig(any()));
  });

  test('host starts when bloc has two players even if repo list lags', () async {
    when(() => repository.lobbyPlayers).thenReturn([hostPlayer]);

    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer, guestPlayer],
        isHost: true,
        userName: 'Host',
        canStartGame: true,
      ),
    );

    bloc.add(StartMafiaGame());

    await expectLater(
      bloc.stream,
      emitsThrough(isA<MafiaNightPhase>()),
    );

    verify(() => repository.setActiveGameConfig(any())).called(1);
  });

  test('client transitions to night phase on GameStarted', () async {
    when(() => repository.isHost).thenReturn(false);

    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer, guestPlayer],
        isHost: false,
        userName: 'Guest',
      ),
    );

    bloc.add(MafiaSessionEventReceived(GameStarted(twoPlayerConfig)));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<MafiaNightPhase>()
            .having((state) => state.config, 'config', twoPlayerConfig)
            .having((state) => state.isHost, 'isHost', false),
      ),
    );
  });

  test('CanStartGameUpdatedEvent updates lobby readiness', () async {
    bloc.emit(
      const MafiaLobby(
        players: [hostPlayer],
        isHost: true,
        userName: 'Host',
        canStartGame: false,
      ),
    );

    bloc.add(CanStartGameUpdatedEvent(true));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<MafiaLobby>().having(
          (state) => state.canStartGame,
          'canStartGame',
          true,
        ),
      ),
    );
  });
}
