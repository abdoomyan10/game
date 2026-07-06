import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

class MafiaReconnectOverlay extends StatefulWidget {
  const MafiaReconnectOverlay({
    super.key,
    required this.reconnectDeadline,
    this.statusMessage,
  });

  final DateTime reconnectDeadline;
  final String? statusMessage;

  @override
  State<MafiaReconnectOverlay> createState() => _MafiaReconnectOverlayState();
}

class _MafiaReconnectOverlayState extends State<MafiaReconnectOverlay> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final remaining =
        widget.reconnectDeadline.difference(DateTime.now()).inSeconds;
    setState(() {
      _secondsRemaining = remaining.clamp(0, 999);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXXL),
            padding: const EdgeInsets.all(AppTheme.spacingXXL),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  widget.statusMessage ??
                      'انقطع اتصال لاعب — محاولة إعادة الاتصال…',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  '$_secondsRemaining ث',
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.accentGame2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
