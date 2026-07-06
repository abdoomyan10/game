import 'package:equatable/equatable.dart';

import 'mafia_lobby_player.dart';

sealed class MafiaSessionEvent extends Equatable {
  const MafiaSessionEvent();

  @override
  List<Object?> get props => [];
}

final class PeerDisconnected extends MafiaSessionEvent {
  const PeerDisconnected(this.playerId);

  final String playerId;

  @override
  List<Object?> get props => [playerId];
}

final class PeerReconnecting extends MafiaSessionEvent {
  const PeerReconnecting(this.playerId, this.deadline);

  final String playerId;
  final DateTime deadline;

  @override
  List<Object?> get props => [playerId, deadline];
}

final class PeerReconnected extends MafiaSessionEvent {
  const PeerReconnected(this.playerId);

  final String playerId;

  @override
  List<Object?> get props => [playerId];
}

final class PeerEliminated extends MafiaSessionEvent {
  const PeerEliminated(this.playerId);

  final String playerId;

  @override
  List<Object?> get props => [playerId];
}

final class SessionPaused extends MafiaSessionEvent {
  const SessionPaused(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

final class SessionResumed extends MafiaSessionEvent {
  const SessionResumed();
}

final class HostDisconnected extends MafiaSessionEvent {
  const HostDisconnected();
}

final class HostAdvertiserLost extends MafiaSessionEvent {
  const HostAdvertiserLost(this.endpointId);

  final String endpointId;

  @override
  List<Object?> get props => [endpointId];
}

final class RosterUpdated extends MafiaSessionEvent {
  const RosterUpdated(this.players);

  final List<MafiaLobbyPlayer> players;

  @override
  List<Object?> get props => [players];
}
