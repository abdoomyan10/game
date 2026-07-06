import 'package:flutter/material.dart';

import '../../domain/entities/mafia_role.dart';

/// Arabic labels, icons, and glow colors for [MafiaRole] UI.
class MafiaRolePresentation {
  MafiaRolePresentation._();

  static String label(MafiaRole role) => switch (role) {
        MafiaRole.mafiaBoss => 'زعيم المافيا',
        MafiaRole.silencerMafia => 'مافيا الصامت',
        MafiaRole.doctor => 'المسعفة',
        MafiaRole.detective => 'شيخ الصالحين',
        MafiaRole.sniper => 'القناص',
        MafiaRole.citizen => 'مواطن',
      };

  static IconData icon(MafiaRole role) => switch (role) {
        MafiaRole.mafiaBoss => Icons.whatshot,
        MafiaRole.silencerMafia => Icons.volume_off,
        MafiaRole.doctor => Icons.medical_services_outlined,
        MafiaRole.detective => Icons.search,
        MafiaRole.sniper => Icons.gps_fixed,
        MafiaRole.citizen => Icons.person_outline,
      };

  static Color glowColor(MafiaRole role) => switch (role) {
        MafiaRole.mafiaBoss || MafiaRole.silencerMafia => const Color(0xFFDC2626),
        MafiaRole.citizen => const Color(0xFFF59E0B),
        MafiaRole.doctor => const Color(0xFF38BDF8),
        MafiaRole.detective => const Color(0xFFEAB308),
        MafiaRole.sniper => const Color(0xFF6366F1),
      };

  static String alignmentLabel(MafiaRole role) =>
      role.isMafia ? 'المافيا' : 'المدينة';
}
