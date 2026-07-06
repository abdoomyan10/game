import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../constants/mafia_p2p_constants.dart';
import '../exceptions/mafia_p2p_exceptions.dart';
import '../models/mafia_connection_health.dart';
import '../models/mafia_phase_ack.dart';

/// Parsed plaintext control frame from a connected peer.
class MafiaControlPayload {
  const MafiaControlPayload({
    required this.type,
    this.pingId,
    this.sentAtMs,
    this.correlationId,
    this.playerId,
    this.sessionToken,
    this.deadlineMs,
    this.accepted,
  });

  final MafiaControlMessageType type;
  final String? pingId;
  final int? sentAtMs;
  final String? correlationId;
  final String? playerId;
  final String? sessionToken;
  final int? deadlineMs;
  final bool? accepted;
}

/// Builds and parses small JSON control frames for ping/pong/ack/phaseSync.
class MafiaP2pProtocol {
  MafiaP2pProtocol._();

  static Uint8List buildPing({required String pingId, required int sentAtMs}) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.ping.value,
          'pingId': pingId,
          'sentAtMs': sentAtMs,
        }),
      ),
    );
  }

  static Uint8List buildPong({
    required String pingId,
    required int sentAtMs,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.pong.value,
          'pingId': pingId,
          'sentAtMs': sentAtMs,
        }),
      ),
    );
  }

  static Uint8List buildAck({required String correlationId}) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.ack.value,
          'correlationId': correlationId,
        }),
      ),
    );
  }

  static Uint8List buildPhaseSync({required String correlationId}) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.phaseSync.value,
          'correlationId': correlationId,
        }),
      ),
    );
  }

  static Uint8List buildRejoin({
    required String playerId,
    required String sessionToken,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.rejoin.value,
          'playerId': playerId,
          'sessionToken': sessionToken,
        }),
      ),
    );
  }

  static Uint8List buildRejoinAck({
    required String playerId,
    required bool accepted,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.rejoinAck.value,
          'playerId': playerId,
          'accepted': accepted,
        }),
      ),
    );
  }

  static Uint8List buildSessionPaused({
    required String playerId,
    required int deadlineMs,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.sessionPaused.value,
          'playerId': playerId,
          'deadlineMs': deadlineMs,
        }),
      ),
    );
  }

  static Uint8List buildSessionResumed() {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.sessionResumed.value,
        }),
      ),
    );
  }

  static Uint8List buildPlayerEliminated({required String playerId}) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'type': MafiaControlMessageType.playerEliminated.value,
          'playerId': playerId,
        }),
      ),
    );
  }

  /// Returns null when [bytes] is not a recognized control frame.
  static MafiaControlPayload? tryParseControlPayload(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;

      final type =
          MafiaControlMessageType.fromString(decoded['type'] as String?);
      if (type == null) return null;

      return MafiaControlPayload(
        type: type,
        pingId: decoded['pingId'] as String?,
        sentAtMs: decoded['sentAtMs'] as int?,
        correlationId: decoded['correlationId'] as String?,
        playerId: decoded['playerId'] as String?,
        sessionToken: decoded['sessionToken'] as String?,
        deadlineMs: decoded['deadlineMs'] as int?,
        accepted: decoded['accepted'] as bool?,
      );
    } on Object {
      return null;
    }
  }
}

/// Host-side phase ACK tracking (unit-testable).
class MafiaAckCoordinator {
  final Map<String, Set<String>> _pendingAcks = {};
  final Map<String, Completer<void>> _completers = {};
  final Map<String, Timer> _timeouts = {};
  final Map<String, Set<String>> _earlyAcks = {};

  StreamController<MafiaPhaseAck>? _acksController;

  Stream<MafiaPhaseAck> get onAckReceived =>
      (_acksController ??= StreamController<MafiaPhaseAck>.broadcast()).stream;

  void registerExpectation({
    required String correlationId,
    required Set<String> endpointIds,
    required Duration timeout,
  }) {
    cancelExpectation(correlationId);
    final pending = Set<String>.from(endpointIds);
    final early = _earlyAcks.remove(correlationId);
    if (early != null) {
      pending.removeAll(early);
    }
    _pendingAcks[correlationId] = pending;
    final completer = Completer<void>();
    _completers[correlationId] = completer;

    if (pending.isEmpty) {
      completer.complete();
      return;
    }

    _timeouts[correlationId] = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          MafiaAckTimeoutException(
            correlationId: correlationId,
            missingEndpointIds: pendingFor(correlationId),
          ),
        );
      }
    });
  }

  Set<String> pendingFor(String correlationId) =>
      Set.unmodifiable(_pendingAcks[correlationId] ?? const {});

  bool recordAck({
    required String correlationId,
    required String endpointId,
    DateTime? receivedAt,
  }) {
    final pending = _pendingAcks[correlationId];
    if (pending == null) {
      _earlyAcks.putIfAbsent(correlationId, () => {}).add(endpointId);
      _acksController?.add(
        MafiaPhaseAck(
          correlationId: correlationId,
          endpointId: endpointId,
          receivedAt: receivedAt ?? DateTime.now(),
        ),
      );
      return true;
    }
    if (!pending.contains(endpointId)) return false;

    pending.remove(endpointId);
    _acksController?.add(
      MafiaPhaseAck(
        correlationId: correlationId,
        endpointId: endpointId,
        receivedAt: receivedAt ?? DateTime.now(),
      ),
    );

    if (pending.isEmpty) {
      _complete(correlationId);
    }
    return true;
  }

  Future<void> waitForAcks(String correlationId) {
    final completer = _completers[correlationId];
    if (completer == null) {
      throw StateError('No ACK expectation registered for $correlationId');
    }
    return completer.future;
  }

  void cancelExpectation(String correlationId) {
    _timeouts.remove(correlationId)?.cancel();
    _pendingAcks.remove(correlationId);
    _completers.remove(correlationId);
  }

  /// Removes [endpointId] from all pending ACK sets; completes when a set empties.
  void removeEndpointFromAllExpectations(String endpointId) {
    final correlationIds = _pendingAcks.keys.toList();
    for (final correlationId in correlationIds) {
      final pending = _pendingAcks[correlationId];
      if (pending == null || !pending.remove(endpointId)) continue;
      if (pending.isEmpty) {
        _complete(correlationId);
      }
    }
    for (final early in _earlyAcks.values) {
      early.remove(endpointId);
    }
  }

  void clear() {
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    _pendingAcks.clear();
    _completers.clear();
    _earlyAcks.clear();
  }

  void dispose() {
    clear();
    _acksController?.close();
    _acksController = null;
  }

  void _complete(String correlationId) {
    _timeouts.remove(correlationId)?.cancel();
    _pendingAcks.remove(correlationId);
    final completer = _completers.remove(correlationId);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

/// Tracks per-endpoint RTT, transfer failures, and staleness.
class MafiaConnectionHealthTracker {
  MafiaConnectionHealthTracker({
    required this.staleThreshold,
  });

  final Duration staleThreshold;
  final Map<String, MafiaConnectionHealth> _healthByEndpoint = {};
  final Map<String, int> _outstandingPingSentAt = {};

  Iterable<MafiaConnectionHealth> get all => _healthByEndpoint.values;

  MafiaConnectionHealth healthFor(String endpointId) {
    return _healthByEndpoint[endpointId] ??
        MafiaConnectionHealth(
          endpointId: endpointId,
          quality: MafiaConnectionQuality.disconnected,
        );
  }

  MafiaConnectionHealth markConnected(String endpointId) {
    final health = MafiaConnectionHealth(
      endpointId: endpointId,
      quality: MafiaConnectionQuality.healthy,
      roundTripMs: _healthByEndpoint[endpointId]?.roundTripMs,
      failedTransferCount:
          _healthByEndpoint[endpointId]?.failedTransferCount ?? 0,
      lastPayloadAt: DateTime.now(),
    );
    _healthByEndpoint[endpointId] = health;
    return health;
  }

  MafiaConnectionHealth markDisconnected(String endpointId) {
    final health = MafiaConnectionHealth(
      endpointId: endpointId,
      quality: MafiaConnectionQuality.disconnected,
      roundTripMs: _healthByEndpoint[endpointId]?.roundTripMs,
      failedTransferCount:
          _healthByEndpoint[endpointId]?.failedTransferCount ?? 0,
      lastPayloadAt: _healthByEndpoint[endpointId]?.lastPayloadAt,
    );
    _healthByEndpoint[endpointId] = health;
    _outstandingPingSentAt.remove(endpointId);
    return health;
  }

  MafiaConnectionHealth recordTransferFailure(String endpointId) {
    final current = healthFor(endpointId);
    final health = current.copyWith(
      quality: MafiaConnectionQuality.degraded,
      failedTransferCount: current.failedTransferCount + 1,
    );
    _healthByEndpoint[endpointId] = health;
    return health;
  }

  MafiaConnectionHealth recordPayloadSuccess(String endpointId) {
    final current = healthFor(endpointId);
    final health = current.copyWith(
      quality: current.failedTransferCount > 0
          ? MafiaConnectionQuality.degraded
          : MafiaConnectionQuality.healthy,
      lastPayloadAt: DateTime.now(),
    );
    _healthByEndpoint[endpointId] = health;
    return health;
  }

  void registerPing(String endpointId, int sentAtMs) {
    _outstandingPingSentAt[endpointId] = sentAtMs;
  }

  MafiaConnectionHealth? recordPong({
    required String endpointId,
    required int pongSentAtMs,
  }) {
    final pingSentAt = _outstandingPingSentAt.remove(endpointId);
    if (pingSentAt == null) return null;

    final rtt = pongSentAtMs - pingSentAt;
    if (rtt < 0) return null;

    final current = healthFor(endpointId);
    final health = current.copyWith(
      quality: current.failedTransferCount > 0
          ? MafiaConnectionQuality.degraded
          : MafiaConnectionQuality.healthy,
      roundTripMs: rtt,
      lastPayloadAt: DateTime.now(),
    );
    _healthByEndpoint[endpointId] = health;
    return health;
  }

  List<MafiaConnectionHealth> evaluateStale(DateTime now) {
    final stale = <MafiaConnectionHealth>[];
    for (final entry in _healthByEndpoint.entries) {
      final health = entry.value;
      if (health.quality == MafiaConnectionQuality.disconnected) continue;

      final lastSeen = health.lastPayloadAt;
      if (lastSeen == null) continue;
      if (now.difference(lastSeen) <= staleThreshold) continue;

      final degraded = health.copyWith(quality: MafiaConnectionQuality.degraded);
      _healthByEndpoint[entry.key] = degraded;
      stale.add(degraded);
    }
    return stale;
  }

  void clear() {
    _healthByEndpoint.clear();
    _outstandingPingSentAt.clear();
  }
}
