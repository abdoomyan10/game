import 'package:equatable/equatable.dart';

enum MafiaSessionControlType {
  sessionPaused,
  sessionResumed,
  playerEliminated,
  rejoinAck,
}

/// Session-wide control broadcast from host to clients.
class MafiaSessionControl extends Equatable {
  const MafiaSessionControl({
    required this.type,
    this.playerId,
    this.deadlineMs,
    this.accepted,
  });

  final MafiaSessionControlType type;
  final String? playerId;
  final int? deadlineMs;
  final bool? accepted;

  @override
  List<Object?> get props => [type, playerId, deadlineMs, accepted];
}
