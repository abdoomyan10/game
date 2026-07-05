import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/core/theme/app_colors.dart';
import 'package:game/features/home/presentation/widgets/game_card.dart';

void main() {
  testWidgets('GameCard calls onTap when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameCard(
            title: 'لعبة ١',
            subtitle: 'مغامرة',
            icon: Icons.extension,
            accentColor: AppColors.accentGame1,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('لعبة ١'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
