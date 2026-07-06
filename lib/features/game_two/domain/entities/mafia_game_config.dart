import 'package:equatable/equatable.dart';

import 'mafia_game_state.dart';
import 'mafia_phase.dart';
import 'mafia_player_entity.dart';

class MafiaGameConfig extends Equatable {
  const MafiaGameConfig({
    required this.state,
    required this.phase,
    required this.players,
  });

  final MafiaGameState state;
  final MafiaPhase phase;
  final List<MafiaPlayerEntity> players;

  List<MafiaPlayerEntity> get activePlayers =>
      players.where((player) => player.isAlive).toList();

  MafiaGameConfig copyWith({
    MafiaGameState? state,
    MafiaPhase? phase,
    List<MafiaPlayerEntity>? players,
  }) {
    return MafiaGameConfig(
      state: state ?? this.state,
      phase: phase ?? this.phase,
      players: players ?? this.players,
    );
  }

  @override
  List<Object?> get props => [state, phase, players];
}
