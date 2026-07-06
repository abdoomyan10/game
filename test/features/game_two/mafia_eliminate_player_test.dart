import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_player_entity.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/logic/eliminate_player.dart';

void main() {
  final config = MafiaGameConfig(
    state: MafiaGameState.inProgress,
    phase: MafiaPhase.day,
    players: const [
      MafiaPlayerEntity(
        id: 'a',
        name: 'A',
        isHost: true,
        role: MafiaRole.citizen,
        isAlive: true,
        isSilenced: false,
      ),
      MafiaPlayerEntity(
        id: 'b',
        name: 'B',
        isHost: false,
        role: MafiaRole.citizen,
        isAlive: true,
        isSilenced: false,
      ),
    ],
  );

  test('eliminatePlayer sets isAlive to false', () {
    final updated = eliminatePlayer(config, 'b');
    final player = updated.players.firstWhere((p) => p.id == 'b');
    expect(player.isAlive, isFalse);
    expect(updated.players.length, 2);
  });

  test('eliminatePlayer is idempotent for dead player', () {
    final once = eliminatePlayer(config, 'b');
    final twice = eliminatePlayer(once, 'b');
    expect(twice, once);
  });
}
