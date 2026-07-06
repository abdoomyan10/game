import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaLobbyView extends StatelessWidget {
  const MafiaLobbyView({
    super.key,
    required this.players,
    required this.isHost,
  });

  final List<MafiaLobbyPlayer> players;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'غرفة الانتظار',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            isHost
                ? 'انتظر انضمام اللاعبين ثم ابدأ اللعبة (٣ لاعبين على الأقل)'
                : 'في انتظار المضيف لبدء اللعبة...',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXL),
          Expanded(
            child: ListView.separated(
              itemCount: players.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacingM),
              itemBuilder: (context, index) {
                final player = players[index];
                return ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  leading: Icon(
                    player.isHost ? Icons.star : Icons.person,
                    color: AppColors.primary,
                  ),
                  title: Text(player.name, style: AppTextStyles.body),
                  subtitle: player.isHost ? const Text('المضيف') : null,
                );
              },
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingL),
            MainButton(
              text: 'بدء اللعبة',
              onPressed: players.length >= 3
                  ? () => context.read<MafiaBloc>().add(StartMafiaGame())
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
