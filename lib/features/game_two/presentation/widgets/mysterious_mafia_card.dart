import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mafia_role.dart';
import 'mafia_role_presentation.dart';

/// Face-down playing card that flips in 3D to reveal a [MafiaRole].
class MysteriousMafiaCard extends StatefulWidget {
  const MysteriousMafiaCard({
    super.key,
    required this.role,
    this.onRevealed,
  });

  final MafiaRole role;
  final VoidCallback? onRevealed;

  @override
  State<MysteriousMafiaCard> createState() => _MysteriousMafiaCardState();
}

class _MysteriousMafiaCardState extends State<MysteriousMafiaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool _isRevealed = false;
  bool _glowEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _glowEnabled = true);
        widget.onRevealed?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isRevealed) return;
    _isRevealed = true;
    HapticFeedback.mediumImpact();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.clamp(280.0, 400.0);
        final cardW = maxW * 0.88;
        final cardH = cardW * 1.45;

        return Center(
          child: SizedBox(
            width: cardW,
            height: cardH,
            child: GestureDetector(
              onTap: _flip,
              onLongPress: _flip,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final angle = _animation.value * pi;
                  final showFront = angle >= pi / 2;
                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(showFront ? angle - pi : angle);

                  return Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: showFront
                        ? _CardFront(role: widget.role, glowEnabled: _glowEnabled)
                        : const _CardBack(),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.surface,
            Color(0xFF1A0A0A),
          ],
        ),
        border: Border.all(color: AppColors.surfaceLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _MysteryPatternPainter()),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXXL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    size: 56,
                    color: AppColors.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Text(
                    '؟',
                    style: AppTextStyles.gameCardTitle.copyWith(
                      fontSize: 48,
                      color: AppColors.onSurface.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  Text(
                    'بطاقة سرية',
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'اضغط للكشف',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.onSurface.withValues(alpha: 0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.role,
    required this.glowEnabled,
  });

  final MafiaRole role;
  final bool glowEnabled;

  @override
  Widget build(BuildContext context) {
    final glow = MafiaRolePresentation.glowColor(role);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              glow.withValues(alpha: 0.18),
              AppColors.surface,
            ),
            AppColors.backgroundLight,
            Color.alphaBlend(
              glow.withValues(alpha: 0.08),
              AppColors.surface,
            ),
          ],
        ),
        border: Border.all(
          color: glow.withValues(alpha: glowEnabled ? 0.6 : 0.2),
          width: 1.5,
        ),
        boxShadow: glowEnabled
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.55),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: glow.withValues(alpha: 0.25),
                  blurRadius: 56,
                  spreadRadius: 8,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glow.withValues(alpha: 0.15),
                border: Border.all(
                  color: glow.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: glowEnabled
                    ? [
                        BoxShadow(
                          color: glow.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                MafiaRolePresentation.icon(role),
                size: 44,
                color: glow,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXXL),
            Text(
              MafiaRolePresentation.label(role),
              style: AppTextStyles.gameCardTitle.copyWith(
                fontSize: 26,
                color: AppColors.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: glow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(
                  color: glow.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'فريق ${MafiaRolePresentation.alignmentLabel(role)}',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: glow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle diagonal crosshatch for the face-down card back.
class _MysteryPatternPainter extends CustomPainter {
  const _MysteryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onSurface.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 18.0;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
    for (var x = 0.0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
