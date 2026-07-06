import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../../../game_one/data/exceptions/p2p_exceptions.dart';
import '../../../game_one/data/services/p2p_permission_service.dart';
import '../../../game_one/domain/entities/p2p_disconnect_reason.dart';
import '../constants/mafia_p2p_constants.dart';
import '../exceptions/mafia_p2p_exceptions.dart';
import '../models/mafia_connection_health.dart';
import '../models/mafia_payload_transfer_event.dart';
import '../models/mafia_rejoin_request.dart';
import '../models/mafia_session_control.dart';
import 'mafia_network_datasource.dart';
import 'mafia_p2p_protocol.dart';

/// Android Nearby Connections transport for Mafia with health monitoring,
/// per-endpoint delivery guards, and phase-sync ACK coordination.
@LazySingleton(as: MafiaNetworkDataSource)
class MafiaNetworkDataSourceImpl implements MafiaNetworkDataSource {
  MafiaNetworkDataSourceImpl(this._permissionService) : _nearby = Nearby() {
    _healthTracker = MafiaConnectionHealthTracker(
      staleThreshold: MafiaP2pConstants.healthStaleThreshold,
    );
    _ackCoordinator = MafiaAckCoordinator();
  }

  final P2pPermissionService _permissionService;
  final Nearby _nearby;

  late final MafiaConnectionHealthTracker _healthTracker;
  late final MafiaAckCoordinator _ackCoordinator;

  final _payloadController = StreamController<MafiaP2pPayload>.broadcast();
  final _endpointFoundController =
      StreamController<MafiaP2pEndpoint>.broadcast();
  final _connectedController = StreamController<Set<String>>.broadcast();
  final _endpointDisconnectedController =
      StreamController<String>.broadcast();
  final _endpointLostController = StreamController<String>.broadcast();
  final _connectionHealthController =
      StreamController<MafiaConnectionHealth>.broadcast();
  final _payloadTransferController =
      StreamController<MafiaPayloadTransferEvent>.broadcast();
  final _phaseSyncAnnouncedController =
      StreamController<String>.broadcast();
  final _rejoinRequestedController =
      StreamController<MafiaRejoinRequest>.broadcast();
  final _sessionControlController =
      StreamController<MafiaSessionControl>.broadcast();

  final Set<String> _connectedEndpoints = {};
  final Map<int, String> _payloadEndpointById = {};

  String? _userName;
  bool _isHosting = false;
  bool _isDiscovering = false;
  bool _healthMonitoring = false;
  Timer? _healthPingTimer;
  int _pingSequence = 0;

  @override
  Stream<MafiaP2pPayload> get onPayloadReceived => _payloadController.stream;

  @override
  Stream<MafiaP2pEndpoint> get onEndpointFound =>
      _endpointFoundController.stream;

  @override
  Stream<Set<String>> get connectedEndpoints => _connectedController.stream;

  @override
  Stream<String> get onEndpointDisconnected =>
      _endpointDisconnectedController.stream;

  @override
  Stream<String> get onEndpointLost => _endpointLostController.stream;

  @override
  Stream<MafiaConnectionHealth> get connectionHealth =>
      _connectionHealthController.stream;

  @override
  Stream<MafiaPayloadTransferEvent> get payloadTransferUpdates =>
      _payloadTransferController.stream;

  @override
  Stream<String> get onPhaseSyncAnnounced =>
      _phaseSyncAnnouncedController.stream;

  @override
  Stream<MafiaRejoinRequest> get onRejoinRequested =>
      _rejoinRequestedController.stream;

  @override
  Stream<MafiaSessionControl> get onSessionControl =>
      _sessionControlController.stream;

  @override
  Future<void> startHosting({required String userName}) async {
    _userName = userName;
    await _ensurePermissions();

    await _nearby.startAdvertising(
      userName,
      Strategy.P2P_CLUSTER,
      serviceId: MafiaP2pConstants.serviceId,
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
      serviceId: MafiaP2pConstants.serviceId,
      onEndpointFound: (endpointId, endpointName, serviceId) {
        _endpointFoundController.add(
          MafiaP2pEndpoint(id: endpointId, userName: endpointName),
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
  Future<void> sendIsolatedPayload({
    required String endpointId,
    required Uint8List data,
  }) async {
    if (!_connectedEndpoints.contains(endpointId)) {
      throw MafiaTransportException(
        message: 'Endpoint not connected: $endpointId',
        reason: P2pDisconnectReason.clientLeft,
      );
    }

    await _nearby.sendBytesPayload(endpointId, data);
  }

  @override
  Future<void> disconnectAll() async {
    stopHealthMonitoring();
    _ackCoordinator.clear();
    await stopHosting();
    await stopDiscovery();
    await _nearby.stopAllEndpoints();
    _connectedEndpoints.clear();
    _payloadEndpointById.clear();
    _healthTracker.clear();
    _emitConnectedEndpoints();
  }

  @override
  void startHealthMonitoring() {
    if (_healthMonitoring) return;
    _healthMonitoring = true;
    _healthPingTimer?.cancel();
    _healthPingTimer = Timer.periodic(
      MafiaP2pConstants.healthPingInterval,
      (_) => unawaited(_sendHealthPings()),
    );
  }

  @override
  void stopHealthMonitoring() {
    _healthMonitoring = false;
    _healthPingTimer?.cancel();
    _healthPingTimer = null;
  }

  @override
  Future<void> announcePhaseSync({
    required String correlationId,
    required Set<String> endpointIds,
  }) async {
    final frame = MafiaP2pProtocol.buildPhaseSync(correlationId: correlationId);
    for (final endpointId in endpointIds) {
      await sendIsolatedPayload(endpointId: endpointId, data: frame);
    }
  }

  @override
  Future<void> awaitPhaseAcks({
    required String correlationId,
    required Set<String> endpointIds,
    Duration? timeout,
  }) async {
    _ackCoordinator.registerExpectation(
      correlationId: correlationId,
      endpointIds: endpointIds,
      timeout: timeout ?? MafiaP2pConstants.phaseAckTimeout,
    );
    await _ackCoordinator.waitForAcks(correlationId);
  }

  @override
  Future<void> sendPhaseAck({
    required String correlationId,
    required String hostEndpointId,
  }) async {
    final frame = MafiaP2pProtocol.buildAck(correlationId: correlationId);
    await sendIsolatedPayload(endpointId: hostEndpointId, data: frame);
  }

  @override
  Future<void> sendRejoin({
    required String hostEndpointId,
    required String playerId,
    required String sessionToken,
  }) async {
    final frame = MafiaP2pProtocol.buildRejoin(
      playerId: playerId,
      sessionToken: sessionToken,
    );
    await sendIsolatedPayload(endpointId: hostEndpointId, data: frame);
  }

  Future<void> _acceptEndpoint(String endpointId) async {
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (payload.type != PayloadType.BYTES || payload.bytes == null) {
          return;
        }
        _payloadEndpointById[payload.id] = id;
        _handleIncomingPayload(
          endpointId: id,
          bytes: payload.bytes!,
        );
      },
      onPayloadTransferUpdate: (id, update) {
        _handlePayloadTransferUpdate(id, update);
      },
    );
  }

  void _handleIncomingPayload({
    required String endpointId,
    required Uint8List bytes,
  }) {
    final control = MafiaP2pProtocol.tryParseControlPayload(bytes);
    if (control != null) {
      unawaited(_handleControlPayload(endpointId: endpointId, control: control));
      return;
    }

    _emitHealth(_healthTracker.recordPayloadSuccess(endpointId));
    _payloadController.add(MafiaP2pPayload(endpointId: endpointId, bytes: bytes));
  }

  Future<void> _handleControlPayload({
    required String endpointId,
    required MafiaControlPayload control,
  }) async {
    switch (control.type) {
      case MafiaControlMessageType.ping:
        final pingId = control.pingId;
        if (pingId == null) return;
        await sendIsolatedPayload(
          endpointId: endpointId,
          data: MafiaP2pProtocol.buildPong(
            pingId: pingId,
            sentAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      case MafiaControlMessageType.pong:
        final pongSentAt = control.sentAtMs;
        if (pongSentAt == null) return;
        final health = _healthTracker.recordPong(
          endpointId: endpointId,
          pongSentAtMs: pongSentAt,
        );
        if (health != null) _emitHealth(health);
      case MafiaControlMessageType.ack:
        final correlationId = control.correlationId;
        if (correlationId == null) return;
        _ackCoordinator.recordAck(
          correlationId: correlationId,
          endpointId: endpointId,
        );
      case MafiaControlMessageType.phaseSync:
        final correlationId = control.correlationId;
        if (correlationId == null) return;
        if (!_phaseSyncAnnouncedController.isClosed) {
          _phaseSyncAnnouncedController.add(correlationId);
        }
        await sendPhaseAck(
          correlationId: correlationId,
          hostEndpointId: endpointId,
        );
      case MafiaControlMessageType.rejoin:
        final playerId = control.playerId;
        final sessionToken = control.sessionToken;
        if (playerId == null || sessionToken == null) return;
        if (!_rejoinRequestedController.isClosed) {
          _rejoinRequestedController.add(
            MafiaRejoinRequest(
              endpointId: endpointId,
              playerId: playerId,
              sessionToken: sessionToken,
            ),
          );
        }
      case MafiaControlMessageType.rejoinAck:
        _emitSessionControl(
          MafiaSessionControl(
            type: MafiaSessionControlType.rejoinAck,
            playerId: control.playerId,
            accepted: control.accepted,
          ),
        );
      case MafiaControlMessageType.sessionPaused:
        _emitSessionControl(
          MafiaSessionControl(
            type: MafiaSessionControlType.sessionPaused,
            playerId: control.playerId,
            deadlineMs: control.deadlineMs,
          ),
        );
      case MafiaControlMessageType.sessionResumed:
        _emitSessionControl(
          const MafiaSessionControl(type: MafiaSessionControlType.sessionResumed),
        );
      case MafiaControlMessageType.playerEliminated:
        _emitSessionControl(
          MafiaSessionControl(
            type: MafiaSessionControlType.playerEliminated,
            playerId: control.playerId,
          ),
        );
    }
  }

  void _emitSessionControl(MafiaSessionControl control) {
    if (!_sessionControlController.isClosed) {
      _sessionControlController.add(control);
    }
  }

  void _handlePayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    _payloadEndpointById[update.id] = endpointId;

    final event = MafiaPayloadTransferEvent(
      endpointId: endpointId,
      payloadId: update.id,
      status: update.status,
      bytesTransferred: update.bytesTransferred,
      totalBytes: update.totalBytes,
    );

    if (!_payloadTransferController.isClosed) {
      _payloadTransferController.add(event);
    }

    if (event.isFailure) {
      _emitHealth(_healthTracker.recordTransferFailure(endpointId));
      return;
    }

    if (event.isSuccess) {
      _emitHealth(_healthTracker.recordPayloadSuccess(endpointId));
    }
  }

  Future<void> _sendHealthPings() async {
    if (!_healthMonitoring || _connectedEndpoints.isEmpty) return;

    final now = DateTime.now();
    for (final stale in _healthTracker.evaluateStale(now)) {
      _emitHealth(stale);
    }

    for (final endpointId in _connectedEndpoints) {
      final pingId = '${_pingSequence++}';
      final sentAtMs = now.millisecondsSinceEpoch;
      _healthTracker.registerPing(endpointId, sentAtMs);
      try {
        await sendIsolatedPayload(
          endpointId: endpointId,
          data: MafiaP2pProtocol.buildPing(
            pingId: pingId,
            sentAtMs: sentAtMs,
          ),
        );
      } on MafiaTransportException {
        _emitHealth(_healthTracker.markDisconnected(endpointId));
      }
    }
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
    _ackCoordinator.removeEndpointFromAllExpectations(endpointId);
    _removeConnectedEndpoint(endpointId);
    if (!_endpointDisconnectedController.isClosed) {
      _endpointDisconnectedController.add(endpointId);
    }
  }

  void _addConnectedEndpoint(String endpointId) {
    _connectedEndpoints.add(endpointId);
    _emitHealth(_healthTracker.markConnected(endpointId));
    _emitConnectedEndpoints();
  }

  void _removeConnectedEndpoint(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _emitHealth(_healthTracker.markDisconnected(endpointId));
    _emitConnectedEndpoints();
  }

  void _emitConnectedEndpoints() {
    if (!_connectedController.isClosed) {
      _connectedController.add(Set.unmodifiable(_connectedEndpoints));
    }
  }

  void _emitHealth(MafiaConnectionHealth health) {
    if (!_connectionHealthController.isClosed) {
      _connectionHealthController.add(health);
    }
  }

  Future<void> _ensurePermissions() async {
    await _permissionService.ensureGranted();
  }
}
