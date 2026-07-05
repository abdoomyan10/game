import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

class AppDecorations {
  AppDecorations._();

  static BoxDecoration splashBackground = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.background,
        AppColors.backgroundLight,
        Color(0xFF1A1033),
      ],
    ),
  );

  static BoxDecoration gameCardGradient(Color accent) => BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            accent.withValues(alpha: 0.7),
            accent.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration splashLogoCircle = BoxDecoration(
    shape: BoxShape.circle,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.secondary],
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.splashGlow.withValues(alpha: 0.5),
        blurRadius: 32,
        spreadRadius: 4,
      ),
    ],
  );
}
