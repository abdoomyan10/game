import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../bloc/game_one_bloc.dart';
import 'player_name_dialog.dart';

class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  Future<void> _hostGame(BuildContext context) async {
    final name = await showPlayerNameDialog(context);
    if (!context.mounted || name == null) return;
    context.read<GameOneBloc>().add(HostRoomEvent(name));
  }

  Future<void> _joinGame(BuildContext context) async {
    final name = await showPlayerNameDialog(context);
    if (!context.mounted || name == null) return;
    context.read<GameOneBloc>().add(DiscoverRoomsEvent(name));
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
            'كيف تريد اللعب؟',
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
