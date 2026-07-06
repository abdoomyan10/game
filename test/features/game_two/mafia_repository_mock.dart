import 'package:dartz/dartz.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/features/game_two/domain/entities/mafia_discovered_lobby.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_config.dart';
import 'package:game/features/game_two/domain/entities/mafia_game_state.dart';
import 'package:game/features/game_two/domain/entities/mafia_lobby_player.dart';
import 'package:game/features/game_two/domain/entities/mafia_phase.dart';
import 'package:game/features/game_two/domain/entities/mafia_session_event.dart';
import 'package:game/features/game_two/domain/repositories/mafia_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMafiaRepository extends Mock implements MafiaRepository {}

void registerFallbacks() {
  registerFallbackValue(
    const MafiaGameConfig(
      state: MafiaGameState.inProgress,
      phase: MafiaPhase.day,
      players: [],
    ),
  );
}
