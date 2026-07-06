import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/mafia_game_config.dart';
import '../entities/mafia_phase.dart';
import '../entities/mafia_player_entity.dart';
import '../entities/mafia_role.dart';
import '../entities/night_actions_input.dart';
import '../entities/process_night_actions_result.dart';
import '../logic/resolve_night_actions.dart';
import '../repositories/mafia_repository.dart';

class ProcessNightActionsParams extends Equatable {
  const ProcessNightActionsParams({
    required this.config,
    required this.roundNumber,
    required this.actions,
  });

  final MafiaGameConfig config;
  final int roundNumber;
  final NightActionsInput actions;

  @override
  List<Object?> get props => [config, roundNumber, actions];
}

/// Host-only: validates night inputs, resolves deaths/silence, and builds
/// minimum per-player day broadcast payloads.
@injectable
class ProcessNightActionsUseCase
    implements UseCase<ProcessNightActionsResult, ProcessNightActionsParams> {
  ProcessNightActionsUseCase(this._repository);

  final MafiaRepository _repository;

  static const _nightWakeRoles = [
    MafiaRole.mafiaBoss,
    MafiaRole.silencerMafia,
    MafiaRole.detective,
    MafiaRole.doctor,
    MafiaRole.sniper,
  ];

  @override
  Future<Either<Failure, ProcessNightActionsResult>> call(
    ProcessNightActionsParams params,
  ) async {
    if (!_repository.isHost) {
      return const Left(
        ServerFailure(message: 'Only the host can process night actions'),
      );
    }

    if (params.config.phase != MafiaPhase.night) {
      return const Left(
        ServerFailure(message: 'Night actions require night phase'),
      );
    }

    final validationError = _validateActions(
      players: params.config.players,
      actions: params.actions,
    );
    if (validationError != null) {
      return Left(ServerFailure(message: validationError));
    }

    final result = resolveNightActions(
      config: params.config,
      roundNumber: params.roundNumber,
      actions: params.actions,
    );

    return Right(result);
  }

  String? _validateActions({
    required List<MafiaPlayerEntity> players,
    required NightActionsInput actions,
  }) {
    final alivePlayers =
        players.where((player) => player.isAlive).toList();
    final aliveIds = alivePlayers.map((player) => player.id).toSet();
    final presentRoles = alivePlayers.map((player) => player.role).toSet();

    String? validateTarget(
      String? targetId, {
      required bool required,
      String? actorId,
      bool forbidSelf = false,
    }) {
      if (targetId == null) {
        return required ? 'Missing required night action target' : null;
      }
      if (!aliveIds.contains(targetId)) {
        return 'Invalid target: player is not alive';
      }
      if (forbidSelf && actorId != null && targetId == actorId) {
        return 'Role cannot target themselves';
      }
      return null;
    }

    if (presentRoles.contains(MafiaRole.mafiaBoss)) {
      final bossId = _playerIdForRole(alivePlayers, MafiaRole.mafiaBoss);
      final error = validateTarget(
        actions.mafiaKillTargetId,
        required: true,
        actorId: bossId,
        forbidSelf: true,
      );
      if (error != null) return error;
    } else if (actions.mafiaKillTargetId != null) {
      return 'Mafia kill provided but no Mafia Boss in match';
    }

    if (presentRoles.contains(MafiaRole.silencerMafia)) {
      final error = validateTarget(
        actions.silencerTargetId,
        required: true,
      );
      if (error != null) return error;
    } else if (actions.silencerTargetId != null) {
      return 'Silencer target provided but no Silencer in match';
    }

    if (presentRoles.contains(MafiaRole.detective)) {
      final detectiveId = _playerIdForRole(alivePlayers, MafiaRole.detective);
      final error = validateTarget(
        actions.detectiveTargetId,
        required: true,
        actorId: detectiveId,
        forbidSelf: true,
      );
      if (error != null) return error;
    } else if (actions.detectiveTargetId != null) {
      return 'Detective target provided but no Detective in match';
    }

    if (presentRoles.contains(MafiaRole.doctor)) {
      final doctorId = _playerIdForRole(alivePlayers, MafiaRole.doctor);
      final error = validateTarget(
        actions.doctorSaveTargetId,
        required: true,
        actorId: doctorId,
        forbidSelf: true,
      );
      if (error != null) return error;
    } else if (actions.doctorSaveTargetId != null) {
      return 'Doctor save provided but no Doctor in match';
    }

    if (presentRoles.contains(MafiaRole.sniper)) {
      final sniperId = _playerIdForRole(alivePlayers, MafiaRole.sniper);
      final error = validateTarget(
        actions.sniperTargetId,
        required: true,
        actorId: sniperId,
        forbidSelf: true,
      );
      if (error != null) return error;
    } else if (actions.sniperTargetId != null) {
      return 'Sniper target provided but no Sniper in match';
    }

    for (final role in _nightWakeRoles) {
      if (!presentRoles.contains(role)) continue;
      // Required checks handled above.
    }

    return null;
  }

  String? _playerIdForRole(
    List<MafiaPlayerEntity> players,
    MafiaRole role,
  ) {
    for (final player in players) {
      if (player.role == role) return player.id;
    }
    return null;
  }
}
