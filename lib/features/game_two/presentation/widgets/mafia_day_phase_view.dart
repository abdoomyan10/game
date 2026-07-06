import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_player_entity.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaDayPhaseView extends StatelessWidget {
  const MafiaDayPhaseView({
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
    final aliveCount = players.where((player) => player.isAlive).length;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'النهار — الجولة $roundNumber',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'مرحلة النقاش — $aliveCount لاعبين أحياء',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingXXXL),
            MainButton(
              text: 'بدء التصويت',
              onPressed: () => context.read<MafiaBloc>().add(NextPhaseEvent()),
            ),
          ],
        ],
      ),
    );
  }
}
