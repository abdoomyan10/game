import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_player_entity.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaVotingPhaseView extends StatelessWidget {
  const MafiaVotingPhaseView({
    super.key,
    required this.players,
    required this.isHost,
    required this.roundNumber,
  });

  final List<MafiaPlayerEntity> players;
  final bool isHost;
  final int roundNumber;

  @override
  Widget build(BuildContext context) {
    final alivePlayers = players.where((player) => player.isAlive).toList();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'التصويت — الجولة $roundNumber',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'صوّت لإخراج مشتبه به',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXL),
          Expanded(
            child: ListView.separated(
              itemCount: alivePlayers.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacingM),
              itemBuilder: (context, index) {
                final player = alivePlayers[index];
                return ListTile(
                  title: Text(player.name),
                  subtitle: Text(player.role.name),
                );
              },
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingL),
            MainButton(
              text: 'إنهاء التصويت',
              onPressed: () => context.read<MafiaBloc>().add(NextPhaseEvent()),
            ),
          ],
        ],
      ),
    );
  }
}
