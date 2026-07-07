import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../data/constants/mafia_p2p_constants.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaLobbyView extends StatelessWidget {
  const MafiaLobbyView({
    super.key,
    required this.players,
    required this.isHost,
    required this.canStartGame,
  });

  final List<MafiaLobbyPlayer> players;
  final bool isHost;
  final bool canStartGame;

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
                ? 'انتظر انضمام اللاعبين ثم ابدأ اللعبة (لاعبان على الأقل)'
                : 'في انتظار المضيف لبدء اللعبة...',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (isHost &&
              players.length >= MafiaP2pConstants.minPlayersToStart &&
              !canStartGame) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'جاري تأكيد الاتصال…',
              style: AppTextStyles.body.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
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
              onPressed: canStartGame &&
                      players.length >= MafiaP2pConstants.minPlayersToStart
                  ? () => context.read<MafiaBloc>().add(StartMafiaGame())
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
