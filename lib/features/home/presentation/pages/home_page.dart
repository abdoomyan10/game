import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/game_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/home_bloc.dart';
import '../widgets/game_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == HomeStatus.gameSelected,
      listener: (context, state) {
        final route = context.read<HomeBloc>().routeForGame(
              state.selectedGameId ?? '',
            );
        if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacingXXXL),
                Text(
                  'اختر لعبتك',
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'اضغط على اللعبة التي تريد لعبها',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXXXL),
                GameCard(
                  title: 'لعبة ١',
                  subtitle: 'مغامرة ممتعة',
                  icon: Icons.extension,
                  accentColor: AppColors.accentGame1,
                  onTap: () => context.read<HomeBloc>().add(
                        HomeGameSelected(GameIds.game1),
                      ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                GameCard(
                  title: 'لعبة ٢',
                  subtitle: 'تحدي مثير',
                  icon: Icons.casino,
                  accentColor: AppColors.accentGame2,
                  onTap: () => context.read<HomeBloc>().add(
                        HomeGameSelected(GameIds.game2),
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
