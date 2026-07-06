import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/entities/night_actions_input.dart';
import 'package:game/features/game_two/domain/repositories/mafia_repository.dart';
import 'package:game/features/game_two/domain/usecases/process_night_actions_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockMafiaRepository extends Mock implements MafiaRepository {}

void main() {
  late MockMafiaRepository repository;
  late ProcessNightActionsUseCase useCase;

  setUp(() {
    repository = MockMafiaRepository();
    useCase = ProcessNightActionsUseCase(repository);
    when(() => repository.isHost).thenReturn(true);
  });

  const config = MafiaGameConfig(
    state: MafiaGameState.inProgress,
    phase: MafiaPhase.night,
    players: [
      MafiaPlayerEntity(
        id: 'boss',
        name: 'Boss',
        isHost: true,
        role: MafiaRole.mafiaBoss,
        isAlive: true,
        isSilenced: false,
      ),
      MafiaPlayerEntity(
        id: 'citizen',
        name: 'Citizen',
        isHost: false,
        role: MafiaRole.citizen,
        isAlive: true,
        isSilenced: false,
      ),
    ],
  );

  test('fails when caller is not host', () async {
    when(() => repository.isHost).thenReturn(false);

    final result = await useCase(
      const ProcessNightActionsParams(
        config: config,
        roundNumber: 1,
        actions: NightActionsInput(mafiaKillTargetId: 'citizen'),
      ),
    );

    expect(result, const Left(ServerFailure(message: 'Only the host can process night actions')));
  });

  test('fails when target is not alive', () async {
    final result = await useCase(
      const ProcessNightActionsParams(
        config: config,
        roundNumber: 1,
        actions: NightActionsInput(mafiaKillTargetId: 'missing'),
      ),
    );

    expect(
      result.fold((l) => l.message, (_) => ''),
      'Invalid target: player is not alive',
    );
  });

  test('returns per-player payloads on happy path', () async {
    final result = await useCase(
      const ProcessNightActionsParams(
        config: config,
        roundNumber: 1,
        actions: NightActionsInput(mafiaKillTargetId: 'citizen'),
      ),
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected success'),
      (value) {
        expect(value.updatedConfig.phase, MafiaPhase.day);
        expect(value.perPlayerPayloads.keys, containsAll(['boss', 'citizen']));
        expect(value.perPlayerPayloads['citizen']!.public.eliminatedPlayerIds, ['citizen']);
      },
    );
  });
}
