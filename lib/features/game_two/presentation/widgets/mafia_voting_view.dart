import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_player_entity.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';
import '../bloc/mafia_state.dart';
import 'mafia_player_grid.dart';
import 'vote_count_bottom_sheet.dart';

/// Voting phase with interactive player grid and vote count bottom sheet.
class MafiaVotingView extends StatelessWidget {
  const MafiaVotingView({
    super.key,
    required this.players,
    required this.isHost,
    required this.roundNumber,
    required this.voteCounts,
    this.myVoteTargetId,
    this.onEndVoting,
  });

  final List<MafiaPlayerEntity> players;
  final bool isHost;
  final int roundNumber;
  final Map<String, int> voteCounts;
  final String? myVoteTargetId;
  final VoidCallback? onEndVoting;

  Future<void> _onPlayerTap(
    BuildContext context,
    MafiaPlayerEntity player,
  ) async {
    if (!player.isAlive) return;

    final bloc = context.read<MafiaBloc>();
    final previousCount = voteCounts[player.id] ?? 0;
    bloc.add(CastVoteEvent(player.id));

    final updated = await bloc.stream.firstWhere(
      (state) =>
          state is MafiaVotingPhase && state.myVoteTargetId == player.id,
    );
    if (updated is! MafiaVotingPhase) return;
    if (!context.mounted) return;

    final newCount = updated.voteCounts[player.id] ?? 0;
    await showVoteCountBottomSheet(
      context,
      player: player,
      voteCount: newCount,
      previousCount: previousCount,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            'اضغط على لاعب للتصويت ضده',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Expanded(
            child: MafiaPlayerGrid(
              players: players,
              onPlayerTap: (player) => _onPlayerTap(context, player),
              selectedVoteTargetId: myVoteTargetId,
              voteCounts: voteCounts,
              showVoteOverlay: true,
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: AppTheme.spacingL),
            MainButton(
              text: 'إنهاء التصويت',
              onPressed: onEndVoting,
            ),
          ],
        ],
      ),
    );
  }
}
