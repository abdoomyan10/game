import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failure.dart';
import '../../../game_one/data/exceptions/p2p_exceptions.dart';
import '../../../game_one/data/services/encryption_service.dart';
import '../../../game_one/data/services/p2p_permission_service.dart';
import '../../domain/entities/mafia_discovered_lobby.dart';
import '../../domain/entities/mafia_game_config.dart';
import '../../domain/entities/mafia_game_state.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_phase.dart';
import '../../domain/entities/mafia_player_entity.dart';
import '../../domain/entities/mafia_role.dart';
import '../../domain/entities/mafia_session_event.dart';
import '../../domain/logic/eliminate_player.dart';
import '../../domain/repositories/mafia_repository.dart';
import '../constants/mafia_p2p_constants.dart';
import '../datasources/mafia_network_datasource.dart';
import '../datasources/mafia_p2p_protocol.dart';
import '../exceptions/mafia_p2p_exceptions.dart';
import '../models/mafia_connection_health.dart';
import '../models/mafia_rejoin_request.dart';
import '../models/mafia_session_control.dart';
import '../services/mafia_reconnect_grace_manager.dart';

@LazySingleton(as: MafiaRepository)
class MafiaRepositoryImpl with HandlingMixin implements MafiaRepository {
  MafiaRepositoryImpl(
    this._network,
    this._encryption,
    this._permissionService,
  ) {
    _graceManager = MafiaReconnectGraceManager(onExpired: _onReconnectGraceExpired);
  }

  final MafiaNetworkDataSource _network;
  final EncryptionService _encryption;
  final P2pPermissionService _permissionService;

  late final MafiaReconnectGraceManager _graceManager;

  final _sessionEventsController =
      StreamController<MafiaSessionEvent>.broadcast();
  final _playersController = StreamController<List<MafiaLobbyPlayer>>.broadcast();
  final _discoveredLobbiesController =
      StreamController<MafiaDiscoveredLobby>.broadcast();
  final _canStartGameController = StreamController<bool>.broadcast();

  final List<MafiaLobbyPlayer> _players = [];
  final Map<String, String> _endpointToPlayerId = {};
  final Map<String, String> _playerIdToEndpoint = {};
  final Set<String> _handshakeSentTo = {};
  final Set<String> _lastConnected = {};
  final Set<String> _reconnectingPlayerIds = {};

  bool _isHost = false;
  String? _sessionKey;
  String? _sessionToken;
  String? _activeHostEndpointId;
  String? _localAssignedPlayerId;
  MafiaGameConfig? _activeGameConfig;
  bool _hostLossHandled = false;
  Timer? _hostLossDebounceTimer;
  String? _storedUserName;

  StreamSubscription<MafiaP2pPayload>? _payloadSubscription;
  StreamSubscription<MafiaP2pEndpoint>? _endpointFoundSubscription;
  StreamSubscription<Set<String>>? _connectedSubscription;
  StreamSubscription<String>? _endpointLostSubscription;
  StreamSubscription<String>? _endpointDisconnectedSubscription;
  StreamSubscription<MafiaRejoinRequest>? _rejoinSubscription;
  StreamSubscription<MafiaSessionControl>? _sessionControlSubscription;
  StreamSubscription<MafiaConnectionHealth>? _healthSubscription;

  @override
  bool get isHost => _isHost;

  @override
  String? get localPlayerId => _isHost ? 'local' : _localAssignedPlayerId;

  @override
  MafiaGameConfig? get activeGameConfig => _activeGameConfig;

  @override
  List<MafiaLobbyPlayer> get lobbyPlayers => List.unmodifiable(_players);

  @override
  Future<void> setActiveGameConfig(MafiaGameConfig? config) async {
    if (config == null) {
      _activeGameConfig = null;
      _emitCanStartGame();
      return;
    }

    if (!_isHost) {
      _activeGameConfig = config;
      return;
    }

    final wasInProgress = _activeGameConfig?.state == MafiaGameState.inProgress;
    _activeGameConfig = config;

    final delivered = await _broadcastGameConfigSync();
    final isInitialStart =
        !wasInProgress && config.state == MafiaGameState.inProgress;

    if (isInitialStart && delivered == 0 && _hasRemotePeers()) {
      unawaited(_retryGameConfigSyncBurst());
    }
  }

  Future<void> _retryGameConfigSyncBurst() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_activeGameConfig?.state != MafiaGameState.inProgress) return;

      final delivered = await _broadcastGameConfigSync();
      if (delivered > 0) return;
    }
  }

  @override
  Stream<MafiaSessionEvent> get sessionEvents => _sessionEventsController.stream;

  @override
  Stream<List<MafiaLobbyPlayer>> get players => _playersController.stream;

  @override
  Stream<MafiaDiscoveredLobby> get discoveredLobbies =>
      _discoveredLobbiesController.stream;

  @override
  bool get canStartGame => _computeCanStartGame();

  @override
  Stream<bool> get canStartGameUpdates => _canStartGameController.stream;

  @override
  Future<Either<Failure, void>> ensurePermissions() {
    return wrapHandling(tryCall: () => _permissionService.ensureGranted());
  }

  @override
  Future<Either<Failure, void>> startHosting(String userName) {
    return _wrapP2pHandling(tryCall: () async {
      await _resetSession();
      _isHost = true;
      _storedUserName = userName;
      _localAssignedPlayerId = 'local';

      _sessionKey = _encryption.generateSessionKey();
      _sessionToken = _sessionKey;
      _encryption.setSessionKey(_sessionKey!);

      _players
        ..clear()
        ..add(MafiaLobbyPlayer(id: 'local', name: userName, isHost: true));
      _emitPlayers();
      _emitCanStartGame();

      _listenToAllStreams();
      await _network.startHosting(userName: userName);
      _network.startHealthMonitoring();
    });
  }

  @override
  Future<Either<Failure, void>> scanForLobbies(String userName) {
    return _wrapP2pHandling(tryCall: () async {
      await _resetSession();
      _isHost = false;
      _storedUserName = userName;
      _activeHostEndpointId = null;
      _localAssignedPlayerId = 'local';

      _listenToAllStreams();
      await _network.startDiscovery(userName: userName);
    });
  }

  @override
  Future<Either<Failure, void>> joinLobby({
    required String endpointId,
    required String userName,
  }) {
    return _wrapP2pHandling(tryCall: () async {
      _activeHostEndpointId = endpointId;
      _storedUserName = userName;
      _localAssignedPlayerId = 'local';

      _listenToAllStreams();
      await _network.connectToHost(endpointId: endpointId);
      await _network.stopDiscovery();
      _localAssignedPlayerId = endpointId;

      _players
        ..clear()
        ..add(MafiaLobbyPlayer(id: 'local', name: userName, isHost: false));
      _emitPlayers();
      _network.startHealthMonitoring();
    });
  }

  @override
  Future<Either<Failure, void>> disconnect() {
    return _wrapP2pHandling(tryCall: () async {
      await _resetSession();
      await _network.disconnectAll();
    });
  }

  void _listenToAllStreams() {
    _listenToPayloads();
    _listenToEndpointFound();
    _listenToEndpointLost();
    _listenToConnectedEndpoints();
    _listenToEndpointDisconnected();
    _listenToRejoinRequests();
    _listenToSessionControl();
    _listenToHealth();
  }

  void _listenToPayloads() {
    _payloadSubscription ??= _network.onPayloadReceived.listen(
      _handleRawPayload,
      onError: (_) {},
    );
  }

  void _listenToEndpointFound() {
    _endpointFoundSubscription ??=
        _network.onEndpointFound.listen((endpoint) {
      _discoveredLobbiesController.add(
        MafiaDiscoveredLobby(
          endpointId: endpoint.id,
          hostName: endpoint.userName,
        ),
      );
    });
  }

  void _listenToEndpointLost() {
    _endpointLostSubscription ??= _network.onEndpointLost.listen((endpointId) {
      _sessionEventsController.add(HostAdvertiserLost(endpointId));
      if (!_isHost &&
          _activeHostEndpointId != null &&
          _activeHostEndpointId == endpointId) {
        _scheduleHostLossDetection();
      }
    });
  }

  void _listenToEndpointDisconnected() {
    _endpointDisconnectedSubscription ??=
        _network.onEndpointDisconnected.listen((endpointId) {
      if (!_isHost) {
        if (endpointId == _activeHostEndpointId) {
          _scheduleHostLossDetection();
        } else {
          unawaited(_attemptClientReconnect());
        }
        return;
      }

      final playerId = _endpointToPlayerId.remove(endpointId) ??
          _resolvePlayerId(endpointId);
      _playerIdToEndpoint.remove(playerId);

      if (!_isGameInProgress) {
        _removeGuestPlayer(playerId);
        return;
      }

      if (!isPlayerAlive(_activeGameConfig!, playerId)) return;
      if (_reconnectingPlayerIds.contains(playerId)) return;

      _beginPeerReconnect(playerId);
    });
  }

  void _listenToConnectedEndpoints() {
    _connectedSubscription ??=
        _network.connectedEndpoints.listen((endpointIds) async {
      if (_isHost) {
        for (final endpointId in endpointIds) {
          final alreadyHandshook = _handshakeSentTo.contains(endpointId);
          if (!alreadyHandshook) {
            _handshakeSentTo.add(endpointId);
            await _sendHandshake(endpointId);
          }

          final playerId = _endpointToPlayerId[endpointId];
          if (playerId == null) {
            _registerEndpoint(endpointId, endpointId);
            _addGuestPlayer(endpointId);
          } else if (!_players.any((player) => player.id == playerId)) {
            _addGuestPlayer(playerId);
          }
        }

        final removed = _lastConnected.difference(endpointIds);
        for (final endpointId in removed) {
          if (_isGameInProgress) continue;
          final playerId = _endpointToPlayerId[endpointId] ?? endpointId;
          _removeGuestPlayer(playerId);
        }

        _lastConnected
          ..clear()
          ..addAll(endpointIds);

        if (_players.length > 1 && !_isGameInProgress) {
          await _broadcastPlayerRoster();
        }

        _emitCanStartGame();
      } else {
        if (_lastConnected.isNotEmpty && endpointIds.isEmpty) {
          _scheduleHostLossDetection();
        }
        _lastConnected
          ..clear()
          ..addAll(endpointIds);
      }
    });
  }

  void _listenToRejoinRequests() {
    _rejoinSubscription ??= _network.onRejoinRequested.listen((request) {
      if (!_isHost) return;
      unawaited(_handleRejoinRequest(request));
    });
  }

  void _listenToSessionControl() {
    _sessionControlSubscription ??=
        _network.onSessionControl.listen((control) {
      if (_isHost) return;
      unawaited(_handleSessionControl(control));
    });
  }

  void _listenToHealth() {
    _healthSubscription ??= _network.connectionHealth.listen((health) {
      if (_isHost || _hostLossHandled) return;
      if (_activeHostEndpointId == null) return;
      if (health.endpointId != _activeHostEndpointId) return;
      if (health.quality == MafiaConnectionQuality.disconnected) {
        _scheduleHostLossDetection();
      }
    });
  }

  void _scheduleHostLossDetection() {
    if (_hostLossHandled) return;
    _hostLossDebounceTimer?.cancel();
    _hostLossDebounceTimer = Timer(
      MafiaP2pConstants.hostLossDetectionDebounce,
      () {
        if (_hostLossHandled) return;
        unawaited(_handleHostDisconnected());
      },
    );
  }

  Future<void> _handleHostDisconnected() async {
    if (_hostLossHandled || _sessionEventsController.isClosed) return;
    _hostLossHandled = true;
    _sessionEventsController.add(const HostDisconnected());
    await _resetSession();
    await _network.disconnectAll();
  }

  void _beginPeerReconnect(String playerId) {
    _reconnectingPlayerIds.add(playerId);
    _sessionEventsController.add(PeerDisconnected(playerId));

    final deadline = _graceManager.startGrace(playerId);
    _sessionEventsController.add(PeerReconnecting(playerId, deadline));
    _sessionEventsController.add(
      SessionPaused('reconnecting:$playerId'),
    );

    unawaited(_broadcastSessionPaused(playerId: playerId, deadline: deadline));
  }

  Future<void> _handleRejoinRequest(MafiaRejoinRequest request) async {
    if (!_isHost || _sessionToken == null) return;

    final playerId = request.playerId;
    if (request.sessionToken != _sessionToken) {
      await _sendRejoinAck(
        endpointId: request.endpointId,
        playerId: playerId,
        accepted: false,
      );
      return;
    }

    if (!_reconnectingPlayerIds.contains(playerId) &&
        !_players.any((p) => p.id == playerId)) {
      await _sendRejoinAck(
        endpointId: request.endpointId,
        playerId: playerId,
        accepted: false,
      );
      return;
    }

    _registerEndpoint(request.endpointId, playerId);
    _handshakeSentTo.add(request.endpointId);
    await _sendHandshake(request.endpointId);
    await _sendRejoinAck(
      endpointId: request.endpointId,
      playerId: playerId,
      accepted: true,
    );

    _graceManager.cancelGrace(playerId);
    _reconnectingPlayerIds.remove(playerId);
    _sessionEventsController.add(PeerReconnected(playerId));
    _sessionEventsController.add(const SessionResumed());
    await _broadcastSessionResumed();

    if (_activeGameConfig != null) {
      await _broadcastGameConfigSync();
    }
  }

  void _onReconnectGraceExpired(String playerId) {
    if (!_isHost || _activeGameConfig == null) return;
    if (!_reconnectingPlayerIds.remove(playerId)) return;
    if (!isPlayerAlive(_activeGameConfig!, playerId)) return;

    _activeGameConfig = eliminatePlayer(_activeGameConfig!, playerId);
    _sessionEventsController.add(PeerEliminated(playerId));
    _sessionEventsController.add(const SessionResumed());

    unawaited(_broadcastPlayerEliminated(playerId));
    unawaited(_broadcastGameConfigSync());
    unawaited(_broadcastSessionResumed());
  }

  Future<void> _handleSessionControl(MafiaSessionControl control) async {
    switch (control.type) {
      case MafiaSessionControlType.sessionPaused:
        final playerId = control.playerId;
        final deadlineMs = control.deadlineMs;
        if (playerId == null || deadlineMs == null) return;
        _sessionEventsController.add(
          PeerReconnecting(playerId, DateTime.fromMillisecondsSinceEpoch(deadlineMs)),
        );
        _sessionEventsController.add(
          SessionPaused('reconnecting:$playerId'),
        );
      case MafiaSessionControlType.sessionResumed:
        _sessionEventsController.add(const SessionResumed());
      case MafiaSessionControlType.playerEliminated:
        final playerId = control.playerId;
        if (playerId == null || _activeGameConfig == null) return;
        _activeGameConfig = eliminatePlayer(_activeGameConfig!, playerId);
        _sessionEventsController.add(PeerEliminated(playerId));
      case MafiaSessionControlType.rejoinAck:
        if (control.accepted == true) {
          final playerId = control.playerId;
          if (playerId != null) {
            _sessionEventsController.add(PeerReconnected(playerId));
            _sessionEventsController.add(const SessionResumed());
          }
        }
    }
  }

  Future<void> _attemptClientReconnect() async {
    if (_isHost || _hostLossHandled) return;
    if (_storedUserName == null || _sessionToken == null) return;
    if (_localAssignedPlayerId == null) return;

    try {
      await _network.startDiscovery(userName: _storedUserName!);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (_activeHostEndpointId != null) {
        await _network.connectToHost(endpointId: _activeHostEndpointId!);
        await _network.sendRejoin(
          hostEndpointId: _activeHostEndpointId!,
          playerId: _localAssignedPlayerId!,
          sessionToken: _sessionToken!,
        );
      }
    } on Object {
      // Retry is best-effort; host-loss path handles permanent failure.
    }
  }

  bool get _isGameInProgress =>
      _activeGameConfig?.state == MafiaGameState.inProgress;

  void _registerEndpoint(String endpointId, String playerId) {
    _endpointToPlayerId[endpointId] = playerId;
    _playerIdToEndpoint[playerId] = endpointId;
  }

  String _resolvePlayerId(String endpointId) =>
      _endpointToPlayerId[endpointId] ?? endpointId;

  Future<void> _sendHandshake(String endpointId) async {
    if (_sessionKey == null || _sessionToken == null) return;

    final handshake = jsonEncode({
      'type': MafiaP2pMessageType.handshake.value,
      'sessionKey': _sessionKey,
      'sessionToken': _sessionToken,
    });

    await _network.sendIsolatedPayload(
      endpointId: endpointId,
      data: Uint8List.fromList(utf8.encode(handshake)),
    );
  }

  Future<void> _sendRejoinAck({
    required String endpointId,
    required String playerId,
    required bool accepted,
  }) async {
    await _network.sendIsolatedPayload(
      endpointId: endpointId,
      data: MafiaP2pProtocol.buildRejoinAck(
        playerId: playerId,
        accepted: accepted,
      ),
    );
  }

  Future<void> _broadcastToConnected(Uint8List frame) async {
    for (final endpointId in _playerIdToEndpoint.values) {
      try {
        await _network.sendIsolatedPayload(endpointId: endpointId, data: frame);
      } on MafiaTransportException {
        // Skip unreachable peers.
      }
    }
  }

  Future<void> _broadcastSessionPaused({
    required String playerId,
    required DateTime deadline,
  }) async {
    await _broadcastToConnected(
      MafiaP2pProtocol.buildSessionPaused(
        playerId: playerId,
        deadlineMs: deadline.millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _broadcastSessionResumed() async {
    await _broadcastToConnected(MafiaP2pProtocol.buildSessionResumed());
  }

  Future<void> _broadcastPlayerEliminated(String playerId) async {
    await _broadcastToConnected(
      MafiaP2pProtocol.buildPlayerEliminated(playerId: playerId),
    );
  }

  Future<void> _broadcastPlayerRoster() async {
    if (!_isHost || !_encryption.hasSessionKey) return;

    final roster = jsonEncode({
      'type': MafiaP2pMessageType.playerRoster.value,
      'players': _players
          .map(
            (player) => {
              'id': player.id,
              'name': player.name,
              'isHost': player.isHost,
            },
          )
          .toList(),
    });
    final wire = _encryption.encryptData(roster);
    await _broadcastEncrypted(wire);
  }

  Future<int> _broadcastGameConfigSync() async {
    if (!_isHost || !_encryption.hasSessionKey || _activeGameConfig == null) {
      return 0;
    }

    final message = jsonEncode({
      'type': MafiaP2pMessageType.gameConfigSync.value,
      'config': _encodeGameConfig(_activeGameConfig!),
    });
    final wire = _encryption.encryptData(message);
    return _broadcastEncrypted(wire);
  }

  Future<int> _broadcastEncrypted(String wire) async {
    final data = Uint8List.fromList(utf8.encode(wire));
    var delivered = 0;
    for (final endpointId in _broadcastTargets()) {
      try {
        await _network.sendIsolatedPayload(endpointId: endpointId, data: data);
        delivered++;
      } on MafiaTransportException {
        // Skip unreachable peers.
      }
    }
    return delivered;
  }

  Set<String> _broadcastTargets() {
    if (_isHost) {
      if (_lastConnected.isNotEmpty) return _lastConnected;
      return _playerIdToEndpoint.values.toSet();
    }
    return _playerIdToEndpoint.values.toSet();
  }

  bool _hasRemotePeers() {
    return _lastConnected.isNotEmpty || _playerIdToEndpoint.isNotEmpty;
  }

  Map<String, dynamic> _encodeGameConfig(MafiaGameConfig config) {
    return {
      'state': config.state.name,
      'phase': config.phase.name,
      'players': config.players
          .map(
            (player) => {
              'id': player.id,
              'name': player.name,
              'isHost': player.isHost,
              'role': player.role.name,
              'isAlive': player.isAlive,
              'isSilenced': player.isSilenced,
            },
          )
          .toList(),
    };
  }

  MafiaGameConfig? _decodeGameConfig(Map<String, dynamic> map) {
    try {
      final playersJson = map['players'] as List<dynamic>?;
      if (playersJson == null) return null;

      final players = playersJson.map((json) {
        final playerMap = json as Map<String, dynamic>;
        return MafiaPlayerEntity(
          id: playerMap['id'] as String,
          name: playerMap['name'] as String,
          isHost: playerMap['isHost'] as bool,
          role: MafiaRole.values.byName(playerMap['role'] as String),
          isAlive: playerMap['isAlive'] as bool,
          isSilenced: playerMap['isSilenced'] as bool,
        );
      }).toList();

      return MafiaGameConfig(
        state: MafiaGameState.values.byName(map['state'] as String),
        phase: MafiaPhase.values.byName(map['phase'] as String),
        players: players,
      );
    } on Object {
      return null;
    }
  }

  void _handleRawPayload(MafiaP2pPayload payload) {
    try {
      final raw = utf8.decode(payload.bytes);
      if (_tryHandleHandshake(raw, payload.endpointId)) return;
      if (_tryHandleControlMessage(raw)) return;

      if (!_encryption.hasSessionKey) return;

      final decrypted = _encryption.decryptData(raw);
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      final type = MafiaP2pMessageType.fromString(map['type'] as String?);

      if (type == MafiaP2pMessageType.gameConfigSync) {
        final configMap = map['config'] as Map<String, dynamic>?;
        if (configMap != null) {
          final config = _decodeGameConfig(configMap);
          if (config != null) {
            _activeGameConfig = config;
            if (!_isHost) {
              _sessionEventsController.add(GameStarted(config));
            }
          }
        }
        return;
      }

      if (type == MafiaP2pMessageType.playerRoster) {
        _applyRosterFromHost(map);
      }
    } on EncryptionException {
      // Ignore malformed payloads during lobby setup.
    } catch (_) {
      // Ignore non-game payloads.
    }
  }

  bool _tryHandleHandshake(String raw, String endpointId) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (MafiaP2pMessageType.fromString(map['type'] as String?) !=
          MafiaP2pMessageType.handshake) {
        return false;
      }

      final sessionKey = map['sessionKey'] as String?;
      final sessionToken = map['sessionToken'] as String?;
      if (sessionKey == null || sessionKey.isEmpty) return false;

      _sessionKey = sessionKey;
      _sessionToken = sessionToken ?? sessionKey;
      _encryption.setSessionKey(sessionKey);
      _registerEndpoint(endpointId, _isHost ? endpointId : (_localAssignedPlayerId ?? endpointId));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _tryHandleControlMessage(String raw) {
    try {
      if (!_encryption.hasSessionKey) return false;

      final decrypted = _encryption.decryptData(raw);
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      final type = MafiaP2pMessageType.fromString(map['type'] as String?);

      if (type == MafiaP2pMessageType.playerLeft) {
        final playerId = map['playerId'] as String?;
        if (playerId != null) {
          _removeRemotePlayer(playerId);
        }
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  void _applyRosterFromHost(Map<String, dynamic> map) {
    final playersJson = map['players'] as List<dynamic>?;
    if (playersJson == null) return;

    final localPlayer = _players.where((p) => p.id == 'local').toList();
    final remotePlayers = playersJson
        .map((json) {
          final playerMap = json as Map<String, dynamic>;
          return MafiaLobbyPlayer(
            id: playerMap['id'] as String,
            name: playerMap['name'] as String,
            isHost: playerMap['isHost'] as bool,
          );
        })
        .where((player) => player.id != 'local')
        .toList();

    _players
      ..clear()
      ..addAll(localPlayer)
      ..addAll(remotePlayers);

    _emitPlayers();
    _sessionEventsController.add(RosterUpdated(List.unmodifiable(_players)));
  }

  void _addGuestPlayer(String playerId) {
    final exists = _players.any((player) => player.id == playerId);
    if (exists) return;

    _players.add(
      MafiaLobbyPlayer(
        id: playerId,
        name: 'لاعب ${playerId.length >= 4 ? playerId.substring(0, 4) : playerId}',
        isHost: false,
      ),
    );
    _emitPlayers();
  }

  void _removeGuestPlayer(String playerId) {
    if (playerId == 'local') return;

    final exists = _players.any((player) => player.id == playerId);
    if (!exists) return;

    _players.removeWhere((player) => player.id == playerId);
    _handshakeSentTo.remove(_playerIdToEndpoint[playerId]);
    _playerIdToEndpoint.remove(playerId);
    _emitPlayers();
    _sessionEventsController.add(PeerDisconnected(playerId));
    _emitCanStartGame();
  }

  void _removeRemotePlayer(String playerId) {
    if (playerId == 'local') return;

    final exists = _players.any((player) => player.id == playerId);
    if (!exists) return;

    _players.removeWhere((player) => player.id == playerId);
    _emitPlayers();
    _sessionEventsController.add(PeerDisconnected(playerId));
  }

  void _emitPlayers() {
    if (!_playersController.isClosed) {
      _playersController.add(List.unmodifiable(_players));
    }
  }

  bool _computeCanStartGame() {
    if (!_isHost || _isGameInProgress) return false;
    if (_players.length < MafiaP2pConstants.minPlayersToStart) return false;
    if (_lastConnected.isEmpty) return false;

    final remotePlayerCount =
        _players.where((player) => !player.isHost).length;
    return remotePlayerCount > 0;
  }

  void _emitCanStartGame() {
    if (!_canStartGameController.isClosed) {
      _canStartGameController.add(_computeCanStartGame());
    }
  }

  Future<void> _resetSession() async {
    _hostLossDebounceTimer?.cancel();
    _hostLossDebounceTimer = null;
    _graceManager.clear();

    await _payloadSubscription?.cancel();
    await _endpointFoundSubscription?.cancel();
    await _connectedSubscription?.cancel();
    await _endpointLostSubscription?.cancel();
    await _endpointDisconnectedSubscription?.cancel();
    await _rejoinSubscription?.cancel();
    await _sessionControlSubscription?.cancel();
    await _healthSubscription?.cancel();

    _payloadSubscription = null;
    _endpointFoundSubscription = null;
    _connectedSubscription = null;
    _endpointLostSubscription = null;
    _endpointDisconnectedSubscription = null;
    _rejoinSubscription = null;
    _sessionControlSubscription = null;
    _healthSubscription = null;

    _players.clear();
    _handshakeSentTo.clear();
    _lastConnected.clear();
    _endpointToPlayerId.clear();
    _playerIdToEndpoint.clear();
    _reconnectingPlayerIds.clear();

    _isHost = false;
    _sessionKey = null;
    _sessionToken = null;
    _activeHostEndpointId = null;
    _localAssignedPlayerId = null;
    _activeGameConfig = null;
    _hostLossHandled = false;
    _storedUserName = null;
    _encryption.clearSessionKey();

    _emitPlayers();
    _emitCanStartGame();
  }

  Future<Either<Failure, T>> _wrapP2pHandling<T>({
    required Future<T> Function() tryCall,
  }) async {
    try {
      final result = await tryCall();
      return Right(result);
    } on P2pPermissionException catch (error) {
      return Left(
        PermissionFailure(
          message: error.message,
          deniedPermissions: error.denied,
        ),
      );
    } on P2pTransportException catch (error) {
      return Left(
        P2pFailure(message: error.message, reason: error.reason),
      );
    } on MafiaTransportException catch (error) {
      return Left(
        P2pFailure(message: error.message, reason: error.reason),
      );
    } on EncryptionException catch (error) {
      return Left(ServerFailure(message: error.message));
    } catch (error) {
      return Left(ErrorHandler.handle(error));
    }
  }
}
