import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.onBackground,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.onBackground,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
    height: 1.5,
  );

  static const TextStyle gameCardTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.onPrimary,
    height: 1.2,
  );

  static const TextStyle gameCardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
    height: 1.4,
  );

  static const TextStyle splashTitle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.onBackground,
    letterSpacing: 1.2,
  );
}
