import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mafia_victory_side.dart';

class MafiaGameOverView extends StatelessWidget {
  const MafiaGameOverView({
    super.key,
    required this.winner,
    required this.message,
  });

  final MafiaVictorySide winner;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'انتهت اللعبة',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            message,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            winner == MafiaVictorySide.mafia ? 'المافيا' : 'المواطنون',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
