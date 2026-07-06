import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_button.dart';
import '../../domain/entities/mafia_role.dart';
import 'mafia_role_presentation.dart';
import 'mysterious_mafia_card.dart';

/// Full-screen role reveal experience with a flip card.
class MafiaRoleRevealView extends StatefulWidget {
  const MafiaRoleRevealView({
    super.key,
    required this.role,
    this.onContinue,
    this.playerName,
  });

  final MafiaRole role;
  final VoidCallback? onContinue;
  final String? playerName;

  @override
  State<MafiaRoleRevealView> createState() => _MafiaRoleRevealViewState();
}

class _MafiaRoleRevealViewState extends State<MafiaRoleRevealView> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final glow = MafiaRolePresentation.glowColor(widget.role);
    final padding = MediaQuery.paddingOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_revealed)
          Positioned(
            left: -80,
            right: -80,
            top: MediaQuery.sizeOf(context).height * 0.22,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.08),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingXXL + padding.left,
            AppTheme.spacingL + padding.top,
            AppTheme.spacingXXL + padding.right,
            AppTheme.spacingXXL + padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اكتشف دورك',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              if (widget.playerName != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  widget.playerName!,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _revealed
                    ? 'هذا دورك في اللعبة — احفظه سراً'
                    : 'اضغط مطولاً أو انقر على البطاقة',
                style: AppTextStyles.body.copyWith(
                  color: AppTextStyles.body.color?.withValues(
                    alpha: _revealed ? 0.9 : 0.65,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Expanded(
                flex: 5,
                child: MysteriousMafiaCard(
                  role: widget.role,
                  onRevealed: () => setState(() => _revealed = true),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _revealed && widget.onContinue != null ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: IgnorePointer(
                  ignoring: !_revealed || widget.onContinue == null,
                  child: MainButton(
                    text: 'متابعة',
                    onPressed: widget.onContinue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
