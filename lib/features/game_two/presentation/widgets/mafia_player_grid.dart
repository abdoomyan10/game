import 'package:flutter/material.dart';

import '../../domain/entities/mafia_player_entity.dart';
import 'mafia_player_avatar_card.dart';

/// Responsive grid of [MafiaPlayerAvatarCard] widgets.
class MafiaPlayerGrid extends StatelessWidget {
  const MafiaPlayerGrid({
    super.key,
    required this.players,
    this.onPlayerTap,
    this.selectedVoteTargetId,
    this.voteCounts = const {},
    this.showVoteOverlay = false,
  });

  final List<MafiaPlayerEntity> players;
  final void Function(MafiaPlayerEntity player)? onPlayerTap;
  final String? selectedVoteTargetId;
  final Map<String, int> voteCounts;
  final bool showVoteOverlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / 112).floor().clamp(2, 4);

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return MafiaPlayerAvatarCard(
              player: player,
              onTap: onPlayerTap != null ? () => onPlayerTap!(player) : null,
              isVoteSelected: selectedVoteTargetId == player.id,
              showVoteOverlay: showVoteOverlay,
              voteCount: voteCounts[player.id] ?? 0,
            );
          },
        );
      },
    );
  }
}
