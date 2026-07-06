import 'package:equatable/equatable.dart';

import '../../features/game_one/domain/entities/p2p_disconnect_reason.dart';
import '../../features/game_one/domain/entities/p2p_permission.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.statusCode});
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    this.deniedPermissions = const [],
    super.statusCode,
  });

  final List<P2pPermission> deniedPermissions;

  @override
  List<Object?> get props => [message, statusCode, deniedPermissions];
}

class P2pFailure extends Failure {
  const P2pFailure({
    required super.message,
    this.reason,
    super.statusCode,
  });

  final P2pDisconnectReason? reason;

  @override
  List<Object?> get props => [message, statusCode, reason];
}
