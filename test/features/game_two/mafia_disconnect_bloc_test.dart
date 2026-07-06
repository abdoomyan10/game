import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/entities/mafia_session_end_reason.dart';
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

  final inProgressConfig = MafiaGameConfig(
    state: MafiaGameState.inProgress,
    phase: MafiaPhase.day,
    players: const [
      MafiaPlayerEntity(
        id: 'a',
        name: 'A',
        isHost: true,
        role: MafiaRole.citizen,
        isAlive: true,
        isSilenced: false,
      ),
      MafiaPlayerEntity(
        id: 'b',
        name: 'B',
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
    when(() => repository.discoveredLobbies)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.isHost).thenReturn(false);
    when(() => repository.localPlayerId).thenReturn('local');
    when(() => repository.activeGameConfig).thenReturn(null);
    when(() => repository.setActiveGameConfig(any())).thenReturn(null);
    when(() => repository.disconnect())
        .thenAnswer((_) async => const Right<Failure, void>(null));
    bloc = MafiaBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
  });

  test('PeerReconnecting wraps active phase in MafiaPaused', () async {
    bloc.emit(
      MafiaDayPhase(
        config: inProgressConfig,
        isHost: true,
        roundNumber: 1,
      ),
    );

    bloc.add(
      MafiaSessionEventReceived(
        PeerReconnecting('b', DateTime.now().add(const Duration(seconds: 10))),
      ),
    );

    final state = await bloc.stream.firstWhere((s) => s is MafiaPaused);
    expect(state, isA<MafiaPaused>());
    final paused = state as MafiaPaused;
    expect(paused.frozenPhase, isA<MafiaDayPhase>());
    expect(paused.reconnectingPlayerId, 'b');
  });

  test('HostDisconnected ends session with dialog flag', () async {
    bloc.emit(
      MafiaDayPhase(
        config: inProgressConfig,
        isHost: false,
        roundNumber: 1,
      ),
    );

    bloc.add(MafiaSessionEventReceived(const HostDisconnected()));

    final state =
        await bloc.stream.firstWhere((s) => s is MafiaSessionEnded) as MafiaSessionEnded;
    expect(state.reason, MafiaSessionEndReason.hostDisconnected);
    expect(state.showHostLostDialog, isTrue);
    verify(() => repository.disconnect()).called(1);
  });

  test('NextPhaseEvent is ignored while paused', () async {
    final dayPhase = MafiaDayPhase(
      config: inProgressConfig,
      isHost: true,
      roundNumber: 1,
    );
    bloc.emit(
      MafiaPaused(
        frozenPhase: dayPhase,
        reconnectingPlayerId: 'b',
        reconnectDeadline: DateTime.now().add(const Duration(seconds: 10)),
      ),
    );

    bloc.add(NextPhaseEvent());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, isA<MafiaPaused>());
  });

  test('PeerEliminated resumes with dead player in config', () async {
    final config = MafiaGameConfig(
      state: MafiaGameState.inProgress,
      phase: MafiaPhase.day,
      players: const [
        MafiaPlayerEntity(
          id: 'a',
          name: 'A',
          isHost: true,
          role: MafiaRole.citizen,
          isAlive: true,
          isSilenced: false,
        ),
        MafiaPlayerEntity(
          id: 'b',
          name: 'B',
          isHost: false,
          role: MafiaRole.citizen,
          isAlive: true,
          isSilenced: false,
        ),
        MafiaPlayerEntity(
          id: 'c',
          name: 'C',
          isHost: false,
          role: MafiaRole.citizen,
          isAlive: true,
          isSilenced: false,
        ),
        MafiaPlayerEntity(
          id: 'd',
          name: 'D',
          isHost: false,
          role: MafiaRole.mafiaBoss,
          isAlive: true,
          isSilenced: false,
        ),
      ],
    );
    final dayPhase = MafiaDayPhase(
      config: config,
      isHost: true,
      roundNumber: 1,
    );
    bloc.emit(
      MafiaPaused(
        frozenPhase: dayPhase,
        reconnectingPlayerId: 'b',
        reconnectDeadline: DateTime.now().add(const Duration(seconds: 10)),
      ),
    );

    bloc.add(MafiaSessionEventReceived(const PeerEliminated('b')));

    final state =
        await bloc.stream.firstWhere((s) => s is MafiaDayPhase) as MafiaDayPhase;
    final eliminated = state.config.players.firstWhere((p) => p.id == 'b');
    expect(eliminated.isAlive, isFalse);
    verify(() => repository.setActiveGameConfig(any())).called(1);
  });
}
