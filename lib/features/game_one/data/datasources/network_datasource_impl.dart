import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../../domain/entities/p2p_disconnect_reason.dart';
import '../constants/p2p_constants.dart';
import '../exceptions/p2p_exceptions.dart';
import '../services/p2p_permission_service.dart';
import 'network_datasource.dart';

/// Android Nearby Connections transport implementation.
///
/// - Host: advertises and auto-accepts incoming peers
/// - Client: discovers hosts and requests connection
///
/// Payload encryption is intentionally **not** done here — repositories call
/// [EncryptionService] then pass encrypted bytes to [sendPayload].
@LazySingleton(as: NetworkDataSource)
class NetworkDataSourceImpl implements NetworkDataSource {
  NetworkDataSourceImpl(this._permissionService) : _nearby = Nearby();

  final P2pPermissionService _permissionService;
  final Nearby _nearby;

  final _payloadController = StreamController<P2pPayload>.broadcast();
  final _endpointFoundController = StreamController<P2pEndpoint>.broadcast();
  final _connectedController = StreamController<Set<String>>.broadcast();
  final _endpointDisconnectedController =
      StreamController<String>.broadcast();
  final _endpointLostController = StreamController<String>.broadcast();

  final Set<String> _connectedEndpoints = {};
  String? _userName;
  bool _isHosting = false;
  bool _isDiscovering = false;

  @override
  Stream<P2pPayload> get onPayloadReceived => _payloadController.stream;

  @override
  Stream<P2pEndpoint> get onEndpointFound => _endpointFoundController.stream;

  @override
  Stream<Set<String>> get connectedEndpoints => _connectedController.stream;

  @override
  Stream<String> get onEndpointDisconnected =>
      _endpointDisconnectedController.stream;

  @override
  Stream<String> get onEndpointLost => _endpointLostController.stream;

  @override
  Future<void> startHosting({required String userName}) async {
    _userName = userName;
    await _ensurePermissions();

    await _nearby.startAdvertising(
      userName,
      Strategy.P2P_CLUSTER,
      serviceId: P2pConstants.serviceId,
      onConnectionInitiated: (endpointId, info) async {
        await _acceptEndpoint(endpointId);
      },
      onConnectionResult: (endpointId, status) {
        _handleConnectionResult(endpointId, status);
      },
      onDisconnected: (endpointId) {
        _handleDisconnected(endpointId);
      },
    );
    _isHosting = true;
  }

  @override
  Future<void> stopHosting() async {
    if (!_isHosting) return;
    await _nearby.stopAdvertising();
    _isHosting = false;
  }

  @override
  Future<void> startDiscovery({required String userName}) async {
    _userName = userName;
    await _ensurePermissions();

    await _nearby.startDiscovery(
      userName,
      Strategy.P2P_CLUSTER,
      serviceId: P2pConstants.serviceId,
      onEndpointFound: (endpointId, endpointName, serviceId) {
        _endpointFoundController.add(
          P2pEndpoint(id: endpointId, userName: endpointName),
        );
      },
      onEndpointLost: (endpointId) {
        if (endpointId != null) {
          _endpointLostController.add(endpointId);
        }
      },
    );
    _isDiscovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  @override
  Future<void> connectToHost({required String endpointId}) async {
    final userName = _userName;
    if (userName == null) {
      throw StateError('Call startDiscovery before connectToHost');
    }

    await _nearby.requestConnection(
      userName,
      endpointId,
      onConnectionInitiated: (id, info) async {
        await _acceptEndpoint(id);
      },
      onConnectionResult: (id, status) {
        _handleConnectionResult(id, status);
      },
      onDisconnected: (id) {
        _handleDisconnected(id);
      },
    );
  }

  @override
  Future<void> sendPayload({
    required String endpointId,
    required Uint8List data,
  }) async {
    await _nearby.sendBytesPayload(endpointId, data);
  }

  @override
  Future<void> disconnectAll() async {
    await stopHosting();
    await stopDiscovery();
    await _nearby.stopAllEndpoints();
    _connectedEndpoints.clear();
    _emitConnectedEndpoints();
  }

  Future<void> _acceptEndpoint(String endpointId) async {
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (payload.type != PayloadType.BYTES || payload.bytes == null) {
          return;
        }
        _payloadController.add(
          P2pPayload(endpointId: id, bytes: payload.bytes!),
        );
      },
      onPayloadTransferUpdate: null,
    );
  }

  void _handleConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _addConnectedEndpoint(endpointId);
      return;
    }

    if (status == Status.REJECTED) {
      throw const P2pTransportException(
        message: 'تم رفض الاتصال',
        reason: P2pDisconnectReason.connectionRejected,
      );
    }

    if (status == Status.ERROR) {
      throw const P2pTransportException(
        message: 'فشل الاتصال',
        reason: P2pDisconnectReason.connectionError,
      );
    }
  }

  void _handleDisconnected(String endpointId) {
    _removeConnectedEndpoint(endpointId);
    if (!_endpointDisconnectedController.isClosed) {
      _endpointDisconnectedController.add(endpointId);
    }
  }

  void _addConnectedEndpoint(String endpointId) {
    _connectedEndpoints.add(endpointId);
    _emitConnectedEndpoints();
  }

  void _removeConnectedEndpoint(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _emitConnectedEndpoints();
  }

  void _emitConnectedEndpoints() {
    if (!_connectedController.isClosed) {
      _connectedController.add(Set.unmodifiable(_connectedEndpoints));
    }
  }

  Future<void> _ensurePermissions() async {
    await _permissionService.ensureGranted();
  }
}
