import 'dart:math';

import '../entities/mafia_lobby_player.dart';
import '../entities/mafia_player_entity.dart';
import '../entities/mafia_role.dart';

/// Assigns [MafiaRole] values to lobby players using secure randomization.
///
/// - Fewer than 7 players: 1 Boss, 1 Detective, 1 Doctor, rest Citizens.
/// - 7 or more players: 1 Boss, 1 Silencer, 1 Detective, 1 Doctor, 1 Sniper,
///   rest Citizens.
List<MafiaPlayerEntity> distributeMafiaRoles(List<MafiaLobbyPlayer> players) {
  if (players.isEmpty) {
    throw ArgumentError('Cannot distribute roles to an empty roster');
  }

  if (players.length < 3) {
    throw ArgumentError(
      'At least 3 players are required (Mafia Boss, Detective, Doctor)',
    );
  }

  final ids = players.map((player) => player.id);
  if (ids.length != ids.toSet().length) {
    throw ArgumentError('Duplicate player ids in roster');
  }

  final rolePool = _buildRolePool(players.length);
  final shuffledPlayers = List<MafiaLobbyPlayer>.from(players)
    ..shuffle(Random.secure());
  final shuffledRoles = List<MafiaRole>.from(rolePool)..shuffle(Random.secure());

  assert(shuffledPlayers.length == shuffledRoles.length);

  final result = <MafiaPlayerEntity>[];
  for (var i = 0; i < shuffledPlayers.length; i++) {
    final player = shuffledPlayers[i];
    result.add(
      MafiaPlayerEntity(
        id: player.id,
        name: player.name,
        isHost: player.isHost,
        role: shuffledRoles[i],
        isAlive: true,
        isSilenced: false,
      ),
    );
  }

  assert(result.length == players.length);
  assert(
    _roleMultiset(result.map((player) => player.role).toList()) ==
        _roleMultiset(rolePool),
  );
  assert(
    result.map((player) => player.id).toSet().length == players.length,
  );

  return result;
}

List<MafiaRole> _buildRolePool(int playerCount) {
  if (playerCount < 7) {
    return [
      MafiaRole.mafiaBoss,
      MafiaRole.detective,
      MafiaRole.doctor,
      ...List.filled(playerCount - 3, MafiaRole.citizen),
    ];
  }

  return [
    MafiaRole.mafiaBoss,
    MafiaRole.silencerMafia,
    MafiaRole.detective,
    MafiaRole.doctor,
    MafiaRole.sniper,
    ...List.filled(playerCount - 5, MafiaRole.citizen),
  ];
}

Map<MafiaRole, int> _roleMultiset(List<MafiaRole> roles) {
  final counts = <MafiaRole, int>{};
  for (final role in roles) {
    counts[role] = (counts[role] ?? 0) + 1;
  }
  return counts;
}
