import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_role.dart';

sealed class MafiaEvent {}

final class InitMafiaFlow extends MafiaEvent {}

final class HostLobbyEvent extends MafiaEvent {
  HostLobbyEvent(this.userName);

  final String userName;
}

final class DiscoverLobbyEvent extends MafiaEvent {
  DiscoverLobbyEvent(this.userName, {this.endpointId});

  final String userName;
  final String? endpointId;
}

final class PlayersUpdatedEvent extends MafiaEvent {
  PlayersUpdatedEvent(this.players);

  final List<MafiaLobbyPlayer> players;
}

final class StartMafiaGame extends MafiaEvent {}

final class NextPhaseEvent extends MafiaEvent {}

final class ExecuteRoleAction extends MafiaEvent {
  ExecuteRoleAction({
    required this.actingRole,
    this.targetPlayerId,
  });

  final MafiaRole actingRole;
  final String? targetPlayerId;
}
