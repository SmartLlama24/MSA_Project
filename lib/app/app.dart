import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'app_theme.dart';

class MiniatureApp extends StatelessWidget {
  const MiniatureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paintbench',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
