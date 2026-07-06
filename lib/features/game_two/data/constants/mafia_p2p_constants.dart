/// P2P constants for Mafia (Game Two) Nearby Connections sessions.
class MafiaP2pConstants {
  MafiaP2pConstants._();

  /// Distinct from game_one so sessions do not cross-discover.
  static const String serviceId = 'com.example.alfark_game.game_two';

  /// Max wait for all clients to ACK a phase sync before host times out.
  static const Duration phaseAckTimeout = Duration(seconds: 8);

  /// Interval between connection health pings while monitoring is active.
  static const Duration healthPingInterval = Duration(seconds: 4);

  /// No ping/pong or payload within this window marks a peer as degraded.
  static const Duration healthStaleThreshold = Duration(seconds: 12);
}

/// Plaintext JSON control-frame `type` values (ping/pong/ack/phaseSync).
///
/// Game payloads (roles, roster, encrypted state) are sent as opaque bytes by
/// the repository layer after encryption.
enum MafiaControlMessageType {
  ping('ping'),
  pong('pong'),
  ack('ack'),
  phaseSync('phaseSync');

  const MafiaControlMessageType(this.value);

  final String value;

  static MafiaControlMessageType? fromString(String? value) {
    if (value == null) return null;
    for (final type in MafiaControlMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
