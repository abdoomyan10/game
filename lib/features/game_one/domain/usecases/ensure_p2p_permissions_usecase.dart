import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/game_repository.dart';

@injectable
class EnsureP2pPermissionsUseCase implements UseCase<void, NoParams> {
  EnsureP2pPermissionsUseCase(this._repository);

  final GameRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) =>
      _repository.ensurePermissions();
}
