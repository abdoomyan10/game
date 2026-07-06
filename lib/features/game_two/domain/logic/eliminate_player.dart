import '../entities/mafia_game_config.dart';

/// Marks [playerId] as dead in the game config without removing them from roster.
MafiaGameConfig eliminatePlayer(MafiaGameConfig config, String playerId) {
  var changed = false;
  final players = config.players.map((player) {
    if (player.id != playerId || !player.isAlive) {
      return player;
    }
    changed = true;
    return player.copyWith(isAlive: false);
  }).toList();

  if (!changed) return config;
  return config.copyWith(players: players);
}

/// Returns true when [playerId] refers to a living player in [config].
bool isPlayerAlive(MafiaGameConfig config, String playerId) {
  return config.players.any(
    (player) => player.id == playerId && player.isAlive,
  );
}
