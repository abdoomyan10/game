import 'package:equatable/equatable.dart';

import 'mafia_game_config.dart';
import 'mafia_player_day_payload.dart';
import 'mafia_victory_side.dart';

/// Host-side result after resolving a full night sequence.
class ProcessNightActionsResult extends Equatable {
  const ProcessNightActionsResult({
    required this.updatedConfig,
    required this.perPlayerPayloads,
    this.gameOverWinner,
  });

  final MafiaGameConfig updatedConfig;
  final Map<String, MafiaPlayerDayPayload> perPlayerPayloads;
  final MafiaVictorySide? gameOverWinner;

  @override
  List<Object?> get props => [updatedConfig, perPlayerPayloads, gameOverWinner];
}
