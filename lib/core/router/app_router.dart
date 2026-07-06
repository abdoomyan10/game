import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection.dart';
import '../../features/game_one/presentation/bloc/game_one_bloc.dart';
import '../../features/game_one/presentation/pages/game_one_main_page.dart';
import '../../features/game_two/presentation/bloc/mafia_bloc.dart';
import '../../features/game_two/presentation/pages/mafia_main_page.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/splash/presentation/bloc/splash_bloc.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => getIt<GameOneBloc>(),
            child: const GameOneMainPage(),
          ),
        );
      case gameTwo:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => getIt<MafiaBloc>(),
            child: const MafiaMainPage(),
          ),
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
