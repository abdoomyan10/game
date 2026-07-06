import 'package:equatable/equatable.dart';

/// Public day-phase data safe to broadcast to every client.
class MafiaDayPublicSummary extends Equatable {
  const MafiaDayPublicSummary({
    required this.roundNumber,
    required this.eliminatedPlayerIds,
  });

  final int roundNumber;
  final List<String> eliminatedPlayerIds;

  @override
  List<Object?> get props => [roundNumber, eliminatedPlayerIds];
}
