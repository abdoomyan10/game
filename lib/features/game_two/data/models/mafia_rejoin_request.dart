import 'package:equatable/equatable.dart';

/// Host receives a reconnect attempt from a dropped client.
class MafiaRejoinRequest extends Equatable {
  const MafiaRejoinRequest({
    required this.endpointId,
    required this.playerId,
    required this.sessionToken,
  });

  final String endpointId;
  final String playerId;
  final String sessionToken;

  @override
  List<Object?> get props => [endpointId, playerId, sessionToken];
}
