/// P2P constants for Game One Nearby Connections sessions.
class P2pConstants {
  P2pConstants._();

  /// Must be unique across apps; aligned with Android applicationId.
  static const String serviceId = 'com.example.template.game_one';

  /// Max wait for handshake before repository times out (future use).
  static const Duration handshakeTimeout = Duration(seconds: 10);
}

/// JSON envelope `type` field values for P2P messages.
enum P2pMessageType {
  handshake('handshake'),
  game('game'),
  playerRoster('playerRoster'),
  playerLeft('playerLeft');

  const P2pMessageType(this.value);

  final String value;

  static P2pMessageType? fromString(String? value) {
    if (value == null) return null;
    for (final type in P2pMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
