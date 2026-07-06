import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/discovered_room.dart';
import '../../domain/entities/game_payload.dart';
import '../../domain/entities/game_session_event.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/game_repository.dart';
import '../constants/p2p_constants.dart';
import '../datasources/network_datasource.dart';
import '../exceptions/p2p_exceptions.dart';
import '../models/game_payload_model.dart';
import '../models/player_model.dart';
import '../services/encryption_service.dart';
import '../services/p2p_permission_service.dart';

@LazySingleton(as: GameRepository)
class GameRepositoryImpl with HandlingMixin implements GameRepository {
  GameRepositoryImpl(
    this._network,
    this._encryption,
    this._permissionService,
  );

  final NetworkDataSource _network;
  final EncryptionService _encryption;
  final P2pPermissionService _permissionService;

  final _discoveredRoomsController =
      StreamController<DiscoveredRoom>.broadcast();
  final _playersController = StreamController<List<Player>>.broadcast();
  final _incomingPayloadsController =
      StreamController<GamePayload>.broadcast();
  final _connectedEndpointIdsController =
      StreamController<Set<String>>.broadcast();
  final _sessionEventsController =
      StreamController<GameSessionEvent>.broadcast();

  final List<Player> _players = [];
  final Set<String> _handshakeSentTo = {};
  final Set<String> _lastConnected = {};

  bool _isHost = false;
  String? _sessionKey;
  String? _activeHostEndpointId;

  StreamSubscription<P2pPayload>? _payloadSubscription;
  StreamSubscription<P2pEndpoint>? _endpointFoundSubscription;
  StreamSubscription<Set<String>>? _connectedSubscription;
  StreamSubscription<String>? _endpointLostSubscription;

  @override
  bool get isHost => _isHost;

  @override
  Stream<DiscoveredRoom> get discoveredRooms =>
      _discoveredRoomsController.stream;

  @override
  Stream<List<Player>> get players => _playersController.stream;

  @override
  Stream<GamePayload> get incomingPayloads =>
      _incomingPayloadsController.stream;

  @override
  Stream<Set<String>> get connectedEndpointIds =>
      _connectedEndpointIdsController.stream;

  @override
  Stream<GameSessionEvent> get sessionEvents =>
      _sessionEventsController.stream;

  @override
  Future<Either<Failure, void>> ensurePermissions() {
    return wrapHandling(tryCall: () => _permissionService.ensureGranted());
  }

  @override
  Future<Either<Failure, void>> startHosting(String userName) {
    return wrapHandling(tryCall: () async {
      await _resetSession();
      _isHost = true;

      _sessionKey = _encryption.generateSessionKey();
      _encryption.setSessionKey(_sessionKey!);

      _players
        ..clear()
        ..add(Player(id: 'local', name: userName, isHost: true));
      _emitPlayers();

      _listenToPayloads();
      _listenToConnectedEndpoints();
      _listenToEndpointLost();

      await _network.startHosting(userName: userName);
    });
  }

  @override
  Future<Either<Failure, void>> scanForRooms(String userName) {
    return wrapHandling(tryCall: () async {
      await _resetSession();
      _isHost = false;
      _activeHostEndpointId = null;

      _listenToPayloads();
      _listenToEndpointFound();
      _listenToEndpointLost();

      await _network.startDiscovery(userName: userName);
    });
  }

  @override
  Future<Either<Failure, void>> joinRoom({
    required String endpointId,
    required String userName,
  }) {
    return wrapHandling(tryCall: () async {
      _activeHostEndpointId = endpointId;
      _listenToPayloads();
      _listenToConnectedEndpoints();
      _listenToEndpointLost();

      await _network.connectToHost(endpointId: endpointId);

      _players
        ..clear()
        ..add(Player(id: 'local', name: userName, isHost: false));
      _emitPlayers();
    });
  }

  @override
  Future<Either<Failure, void>> sendGamePayload({
    required GamePayload payload,
    required String endpointId,
  }) {
    return wrapHandling(tryCall: () async {
      if (!_encryption.hasSessionKey) {
        throw const EncryptionException('Session key is not set');
      }

      final json = jsonEncode(GamePayloadModel.fromEntity(payload).toJson());
      final wire = _encryption.encryptData(json);

      await _network.sendPayload(
        endpointId: endpointId,
        data: Uint8List.fromList(utf8.encode(wire)),
      );
    });
  }

  @override
  Future<Either<Failure, void>> disconnect() {
    return wrapHandling(tryCall: () async {
      await _resetSession();
      await _network.disconnectAll();
    });
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
      _discoveredRoomsController.add(
        DiscoveredRoom(id: endpoint.id, hostName: endpoint.userName),
      );
    });
  }

  void _listenToEndpointLost() {
    _endpointLostSubscription ??= _network.onEndpointLost.listen((endpointId) {
      _sessionEventsController.add(EndpointLost(endpointId));

      if (!_isHost &&
          _activeHostEndpointId != null &&
          _activeHostEndpointId == endpointId) {
        unawaited(_handleHostDisconnected());
      }
    });
  }

  void _listenToConnectedEndpoints() {
    _connectedSubscription ??=
        _network.connectedEndpoints.listen((endpointIds) async {
      _connectedEndpointIdsController.add(Set.unmodifiable(endpointIds));

      if (_isHost) {
        for (final endpointId in endpointIds) {
          if (_handshakeSentTo.contains(endpointId)) continue;

          _handshakeSentTo.add(endpointId);
          await _sendHandshake(endpointId);
          _addGuestPlayer(endpointId);
        }

        final removed = _lastConnected.difference(endpointIds);
        for (final endpointId in removed) {
          _removeGuestPlayer(endpointId);
          await _broadcastPlayerLeft(endpointId);
        }

        _lastConnected
          ..clear()
          ..addAll(endpointIds);

        if (_players.length > 1) {
          await _broadcastPlayerRoster();
        }
      } else {
        if (_lastConnected.isNotEmpty && endpointIds.isEmpty) {
          await _handleHostDisconnected();
        }
        _lastConnected
          ..clear()
          ..addAll(endpointIds);
      }
    });
  }

  Future<void> _handleHostDisconnected() async {
    if (_sessionEventsController.isClosed) return;

    _sessionEventsController.add(const HostDisconnected());
    await _resetSession();
    await _network.disconnectAll();
  }

  Future<void> _sendHandshake(String endpointId) async {
    if (_sessionKey == null) return;

    final handshake = jsonEncode({
      'type': P2pMessageType.handshake.value,
      'sessionKey': _sessionKey,
    });

    await _network.sendPayload(
      endpointId: endpointId,
      data: Uint8List.fromList(utf8.encode(handshake)),
    );
  }

  Future<void> _broadcastPlayerRoster() async {
    if (!_isHost || !_encryption.hasSessionKey) return;

    final roster = jsonEncode({
      'type': P2pMessageType.playerRoster.value,
      'players': _players.map((p) => PlayerModel.fromEntity(p).toJson()).toList(),
    });
    final wire = _encryption.encryptData(roster);

    for (final player in _players) {
      if (player.id == 'local') continue;
      await _network.sendPayload(
        endpointId: player.id,
        data: Uint8List.fromList(utf8.encode(wire)),
      );
    }
  }

  Future<void> _broadcastPlayerLeft(String endpointId) async {
    if (!_isHost || !_encryption.hasSessionKey) return;

    final message = jsonEncode({
      'type': P2pMessageType.playerLeft.value,
      'endpointId': endpointId,
    });
    final wire = _encryption.encryptData(message);

    for (final player in _players) {
      if (player.id == 'local' || player.id == endpointId) continue;
      await _network.sendPayload(
        endpointId: player.id,
        data: Uint8List.fromList(utf8.encode(wire)),
      );
    }

    await _broadcastPlayerRoster();
  }

  void _handleRawPayload(P2pPayload payload) {
    try {
      final raw = utf8.decode(payload.bytes);

      if (_tryHandleHandshake(raw)) return;
      if (_tryHandleControlMessage(raw)) return;

      if (!_encryption.hasSessionKey) return;

      final decrypted = _encryption.decryptData(raw);
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      final gamePayload = GamePayloadModel.fromJson(map).toEntity();

      _incomingPayloadsController.add(gamePayload);
    } on EncryptionException {
      // Ignore malformed payloads during lobby setup.
    } catch (_) {
      // Ignore non-game payloads.
    }
  }

  bool _tryHandleHandshake(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (P2pMessageType.fromString(map['type'] as String?) !=
          P2pMessageType.handshake) {
        return false;
      }

      final sessionKey = map['sessionKey'] as String?;
      if (sessionKey == null || sessionKey.isEmpty) return false;

      _sessionKey = sessionKey;
      _encryption.setSessionKey(sessionKey);
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
      final type = P2pMessageType.fromString(map['type'] as String?);

      if (type == P2pMessageType.playerRoster) {
        _applyRosterFromHost(map);
        return true;
      }

      if (type == P2pMessageType.playerLeft) {
        final endpointId = map['endpointId'] as String?;
        if (endpointId != null) {
          _removeRemotePlayer(endpointId);
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
        .map((json) => PlayerModel.fromJson(json as Map<String, dynamic>))
        .map((model) => model.toEntity())
        .where((player) => player.id != 'local')
        .toList();

    _players
      ..clear()
      ..addAll(localPlayer)
      ..addAll(remotePlayers);

    _emitPlayers();
    _sessionEventsController.add(RosterUpdated(List.unmodifiable(_players)));
  }

  void _addGuestPlayer(String endpointId) {
    final exists = _players.any((player) => player.id == endpointId);
    if (exists) return;

    _players.add(
      Player(
        id: endpointId,
        name: 'لاعب ${endpointId.length >= 4 ? endpointId.substring(0, 4) : endpointId}',
        isHost: false,
      ),
    );
    _emitPlayers();
  }

  void _removeGuestPlayer(String endpointId) {
    if (endpointId == 'local') return;

    final removed = _players.any((player) => player.id == endpointId);
    if (!removed) return;

    _players.removeWhere((player) => player.id == endpointId);
    _handshakeSentTo.remove(endpointId);
    _emitPlayers();
    _sessionEventsController.add(ClientDisconnected(endpointId));
  }

  void _removeRemotePlayer(String endpointId) {
    if (endpointId == 'local') return;

    final exists = _players.any((player) => player.id == endpointId);
    if (!exists) return;

    _players.removeWhere((player) => player.id == endpointId);
    _emitPlayers();
    _sessionEventsController.add(ClientDisconnected(endpointId));
  }

  void _emitPlayers() {
    if (!_playersController.isClosed) {
      _playersController.add(List.unmodifiable(_players));
    }
  }

  Future<void> _resetSession() async {
    await _payloadSubscription?.cancel();
    await _endpointFoundSubscription?.cancel();
    await _connectedSubscription?.cancel();
    await _endpointLostSubscription?.cancel();

    _payloadSubscription = null;
    _endpointFoundSubscription = null;
    _connectedSubscription = null;
    _endpointLostSubscription = null;

    _players.clear();
    _handshakeSentTo.clear();
    _lastConnected.clear();
    _isHost = false;
    _sessionKey = null;
    _activeHostEndpointId = null;
    _encryption.clearSessionKey();

    _emitPlayers();
    _connectedEndpointIdsController.add({});
  }

  @override
  Future<Either<Failure, T>> wrapHandling<T>({
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
    } on EncryptionException catch (error) {
      return Left(ServerFailure(message: error.message));
    } catch (error) {
      return Left(ErrorHandler.handle(error));
    }
  }
}
