import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/discovered_room.dart';
import '../entities/game_payload.dart';
import '../entities/game_session_event.dart';
import '../entities/player.dart';

abstract class GameRepository {
  bool get isHost;

  Stream<DiscoveredRoom> get discoveredRooms;

  Stream<List<Player>> get players;

  Stream<GamePayload> get incomingPayloads;

  Stream<Set<String>> get connectedEndpointIds;

  Stream<GameSessionEvent> get sessionEvents;

  Future<Either<Failure, void>> ensurePermissions();

  Future<Either<Failure, void>> startHosting(String userName);

  Future<Either<Failure, void>> scanForRooms(String userName);

  Future<Either<Failure, void>> joinRoom({
    required String endpointId,
    required String userName,
  });

  Future<Either<Failure, void>> sendGamePayload({
    required GamePayload payload,
    required String endpointId,
  });

  Future<Either<Failure, void>> disconnect();
}
