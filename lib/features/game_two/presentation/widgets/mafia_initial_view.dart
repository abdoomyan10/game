import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../../game_one/presentation/widgets/player_name_dialog.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaInitialView extends StatelessWidget {
  const MafiaInitialView({super.key});

  Future<void> _hostGame(BuildContext context) async {
    final name = await showPlayerNameDialog(context);
    if (!context.mounted || name == null) return;
    context.read<MafiaBloc>().add(HostLobbyEvent(name));
  }

  Future<void> _joinGame(BuildContext context) async {
    final name = await showPlayerNameDialog(context);
    if (!context.mounted || name == null) return;
    context.read<MafiaBloc>().add(DiscoverLobbyEvent(name));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'لعبة المافيا',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'اختر استضافة جلسة جديدة أو الانضمام إلى مضيف قريب',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXXL),
          MainButton(
            text: 'استضافة لعبة',
            onPressed: () => _hostGame(context),
          ),
          const SizedBox(height: AppTheme.spacingL),
          MainButton(
            text: 'انضمام للعبة',
            onPressed: () => _joinGame(context),
          ),
        ],
      ),
    );
  }
}
