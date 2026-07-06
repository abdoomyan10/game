import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mafia_player_entity.dart';
import 'mafia_player_card_styles.dart';

/// Interactive avatar card for a single Mafia player.
class MafiaPlayerAvatarCard extends StatefulWidget {
  const MafiaPlayerAvatarCard({
    super.key,
    required this.player,
    this.onTap,
    this.isVoteSelected = false,
    this.showVoteOverlay = false,
    this.voteCount = 0,
  });

  final MafiaPlayerEntity player;
  final VoidCallback? onTap;
  final bool isVoteSelected;
  final bool showVoteOverlay;
  final int voteCount;

  @override
  State<MafiaPlayerAvatarCard> createState() => _MafiaPlayerAvatarCardState();
}

class _MafiaPlayerAvatarCardState extends State<MafiaPlayerAvatarCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mutePulseController;
  late final Animation<double> _mutePulse;

  @override
  void initState() {
    super.initState();
    _mutePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mutePulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _mutePulseController, curve: Curves.easeInOut),
    );
    _updateMuteAnimation();
  }

  @override
  void didUpdateWidget(covariant MafiaPlayerAvatarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMuteAnimation();
  }

  void _updateMuteAnimation() {
    final shouldPulse =
        widget.player.isAlive && widget.player.isSilenced;
    if (shouldPulse && !_mutePulseController.isAnimating) {
      _mutePulseController.repeat(reverse: true);
    } else if (!shouldPulse) {
      _mutePulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _mutePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isDead = !player.isAlive;
    final showMuted = player.isAlive && player.isSilenced;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.backgroundLight,
          ],
        ),
        border: Border.all(
          color: widget.isVoteSelected
              ? AppColors.accentGame2
              : AppColors.surfaceLight,
          width: widget.isVoteSelected ? 2 : 1,
        ),
        boxShadow: widget.isVoteSelected
            ? [
                BoxShadow(
                  color: AppColors.accentGame2.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                  child: Text(
                    _initial(player.name),
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.onBackground,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  player.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (player.isHost) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'المضيف',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showMuted)
            Positioned(
              top: AppTheme.spacingS,
              right: AppTheme.spacingS,
              child: ScaleTransition(
                scale: _mutePulse,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_off_rounded,
                    size: 16,
                    color: AppColors.onError,
                  ),
                ),
              ),
            ),
          if (widget.showVoteOverlay && widget.voteCount > 0)
            Positioned(
              top: AppTheme.spacingS,
              left: AppTheme.spacingS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGame2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  '${widget.voteCount}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.background,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isDead) {
      card = ColorFiltered(
        colorFilter: kMafiaGrayscaleColorFilter,
        child: card,
      );
    }

    card = AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: isDead ? 0.42 : 1,
      child: card,
    );

    if (widget.onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: card,
        ),
      );
    }

    return card;
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0];
  }
}
