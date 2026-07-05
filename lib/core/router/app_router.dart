import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static const String initial = '/';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShell(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShell(),
        );
    }
  }
}
