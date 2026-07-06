import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/game_repository.dart';

class StartHostingParams extends Equatable {
  const StartHostingParams({required this.userName});

  final String userName;

  @override
  List<Object?> get props => [userName];
}

@injectable
class StartHostingUseCase implements UseCase<void, StartHostingParams> {
  StartHostingUseCase(this._repository);

  final GameRepository _repository;

  @override
  Future<Either<Failure, void>> call(StartHostingParams params) =>
      _repository.startHosting(params.userName);
}
