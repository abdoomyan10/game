import 'package:equatable/equatable.dart';

import '../../domain/entities/mafia_discovered_lobby.dart';
import '../../domain/entities/mafia_game_config.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_role.dart';
import '../../domain/entities/mafia_session_end_reason.dart';
import '../../domain/entities/mafia_victory_side.dart';

sealed class MafiaState extends Equatable {
  const MafiaState();

  @override
  List<Object?> get props => [];
}

final class MafiaInitial extends MafiaState {
  const MafiaInitial();
}

final class DiscoveringLobbies extends MafiaState {
  const DiscoveringLobbies({
    required this.userName,
    required this.lobbies,
    this.isJoining = false,
  });

  final String userName;
  final List<MafiaDiscoveredLobby> lobbies;
  final bool isJoining;

  DiscoveringLobbies copyWith({
    String? userName,
    List<MafiaDiscoveredLobby>? lobbies,
    bool? isJoining,
  }) {
    return DiscoveringLobbies(
      userName: userName ?? this.userName,
      lobbies: lobbies ?? this.lobbies,
      isJoining: isJoining ?? this.isJoining,
    );
  }

  @override
  List<Object?> get props => [userName, lobbies, isJoining];
}

final class MafiaLobby extends MafiaState {
  const MafiaLobby({
    required this.players,
    required this.isHost,
    required this.userName,
    this.canStartGame = false,
    this.startErrorMessage,
  });

  final List<MafiaLobbyPlayer> players;
  final bool isHost;
  final String userName;
  final bool canStartGame;
  final String? startErrorMessage;

  MafiaLobby copyWith({
    List<MafiaLobbyPlayer>? players,
    bool? isHost,
    String? userName,
    bool? canStartGame,
    String? startErrorMessage,
    bool clearStartErrorMessage = false,
  }) {
    return MafiaLobby(
      players: players ?? this.players,
      isHost: isHost ?? this.isHost,
      userName: userName ?? this.userName,
      canStartGame: canStartGame ?? this.canStartGame,
      startErrorMessage: clearStartErrorMessage
          ? null
          : (startErrorMessage ?? this.startErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        players,
        isHost,
        userName,
        canStartGame,
        startErrorMessage,
      ];
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
    this.voteCounts = const {},
    this.myVoteTargetId,
  });

  final MafiaGameConfig config;
  final bool isHost;
  final int roundNumber;
  final Map<String, int> voteCounts;
  final String? myVoteTargetId;

  MafiaVotingPhase copyWith({
    MafiaGameConfig? config,
    bool? isHost,
    int? roundNumber,
    Map<String, int>? voteCounts,
    String? myVoteTargetId,
    bool clearMyVoteTargetId = false,
  }) {
    return MafiaVotingPhase(
      config: config ?? this.config,
      isHost: isHost ?? this.isHost,
      roundNumber: roundNumber ?? this.roundNumber,
      voteCounts: voteCounts ?? this.voteCounts,
      myVoteTargetId: clearMyVoteTargetId
          ? null
          : (myVoteTargetId ?? this.myVoteTargetId),
    );
  }

  @override
  List<Object?> get props => [
        config,
        isHost,
        roundNumber,
        voteCounts,
        myVoteTargetId,
      ];
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

final class MafiaPaused extends MafiaState {
  const MafiaPaused({
    required this.frozenPhase,
    required this.reconnectingPlayerId,
    required this.reconnectDeadline,
    this.statusMessage,
  });

  final MafiaState frozenPhase;
  final String reconnectingPlayerId;
  final DateTime reconnectDeadline;
  final String? statusMessage;

  @override
  List<Object?> get props => [
        frozenPhase,
        reconnectingPlayerId,
        reconnectDeadline,
        statusMessage,
      ];
}

final class MafiaSessionEnded extends MafiaState {
  const MafiaSessionEnded({
    required this.reason,
    required this.message,
    this.showHostLostDialog = false,
  });

  final MafiaSessionEndReason reason;
  final String message;
  final bool showHostLostDialog;

  @override
  List<Object?> get props => [reason, message, showHostLostDialog];
}
