import 'package:flutter/material.dart';

import '../constants/app_name.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppName.title)),
      body: const Center(
        child: Text('مرحباً'),
      ),
    );
  }
}
