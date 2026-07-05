import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/splash/presentation/bloc/splash_bloc.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../theme/app_text_styles.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String home = '/home';
  static const String gameOne = '/game-one';
  static const String gameTwo = '/game-two';

  static const String initial = splash;

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => getIt<SplashBloc>(),
            child: const SplashPage(),
          ),
        );
      case home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => getIt<HomeBloc>(),
            child: const HomePage(),
          ),
        );
      case gameOne:
      case gameTwo:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _GamePlaceholderPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => getIt<SplashBloc>(),
            child: const SplashPage(),
          ),
        );
    }
  }
}

class _GamePlaceholderPage extends StatelessWidget {
  const _GamePlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text('قريباً', style: AppTextStyles.headline),
      ),
    );
  }
}
