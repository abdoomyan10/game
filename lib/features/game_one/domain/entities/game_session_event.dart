import 'package:equatable/equatable.dart';

import 'player.dart';

sealed class GameSessionEvent extends Equatable {
  const GameSessionEvent();

  @override
  List<Object?> get props => [];
}

final class ClientDisconnected extends GameSessionEvent {
  const ClientDisconnected(this.endpointId);

  final String endpointId;

  @override
  List<Object?> get props => [endpointId];
}

final class HostDisconnected extends GameSessionEvent {
  const HostDisconnected();
}

final class EndpointLost extends GameSessionEvent {
  const EndpointLost(this.endpointId);

  final String endpointId;

  @override
  List<Object?> get props => [endpointId];
}

final class RosterUpdated extends GameSessionEvent {
  const RosterUpdated(this.players);

  final List<Player> players;

  @override
  List<Object?> get props => [players];
}
