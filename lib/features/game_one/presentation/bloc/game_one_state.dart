part of 'game_one_bloc.dart';

sealed class GameOneState extends Equatable {
  const GameOneState();

  @override
  List<Object?> get props => [];
}

final class GameOneInitial extends GameOneState {
  const GameOneInitial();
}

final class CreatingRoom extends GameOneState {
  const CreatingRoom({required this.userName});

  final String userName;

  @override
  List<Object?> get props => [userName];
}

final class DiscoveringRooms extends GameOneState {
  const DiscoveringRooms({
    required this.userName,
    required this.rooms,
    this.isJoining = false,
  });

  final String userName;
  final List<DiscoveredRoom> rooms;
  final bool isJoining;

  DiscoveringRooms copyWith({
    String? userName,
    List<DiscoveredRoom>? rooms,
    bool? isJoining,
  }) {
    return DiscoveringRooms(
      userName: userName ?? this.userName,
      rooms: rooms ?? this.rooms,
      isJoining: isJoining ?? this.isJoining,
    );
  }

  @override
  List<Object?> get props => [userName, rooms, isJoining];
}

final class InsideLobby extends GameOneState {
  const InsideLobby({
    required this.players,
    required this.isHost,
  });

  final List<Player> players;
  final bool isHost;

  @override
  List<Object?> get props => [players, isHost];
}

final class GameActive extends GameOneState {
  const GameActive({
    required this.role,
    required this.word,
    required this.remainingSeconds,
    required this.isHost,
  });

  final PlayerRole role;
  final String? word;
  final int remainingSeconds;
  final bool isHost;

  GameActive copyWith({
    PlayerRole? role,
    String? word,
    int? remainingSeconds,
    bool? isHost,
  }) {
    return GameActive(
      role: role ?? this.role,
      word: word ?? this.word,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isHost: isHost ?? this.isHost,
    );
  }

  @override
  List<Object?> get props => [role, word, remainingSeconds, isHost];
}

final class GameOneError extends GameOneState {
  const GameOneError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

final class SessionEnded extends GameOneState {
  const SessionEnded({
    required this.reason,
    required this.message,
  });

  final SessionEndReason reason;
  final String message;

  @override
  List<Object?> get props => [reason, message];
}
