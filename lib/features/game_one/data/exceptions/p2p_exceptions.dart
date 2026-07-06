import '../../domain/entities/p2p_disconnect_reason.dart';
import '../../domain/entities/p2p_permission.dart';

class P2pPermissionException implements Exception {
  const P2pPermissionException({
    required this.message,
    this.denied = const [],
  });

  final String message;
  final List<P2pPermission> denied;

  @override
  String toString() => message;
}

class P2pTransportException implements Exception {
  const P2pTransportException({
    required this.message,
    this.reason,
  });

  final String message;
  final P2pDisconnectReason? reason;

  @override
  String toString() => message;
}
