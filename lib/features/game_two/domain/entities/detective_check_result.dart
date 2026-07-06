import 'package:equatable/equatable.dart';

/// Private detective investigation result (host + detective device only).
class DetectiveCheckResult extends Equatable {
  const DetectiveCheckResult({
    required this.targetPlayerId,
    required this.isMafia,
  });

  final String targetPlayerId;
  final bool isMafia;

  @override
  List<Object?> get props => [targetPlayerId, isMafia];
}
