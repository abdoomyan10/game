import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/player.dart';
import '../bloc/game_one_bloc.dart';

class LobbyView extends StatelessWidget {
  const LobbyView({
    super.key,
    required this.players,
    required this.isHost,
  });

  final List<Player> players;
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
                ? 'انتظر انضمام اللاعبين ثم ابدأ اللعبة'
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
                return _PlayerTile(player: player);
              },
            ),
          ),
          if (isHost) ...[
            MainButton(
              text: 'بدء اللعبة',
              onPressed: () =>
                  context.read<GameOneBloc>().add(StartGameEvent()),
            ),
          ] else ...[
            const SizedBox(height: AppTheme.spacingL),
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: player.isHost
                ? AppColors.accentGame1
                : AppColors.accentGame2,
            child: Icon(
              player.isHost ? Icons.star : Icons.person,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Text(player.name, style: AppTextStyles.title),
          ),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGame1.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Text(
                'مضيف',
                style: TextStyle(
                  color: AppColors.accentGame1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
