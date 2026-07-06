import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/game_repository.dart';

class JoinRoomParams extends Equatable {
  const JoinRoomParams({
    required this.endpointId,
    required this.userName,
  });

  final String endpointId;
  final String userName;

  @override
  List<Object?> get props => [endpointId, userName];
}

@injectable
class JoinRoomUseCase implements UseCase<void, JoinRoomParams> {
  JoinRoomUseCase(this._repository);

  final GameRepository _repository;

  @override
  Future<Either<Failure, void>> call(JoinRoomParams params) =>
      _repository.joinRoom(
        endpointId: params.endpointId,
        userName: params.userName,
      );
}
