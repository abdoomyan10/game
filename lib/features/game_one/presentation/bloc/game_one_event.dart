part of 'game_one_bloc.dart';

sealed class GameOneEvent {}

final class InitializeGameFlow extends GameOneEvent {}

final class HostRoomEvent extends GameOneEvent {
  HostRoomEvent(this.userName);

  final String userName;
}

final class DiscoverRoomsEvent extends GameOneEvent {
  DiscoverRoomsEvent(this.userName, {this.endpointId});

  final String userName;
  final String? endpointId;
}

final class PlayerJoinedEvent extends GameOneEvent {
  PlayerJoinedEvent(this.players);

  final List<Player> players;
}

final class StartGameEvent extends GameOneEvent {}

final class PayloadReceivedEvent extends GameOneEvent {
  PayloadReceivedEvent(this.payload);

  final GamePayload payload;
}

final class DismissErrorEvent extends GameOneEvent {}

final class SessionEventReceived extends GameOneEvent {
  SessionEventReceived(this.event);

  final GameSessionEvent event;
}
