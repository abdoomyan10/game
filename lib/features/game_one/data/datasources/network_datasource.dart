import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A nearby advertiser discovered during client discovery.
class P2pEndpoint extends Equatable {
  const P2pEndpoint({
    required this.id,
    required this.userName,
  });

  final String id;
  final String userName;

  @override
  List<Object?> get props => [id, userName];
}

/// Raw bytes received from a connected endpoint (before app-layer decryption).
class P2pPayload extends Equatable {
  const P2pPayload({
    required this.endpointId,
    required this.bytes,
  });

  final String endpointId;
  final Uint8List bytes;

  @override
  List<Object?> get props => [endpointId, bytes];
}

/// Transport-only P2P contract for Game One.
///
/// Android-only via `nearby_connections`. Encryption is handled separately by
/// [EncryptionService] in the repository layer.
abstract class NetworkDataSource {
  // --- Host ---
  Future<void> startHosting({required String userName});
  Future<void> stopHosting();

  // --- Client ---
  Future<void> startDiscovery({required String userName});
  Future<void> stopDiscovery();
  Future<void> connectToHost({required String endpointId});

  // --- Shared ---
  Future<void> sendPayload({
    required String endpointId,
    required Uint8List data,
  });

  /// Emits raw bytes from any connected endpoint (before decryption).
  Stream<P2pPayload> get onPayloadReceived;

  /// Client: nearby advertisers found during discovery.
  Stream<P2pEndpoint> get onEndpointFound;

  /// Connected endpoint IDs (host may have many; client typically one).
  Stream<Set<String>> get connectedEndpoints;

  /// Emits endpoint IDs when a peer disconnects.
  Stream<String> get onEndpointDisconnected;

  /// Client discovery: advertiser no longer visible.
  Stream<String> get onEndpointLost;

  Future<void> disconnectAll();
}
