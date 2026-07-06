import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_player_entity.dart';
import 'mafia_player_grid.dart';

/// Day discussion phase with animated player roster grid.
class MafiaDayDiscussionView extends StatelessWidget {
  const MafiaDayDiscussionView({
    super.key,
    required this.players,
    required this.isHost,
    required this.roundNumber,
    this.onStartVoting,
  });

  final List<MafiaPlayerEntity> players;
  final bool isHost;
  final int roundNumber;
  final VoidCallback? onStartVoting;

  @override
  Widget build(BuildContext context) {
    final aliveCount = players.where((player) => player.isAlive).length;
    final silencedCount =
        players.where((player) => player.isAlive && player.isSilenced).length;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'النهار — الجولة $roundNumber',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'مرحلة النقاش — $aliveCount لاعبين أحياء',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (silencedCount > 0) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'لاعب صامت لا يستطيع الكلام اليوم',
              style: AppTextStyles.body.copyWith(
                color: AppTextStyles.body.color?.withValues(alpha: 0.75),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppTheme.spacingL),
          Expanded(
            child: MafiaPlayerGrid(
              players: players,
              onPlayerTap: (player) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(player.name),
                      duration: const Duration(seconds: 1),
                    ),
                  );
              },
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingL),
            MainButton(
              text: 'بدء التصويت',
              onPressed: onStartVoting,
            ),
          ],
        ],
      ),
    );
  }
}
