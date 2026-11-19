import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'app_theme.dart';
import 'theme_preferences.dart';

class MiniatureApp extends StatefulWidget {
  const MiniatureApp({super.key, this.initialTheme = PaintbenchTheme.darkGold});

  final PaintbenchTheme initialTheme;

  @override
  State<MiniatureApp> createState() => _MiniatureAppState();
}

class _MiniatureAppState extends State<MiniatureApp> {
  late PaintbenchTheme _selectedTheme = widget.initialTheme;

  Future<void> _changeTheme(PaintbenchTheme theme) async {
    if (theme == _selectedTheme) return;
    final previousTheme = _selectedTheme;
    setState(() => _selectedTheme = theme);
    try {
      await ThemePreferences.save(theme);
    } catch (_) {
      if (mounted) setState(() => _selectedTheme = previousTheme);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paintbench',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(_selectedTheme),
      home: AuthGate(
        selectedTheme: _selectedTheme,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}
