import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_bloc.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_event.dart';
import 'package:game/features/game_two/presentation/bloc/mafia_state.dart';
import 'package:mocktail/mocktail.dart';

import 'mafia_repository_mock.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockMafiaRepository repository;

  setUp(() {
    repository = MockMafiaRepository();
    when(() => repository.sessionEvents).thenAnswer((_) => const Stream.empty());
    when(() => repository.players).thenAnswer((_) => const Stream.empty());
    when(() => repository.discoveredLobbies)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.isHost).thenReturn(true);
    when(() => repository.localPlayerId).thenReturn('local');
    when(() => repository.activeGameConfig).thenReturn(null);
    when(() => repository.setActiveGameConfig(any())).thenReturn(null);
    when(() => repository.disconnect())
        .thenAnswer((_) async => const Right<Failure, void>(null));
  });

  final votingConfig = MafiaGameConfig(
    state: MafiaGameState.inProgress,
    phase: MafiaPhase.night,
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
    ],
  );

  MafiaVotingPhase votingState() {
    return MafiaVotingPhase(
      config: votingConfig.copyWith(phase: MafiaPhase.day),
      isHost: true,
      roundNumber: 1,
    );
  }

  test('CastVoteEvent increments tally for target', () async {
    final bloc = MafiaBloc(repository)..emit(votingState());
    bloc.add(CastVoteEvent('b'));

    final state = await bloc.stream.first as MafiaVotingPhase;
    expect(state.voteCounts['b'], 1);
    expect(state.myVoteTargetId, 'b');
    await bloc.close();
  });

  test('CastVoteEvent moves vote when target changes', () async {
    final bloc = MafiaBloc(repository)
      ..emit(
        votingState().copyWith(
          voteCounts: const {'b': 1},
          myVoteTargetId: 'b',
        ),
      );
    bloc.add(CastVoteEvent('c'));

    final state = await bloc.stream.first as MafiaVotingPhase;
    expect(state.voteCounts.containsKey('b'), isFalse);
    expect(state.voteCounts['c'], 1);
    expect(state.myVoteTargetId, 'c');
    await bloc.close();
  });

  test('CastVoteEvent is ignored outside voting phase', () async {
    final bloc = MafiaBloc(repository)
      ..emit(
        MafiaDayPhase(
          config: votingConfig.copyWith(phase: MafiaPhase.day),
          isHost: true,
          roundNumber: 1,
        ),
      );
    bloc.add(CastVoteEvent('b'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, isA<MafiaDayPhase>());
    await bloc.close();
  });
}
