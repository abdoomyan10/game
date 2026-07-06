import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_role.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaNightPhaseView extends StatelessWidget {
  const MafiaNightPhaseView({
    super.key,
    required this.activeWakeRole,
    required this.completedWakeRoles,
    required this.isHost,
    required this.roundNumber,
  });

  final MafiaRole activeWakeRole;
  final Set<MafiaRole> completedWakeRoles;
  final bool isHost;
  final int roundNumber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الليل — الجولة $roundNumber',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'استيقظ: ${_roleLabel(activeWakeRole)}',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'أدوار مكتملة: ${completedWakeRoles.map(_roleLabel).join('، ')}',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingXXXL),
            MainButton(
              text: 'تنفيذ دور ${_roleLabel(activeWakeRole)}',
              onPressed: () => context.read<MafiaBloc>().add(
                    ExecuteRoleAction(actingRole: activeWakeRole),
                  ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            MainButton(
              text: 'المرحلة التالية',
              onPressed: () =>
                  context.read<MafiaBloc>().add(NextPhaseEvent()),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(MafiaRole role) => switch (role) {
        MafiaRole.mafiaBoss => 'زعيم المافيا',
        MafiaRole.silencerMafia => 'مافيا الصامت',
        MafiaRole.doctor => 'المسعفة',
        MafiaRole.detective => 'شيخ الصالحين',
        MafiaRole.sniper => 'القناص',
        MafiaRole.citizen => 'مواطن',
      };
}
