import 'package:equatable/equatable.dart';

import 'game_payload.dart';

/// Host-local result after distributing roles to all players.
class DistributeRolesResult extends Equatable {
  const DistributeRolesResult({required this.hostPayload});

  /// Payload for the host device only (never includes the real word for imposters).
  final GamePayload hostPayload;

  @override
  List<Object?> get props => [hostPayload];
}
