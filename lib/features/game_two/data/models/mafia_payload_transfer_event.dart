import 'package:equatable/equatable.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// Nearby payload transfer progress/failure event for a single endpoint.
class MafiaPayloadTransferEvent extends Equatable {
  const MafiaPayloadTransferEvent({
    required this.endpointId,
    required this.payloadId,
    required this.status,
    required this.bytesTransferred,
    required this.totalBytes,
  });

  final String endpointId;
  final int payloadId;
  final PayloadStatus status;
  final int bytesTransferred;
  final int totalBytes;

  bool get isFailure =>
      status == PayloadStatus.FAILURE || status == PayloadStatus.CANCELED;

  bool get isSuccess => status == PayloadStatus.SUCCESS;

  @override
  List<Object?> get props => [
        endpointId,
        payloadId,
        status,
        bytesTransferred,
        totalBytes,
      ];
}
