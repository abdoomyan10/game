import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/player_role.dart';

class GameplayView extends StatelessWidget {
  const GameplayView({
    super.key,
    required this.role,
    required this.word,
    required this.remainingSeconds,
  });

  final PlayerRole role;
  final String? word;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final isImposter = role.isImposter;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isImposter ? 'أنت المخادع' : 'أنت لاعب عادي',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXXL),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXXL),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: isImposter
                    ? AppColors.accentGame1
                    : AppColors.accentGame2,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isImposter ? 'الكلمة السرية' : 'كلمتك هي',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  isImposter ? '؟؟؟' : (word ?? '—'),
                  style: AppTextStyles.gameCardTitle.copyWith(
                    fontSize: 32,
                    color: isImposter
                        ? AppColors.onSurface.withValues(alpha: 0.5)
                        : AppColors.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isImposter) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'حاول اكتشاف الكلمة دون أن ينكشف أمرك',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXXXL),
          Text(
            'الوقت المتبقي',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            _formatTime(remainingSeconds),
            style: AppTextStyles.splashTitle.copyWith(
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}
