import '../../../game_one/domain/entities/p2p_disconnect_reason.dart';

class MafiaTransportException implements Exception {
  const MafiaTransportException({
    required this.message,
    this.reason,
  });

  final String message;
  final P2pDisconnectReason? reason;

  @override
  String toString() => message;
}

/// Thrown when not all clients ACK a phase sync within the timeout window.
class MafiaAckTimeoutException implements Exception {
  const MafiaAckTimeoutException({
    required this.correlationId,
    required this.missingEndpointIds,
  });

  final String correlationId;
  final Set<String> missingEndpointIds;

  @override
  String toString() =>
      'Phase ACK timeout for $correlationId; missing: $missingEndpointIds';
}
