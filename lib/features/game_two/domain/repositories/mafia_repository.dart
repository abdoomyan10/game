import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/mafia_discovered_lobby.dart';
import '../entities/mafia_game_config.dart';
import '../entities/mafia_lobby_player.dart';
import '../entities/mafia_session_event.dart';

abstract class MafiaRepository {
  bool get isHost;

  String? get localPlayerId;

  MafiaGameConfig? get activeGameConfig;

  void setActiveGameConfig(MafiaGameConfig? config);

  Stream<MafiaSessionEvent> get sessionEvents;

  Stream<List<MafiaLobbyPlayer>> get players;

  Stream<MafiaDiscoveredLobby> get discoveredLobbies;

  Future<Either<Failure, void>> ensurePermissions();

  Future<Either<Failure, void>> startHosting(String userName);

  Future<Either<Failure, void>> scanForLobbies(String userName);

  Future<Either<Failure, void>> joinLobby({
    required String endpointId,
    required String userName,
  });

  Future<Either<Failure, void>> disconnect();
}
