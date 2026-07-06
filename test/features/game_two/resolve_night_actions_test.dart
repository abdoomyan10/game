import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/entities/mafia_victory_side.dart';
import 'package:game/features/game_two/domain/entities/night_actions_input.dart';
import 'package:game/features/game_two/domain/logic/resolve_night_actions.dart';

void main() {
  MafiaGameConfig configWith(List<MafiaPlayerEntity> players) {
    return MafiaGameConfig(
      state: MafiaGameState.inProgress,
      phase: MafiaPhase.night,
      players: players,
    );
  }

  const boss = MafiaPlayerEntity(
    id: 'boss',
    name: 'Boss',
    isHost: true,
    role: MafiaRole.mafiaBoss,
    isAlive: true,
    isSilenced: false,
  );
  const silencer = MafiaPlayerEntity(
    id: 'silencer',
    name: 'Silencer',
    isHost: false,
    role: MafiaRole.silencerMafia,
    isAlive: true,
    isSilenced: false,
  );
  const detective = MafiaPlayerEntity(
    id: 'detective',
    name: 'Detective',
    isHost: false,
    role: MafiaRole.detective,
    isAlive: true,
    isSilenced: false,
  );
  const doctor = MafiaPlayerEntity(
    id: 'doctor',
    name: 'Doctor',
    isHost: false,
    role: MafiaRole.doctor,
    isAlive: true,
    isSilenced: false,
  );
  const sniper = MafiaPlayerEntity(
    id: 'sniper',
    name: 'Sniper',
    isHost: false,
    role: MafiaRole.sniper,
    isAlive: true,
    isSilenced: false,
  );
  const citizenA = MafiaPlayerEntity(
    id: 'citizen-a',
    name: 'Citizen A',
    isHost: false,
    role: MafiaRole.citizen,
    isAlive: true,
    isSilenced: false,
  );
  const citizenB = MafiaPlayerEntity(
    id: 'citizen-b',
    name: 'Citizen B',
    isHost: false,
    role: MafiaRole.citizen,
    isAlive: true,
    isSilenced: false,
  );

  group('resolveNightActions', () {
    test('doctor save cancels mafia kill but not sniper kill', () {
      final result = resolveNightActions(
        config: configWith([
          boss,
          doctor,
          sniper,
          citizenA,
          citizenB,
        ]),
        roundNumber: 1,
        actions: const NightActionsInput(
          mafiaKillTargetId: 'citizen-a',
          doctorSaveTargetId: 'citizen-a',
          sniperTargetId: 'citizen-b',
        ),
      );

      expect(result.updatedConfig.phase, MafiaPhase.day);
      expect(
        result.updatedConfig.players.firstWhere((p) => p.id == 'citizen-a').isAlive,
        isTrue,
      );
      expect(
        result.updatedConfig.players.firstWhere((p) => p.id == 'citizen-b').isAlive,
        isFalse,
      );
      expect(result.updatedConfig.activePlayers.length, 4);
    });

    test('dedupes death when mafia and sniper target same player', () {
      final result = resolveNightActions(
        config: configWith([boss, sniper, citizenA, citizenB]),
        roundNumber: 2,
        actions: const NightActionsInput(
          mafiaKillTargetId: 'citizen-a',
          sniperTargetId: 'citizen-a',
        ),
      );

      expect(result.updatedConfig.players.firstWhere((p) => p.id == 'citizen-a').isAlive, isFalse);
      expect(result.updatedConfig.players.where((p) => !p.isAlive).length, 1);
      expect(result.perPlayerPayloads['citizen-a']!.public.eliminatedPlayerIds, ['citizen-a']);
    });

    test('marks silenced player and keeps silence private in public summary', () {
      final result = resolveNightActions(
        config: configWith([boss, silencer, detective, doctor, citizenA, citizenB]),
        roundNumber: 1,
        actions: const NightActionsInput(
          mafiaKillTargetId: 'citizen-a',
          silencerTargetId: 'citizen-b',
          detectiveTargetId: 'boss',
          doctorSaveTargetId: 'citizen-a',
          sniperTargetId: null,
        ),
      );

      expect(
        result.updatedConfig.players.firstWhere((p) => p.id == 'citizen-b').isSilenced,
        isTrue,
      );
      expect(result.perPlayerPayloads['citizen-b']!.youAreSilenced, isTrue);
      expect(result.perPlayerPayloads['boss']!.youAreSilenced, isFalse);
      expect(result.perPlayerPayloads['boss']!.public.eliminatedPlayerIds, isNot(contains('citizen-b')));
    });

    test('detective investigation is private to detective endpoint only', () {
      final result = resolveNightActions(
        config: configWith([boss, detective, citizenA]),
        roundNumber: 1,
        actions: const NightActionsInput(
          mafiaKillTargetId: 'citizen-a',
          detectiveTargetId: 'boss',
        ),
      );

      final detectivePayload = result.perPlayerPayloads['detective']!;
      expect(detectivePayload.investigation?.targetPlayerId, 'boss');
      expect(detectivePayload.investigation?.isMafia, isTrue);
      expect(result.perPlayerPayloads['boss']!.investigation, isNull);
      expect(result.perPlayerPayloads['citizen-a']!.investigation, isNull);
    });

    test('returns citizens victory when all mafia eliminated at night', () {
      final result = resolveNightActions(
        config: configWith([boss, sniper, citizenA]),
        roundNumber: 1,
        actions: const NightActionsInput(
          mafiaKillTargetId: 'citizen-a',
          sniperTargetId: 'boss',
        ),
      );

      expect(result.gameOverWinner, MafiaVictorySide.citizens);
      expect(result.updatedConfig.state, MafiaGameState.finished);
    });
  });
}
