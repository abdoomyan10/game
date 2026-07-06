import 'dart:async';

import '../constants/mafia_p2p_constants.dart';

/// Tracks per-player reconnect grace timers on the host.
class MafiaReconnectGraceManager {
  MafiaReconnectGraceManager({
    Duration gracePeriod = MafiaP2pConstants.reconnectGracePeriod,
    void Function(String playerId)? onExpired,
  })  : _gracePeriod = gracePeriod,
        _onExpired = onExpired;

  final Duration _gracePeriod;
  final void Function(String playerId)? _onExpired;
  final Map<String, Timer> _timers = {};
  final Map<String, DateTime> _deadlines = {};

  bool isGraceActive(String playerId) => _timers.containsKey(playerId);

  DateTime? deadlineFor(String playerId) => _deadlines[playerId];

  DateTime startGrace(String playerId) {
    cancelGrace(playerId);
    final deadline = DateTime.now().add(_gracePeriod);
    _deadlines[playerId] = deadline;
    _timers[playerId] = Timer(_gracePeriod, () {
      _timers.remove(playerId);
      _deadlines.remove(playerId);
      _onExpired?.call(playerId);
    });
    return deadline;
  }

  void cancelGrace(String playerId) {
    _timers.remove(playerId)?.cancel();
    _deadlines.remove(playerId);
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _deadlines.clear();
  }
}
