import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../constants/secret_words.dart';
import '../entities/distribute_roles_result.dart';
import '../entities/game_payload.dart';
import '../entities/player.dart';
import '../entities/player_role.dart';
import '../repositories/game_repository.dart';
import 'send_game_payload_usecase.dart';

class DistributeRolesParams extends Equatable {
  const DistributeRolesParams({
    required this.players,
    required this.imposterCount,
  });

  final List<Player> players;
  final int imposterCount;

  @override
  List<Object?> get props => [players, imposterCount];
}

/// Host-only use case: shuffles players, assigns imposters, picks a secret word,
/// and sends isolated encrypted payloads per connected endpoint.
///
/// The real secret word exists only in this use case's local scope while
/// distributing. Imposter devices receive [SecretWords.imposterPlaceholder] only.
@injectable
class DistributeRolesUseCase
    implements UseCase<DistributeRolesResult, DistributeRolesParams> {
  DistributeRolesUseCase(
    this._repository,
    this._sendGamePayload,
  );

  final GameRepository _repository;
  final SendGamePayloadUseCase _sendGamePayload;

  static const String _hostPlayerId = 'local';

  @override
  Future<Either<Failure, DistributeRolesResult>> call(
    DistributeRolesParams params,
  ) async {
    if (!_repository.isHost) {
      return const Left(
        ServerFailure(message: 'Only the host can distribute roles'),
      );
    }

    if (params.players.isEmpty) {
      return const Left(ServerFailure(message: 'No players in the lobby'));
    }

    if (params.imposterCount < 0) {
      return const Left(
        ServerFailure(message: 'Imposter count cannot be negative'),
      );
    }

    if (params.imposterCount >= params.players.length) {
      return const Left(
        ServerFailure(
          message: 'Imposter count must be less than player count',
        ),
      );
    }

    final secretWord = SecretWords.pickRandom();
    final shuffled = List<Player>.from(params.players)..shuffle(Random.secure());

    final imposterIds = shuffled
        .take(params.imposterCount)
        .map((player) => player.id)
        .toSet();

    GamePayload? hostPayload;

    for (final player in params.players) {
      final isImposter = imposterIds.contains(player.id);
      final payload = _buildPayload(
        isImposter: isImposter,
        secretWord: secretWord,
      );

      if (player.id == _hostPlayerId) {
        hostPayload = payload;
        continue;
      }

      final sendResult = await _sendGamePayload(
        SendGamePayloadParams(payload: payload, endpointId: player.id),
      );

      final failure = sendResult.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) return Left(failure);
    }

    if (hostPayload == null) {
      return const Left(
        ServerFailure(message: 'Host player not found in lobby'),
      );
    }

    return Right(DistributeRolesResult(hostPayload: hostPayload));
  }

  GamePayload _buildPayload({
    required bool isImposter,
    required String secretWord,
  }) {
    if (isImposter) {
      return const GamePayload(
        role: PlayerRole.imposter,
        word: SecretWords.imposterPlaceholder,
      );
    }

    return GamePayload(
      role: PlayerRole.normal,
      word: secretWord,
    );
  }
}
