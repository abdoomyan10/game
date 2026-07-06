import 'package:equatable/equatable.dart';

/// Host-side receipt of a client phase-sync acknowledgment.
class MafiaPhaseAck extends Equatable {
  const MafiaPhaseAck({
    required this.correlationId,
    required this.endpointId,
    required this.receivedAt,
  });

  final String correlationId;
  final String endpointId;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [correlationId, endpointId, receivedAt];
}
