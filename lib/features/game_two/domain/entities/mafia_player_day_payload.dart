import 'package:equatable/equatable.dart';

import 'detective_check_result.dart';
import 'mafia_day_public_summary.dart';

/// Per-endpoint day payload with public summary and private fields.
class MafiaPlayerDayPayload extends Equatable {
  const MafiaPlayerDayPayload({
    required this.public,
    required this.youAreSilenced,
    this.investigation,
  });

  final MafiaDayPublicSummary public;
  final bool youAreSilenced;
  final DetectiveCheckResult? investigation;

  @override
  List<Object?> get props => [public, youAreSilenced, investigation];
}
