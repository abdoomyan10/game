import 'package:equatable/equatable.dart';

enum MafiaConnectionQuality { healthy, degraded, disconnected }

/// Per-endpoint connection health snapshot for Mafia P2P sessions.
class MafiaConnectionHealth extends Equatable {
  const MafiaConnectionHealth({
    required this.endpointId,
    required this.quality,
    this.roundTripMs,
    this.failedTransferCount = 0,
    this.lastPayloadAt,
  });

  final String endpointId;
  final MafiaConnectionQuality quality;
  final int? roundTripMs;
  final int failedTransferCount;
  final DateTime? lastPayloadAt;

  MafiaConnectionHealth copyWith({
    MafiaConnectionQuality? quality,
    int? roundTripMs,
    int? failedTransferCount,
    DateTime? lastPayloadAt,
  }) {
    return MafiaConnectionHealth(
      endpointId: endpointId,
      quality: quality ?? this.quality,
      roundTripMs: roundTripMs ?? this.roundTripMs,
      failedTransferCount: failedTransferCount ?? this.failedTransferCount,
      lastPayloadAt: lastPayloadAt ?? this.lastPayloadAt,
    );
  }

  @override
  List<Object?> get props => [
        endpointId,
        quality,
        roundTripMs,
        failedTransferCount,
        lastPayloadAt,
      ];
}
