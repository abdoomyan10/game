import 'package:equatable/equatable.dart';

import '../../domain/entities/mafia_game_config.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_role.dart';

enum MafiaVictorySide { mafia, citizens }

sealed class MafiaState extends Equatable {
  const MafiaState();

  @override
  List<Object?> get props => [];
}

final class MafiaInitial extends MafiaState {
  const MafiaInitial();
}

final class MafiaLobby extends MafiaState {
  const MafiaLobby({
    required this.players,
    required this.isHost,
    required this.userName,
  });

  final List<MafiaLobbyPlayer> players;
  final bool isHost;
  final String userName;

  MafiaLobby copyWith({
    List<MafiaLobbyPlayer>? players,
    bool? isHost,
    String? userName,
  }) {
    return MafiaLobby(
      players: players ?? this.players,
      isHost: isHost ?? this.isHost,
      userName: userName ?? this.userName,
    );
  }

  @override
  List<Object?> get props => [players, isHost, userName];
}

final class MafiaNightPhase extends MafiaState {
  const MafiaNightPhase({
    required this.config,
    required this.activeWakeRole,
    required this.completedWakeRoles,
    required this.isHost,
    required this.roundNumber,
  });

  final MafiaGameConfig config;
  final MafiaRole activeWakeRole;
  final Set<MafiaRole> completedWakeRoles;
  final bool isHost;
  final int roundNumber;

  MafiaNightPhase copyWith({
    MafiaGameConfig? config,
    MafiaRole? activeWakeRole,
    Set<MafiaRole>? completedWakeRoles,
    bool? isHost,
    int? roundNumber,
  }) {
    return MafiaNightPhase(
      config: config ?? this.config,
      activeWakeRole: activeWakeRole ?? this.activeWakeRole,
      completedWakeRoles: completedWakeRoles ?? this.completedWakeRoles,
      isHost: isHost ?? this.isHost,
      roundNumber: roundNumber ?? this.roundNumber,
    );
  }

  @override
  List<Object?> get props => [
        config,
        activeWakeRole,
        completedWakeRoles,
        isHost,
        roundNumber,
      ];
}

final class MafiaDayPhase extends MafiaState {
  const MafiaDayPhase({
    required this.config,
    required this.isHost,
    required this.roundNumber,
  });

  final MafiaGameConfig config;
  final bool isHost;
  final int roundNumber;

  MafiaDayPhase copyWith({
    MafiaGameConfig? config,
    bool? isHost,
    int? roundNumber,
  }) {
    return MafiaDayPhase(
      config: config ?? this.config,
      isHost: isHost ?? this.isHost,
      roundNumber: roundNumber ?? this.roundNumber,
    );
  }

  @override
  List<Object?> get props => [config, isHost, roundNumber];
}

final class MafiaVotingPhase extends MafiaState {
  const MafiaVotingPhase({
    required this.config,
    required this.isHost,
    required this.roundNumber,
  });

  final MafiaGameConfig config;
  final bool isHost;
  final int roundNumber;

  MafiaVotingPhase copyWith({
    MafiaGameConfig? config,
    bool? isHost,
    int? roundNumber,
  }) {
    return MafiaVotingPhase(
      config: config ?? this.config,
      isHost: isHost ?? this.isHost,
      roundNumber: roundNumber ?? this.roundNumber,
    );
  }

  @override
  List<Object?> get props => [config, isHost, roundNumber];
}

final class MafiaGameOver extends MafiaState {
  const MafiaGameOver({
    required this.config,
    required this.winner,
    required this.message,
  });

  final MafiaGameConfig config;
  final MafiaVictorySide winner;
  final String message;

  @override
  List<Object?> get props => [config, winner, message];
}
