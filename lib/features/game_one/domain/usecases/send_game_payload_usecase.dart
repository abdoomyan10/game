import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/game_payload.dart';
import '../repositories/game_repository.dart';

class SendGamePayloadParams extends Equatable {
  const SendGamePayloadParams({
    required this.payload,
    required this.endpointId,
  });

  final GamePayload payload;
  final String endpointId;

  @override
  List<Object?> get props => [payload, endpointId];
}

@injectable
class SendGamePayloadUseCase
    implements UseCase<void, SendGamePayloadParams> {
  SendGamePayloadUseCase(this._repository);

  final GameRepository _repository;

  @override
  Future<Either<Failure, void>> call(SendGamePayloadParams params) =>
      _repository.sendGamePayload(
        payload: params.payload,
        endpointId: params.endpointId,
      );
}
