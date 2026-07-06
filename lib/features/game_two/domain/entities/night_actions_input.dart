import 'package:equatable/equatable.dart';

/// Night targets collected by the host during role wake steps.
///
/// Only the host holds the full input; clients never see other roles' targets.
class NightActionsInput extends Equatable {
  const NightActionsInput({
    this.mafiaKillTargetId,
    this.silencerTargetId,
    this.detectiveTargetId,
    this.doctorSaveTargetId,
    this.sniperTargetId,
  });

  final String? mafiaKillTargetId;
  final String? silencerTargetId;
  final String? detectiveTargetId;
  final String? doctorSaveTargetId;
  final String? sniperTargetId;

  @override
  List<Object?> get props => [
        mafiaKillTargetId,
        silencerTargetId,
        detectiveTargetId,
        doctorSaveTargetId,
        sniperTargetId,
      ];
}
