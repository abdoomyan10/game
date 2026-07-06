import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../models/mafia_connection_health.dart';
import '../models/mafia_payload_transfer_event.dart';

/// A nearby advertiser discovered during client discovery.
class MafiaP2pEndpoint extends Equatable {
  const MafiaP2pEndpoint({
    required this.id,
    required this.userName,
  });

  final String id;
  final String userName;

  @override
  List<Object?> get props => [id, userName];
}

/// Raw bytes received from a connected endpoint (before app-layer decryption).
class MafiaP2pPayload extends Equatable {
  const MafiaP2pPayload({
    required this.endpointId,
    required this.bytes,
  });

  final String endpointId;
  final Uint8List bytes;

  @override
  List<Object?> get props => [endpointId, bytes];
}

/// Transport + reliability contract for Mafia (Game Two) P2P sessions.
///
/// Android-only via `nearby_connections`. Encryption and game message typing
/// belong in [MafiaRepository] — this layer moves opaque bytes and coordinates
/// plaintext control frames (ping/pong/ack/phaseSync).
///
/// **Repository phase-sync pattern**
/// 1. Encrypt phase/role bytes per peer → [sendIsolatedPayload]
/// 2. [announcePhaseSync] with a shared [correlationId]
/// 3. [awaitPhaseAcks] before the host advances UI
/// 4. Clients auto-ACK on `phaseSync` control frames; game bytes arrive on
///    [onPayloadReceived] for repository decryption.
abstract class MafiaNetworkDataSource {
  // --- Host ---
  Future<void> startHosting({required String userName});
  Future<void> stopHosting();

  // --- Client ---
  Future<void> startDiscovery({required String userName});
  Future<void> stopDiscovery();
  Future<void> connectToHost({required String endpointId});

  // --- Shared transport ---
  Future<void> disconnectAll();

  /// Sends bytes to exactly one connected peer.
  ///
  /// Nearby byte payloads do not expose a payload id synchronously; track
  /// delivery via [payloadTransferUpdates].
  Future<void> sendIsolatedPayload({
    required String endpointId,
    required Uint8List data,
  });

  Stream<MafiaP2pPayload> get onPayloadReceived;
  Stream<MafiaP2pEndpoint> get onEndpointFound;
  Stream<Set<String>> get connectedEndpoints;
  Stream<String> get onEndpointDisconnected;
  Stream<String> get onEndpointLost;

  // --- Connection monitoring ---
  Stream<MafiaConnectionHealth> get connectionHealth;
  Stream<MafiaPayloadTransferEvent> get payloadTransferUpdates;
  void startHealthMonitoring();
  void stopHealthMonitoring();

  // --- Phase ACK coordination ---
  Future<void> announcePhaseSync({
    required String correlationId,
    required Set<String> endpointIds,
  });

  Future<void> awaitPhaseAcks({
    required String correlationId,
    required Set<String> endpointIds,
    Duration? timeout,
  });

  Stream<String> get onPhaseSyncAnnounced;

  Future<void> sendPhaseAck({
    required String correlationId,
    required String hostEndpointId,
  });
}
