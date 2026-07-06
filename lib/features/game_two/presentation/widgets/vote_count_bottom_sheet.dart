import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mafia_player_entity.dart';

Future<void> showVoteCountBottomSheet(
  BuildContext context, {
  required MafiaPlayerEntity player,
  required int voteCount,
  int previousCount = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXXL),
      ),
    ),
    builder: (context) {
      return _VoteCountBottomSheet(
        player: player,
        voteCount: voteCount,
        previousCount: previousCount,
      );
    },
  );
}

class _VoteCountBottomSheet extends StatelessWidget {
  const _VoteCountBottomSheet({
    required this.player,
    required this.voteCount,
    required this.previousCount,
  });

  final MafiaPlayerEntity player;
  final int voteCount;
  final int previousCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingXXL,
        AppTheme.spacingL,
        AppTheme.spacingXXL,
        AppTheme.spacingXXL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.25),
            child: Text(
              player.name.trim().isEmpty ? '?' : player.name.trim()[0],
              style: AppTextStyles.headline,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            player.name,
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'أصوات ضد هذا اللاعب',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: previousCount, end: voteCount),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 1 + (value == voteCount ? 0.08 : 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    '$value',
                    key: ValueKey<int>(value),
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 56,
                      color: AppColors.accentGame2,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingXXL),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ),
        ],
      ),
    );
  }
}
