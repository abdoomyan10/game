import '../entities/detective_check_result.dart';
import '../entities/mafia_day_public_summary.dart';
import '../entities/mafia_game_config.dart';
import '../entities/mafia_game_state.dart';
import '../entities/mafia_phase.dart';
import '../entities/mafia_player_day_payload.dart';
import '../entities/mafia_player_entity.dart';
import '../entities/mafia_role.dart';
import '../entities/mafia_victory_side.dart';
import '../entities/night_actions_input.dart';
import '../entities/process_night_actions_result.dart';

/// Resolves night actions into updated game state and minimum broadcast payloads.
ProcessNightActionsResult resolveNightActions({
  required MafiaGameConfig config,
  required int roundNumber,
  required NightActionsInput actions,
}) {
  final mafiaKill = actions.mafiaKillTargetId;
  final doctorSave = actions.doctorSaveTargetId;
  final sniperKill = actions.sniperTargetId;
  final silencerTarget = actions.silencerTargetId;
  final detectiveTarget = actions.detectiveTargetId;

  final deaths = <String>{};
  if (mafiaKill != null && mafiaKill != doctorSave) {
    deaths.add(mafiaKill);
  }
  if (sniperKill != null) {
    deaths.add(sniperKill);
  }

  final eliminatedIds = deaths.toList()..sort();

  DetectiveCheckResult? detectiveResult;
  if (detectiveTarget != null) {
    final target = _findPlayer(config.players, detectiveTarget);
    detectiveResult = DetectiveCheckResult(
      targetPlayerId: detectiveTarget,
      isMafia: target.role.isMafia,
    );
  }

  final updatedPlayers = config.players.map((player) {
    final silenced = silencerTarget != null && player.id == silencerTarget;
    final alive = player.isAlive && !deaths.contains(player.id);
    return player.copyWith(
      isAlive: alive,
      isSilenced: silenced,
    );
  }).toList();

  final publicSummary = MafiaDayPublicSummary(
    roundNumber: roundNumber,
    eliminatedPlayerIds: eliminatedIds,
  );

  final detectivePlayerId = _findPlayerIdByRole(
    config.players,
    MafiaRole.detective,
    aliveOnly: true,
  );

  final perPlayerPayloads = <String, MafiaPlayerDayPayload>{};
  for (final player in config.players) {
    perPlayerPayloads[player.id] = MafiaPlayerDayPayload(
      public: publicSummary,
      youAreSilenced: player.id == silencerTarget,
      investigation: player.id == detectivePlayerId ? detectiveResult : null,
    );
  }

  var updatedConfig = config.copyWith(
    phase: MafiaPhase.day,
    players: updatedPlayers,
  );

  final gameOverWinner = _checkVictory(updatedConfig);
  if (gameOverWinner != null) {
    updatedConfig = updatedConfig.copyWith(state: MafiaGameState.finished);
  }

  return ProcessNightActionsResult(
    updatedConfig: updatedConfig,
    perPlayerPayloads: perPlayerPayloads,
    gameOverWinner: gameOverWinner,
  );
}

MafiaPlayerEntity _findPlayer(
  List<MafiaPlayerEntity> players,
  String playerId,
) {
  return players.firstWhere((player) => player.id == playerId);
}

String? _findPlayerIdByRole(
  List<MafiaPlayerEntity> players,
  MafiaRole role, {
  required bool aliveOnly,
}) {
  for (final player in players) {
    if (player.role != role) continue;
    if (aliveOnly && !player.isAlive) continue;
    return player.id;
  }
  return null;
}

MafiaVictorySide? _checkVictory(MafiaGameConfig config) {
  final alive = config.activePlayers;
  final mafiaCount = alive.where((player) => player.role.isMafia).length;
  final citizenCount = alive.length - mafiaCount;

  if (mafiaCount == 0) {
    return MafiaVictorySide.citizens;
  }

  if (mafiaCount >= citizenCount) {
    return MafiaVictorySide.mafia;
  }

  return null;
}
