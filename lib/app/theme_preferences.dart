import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

abstract final class ThemePreferences {
  static const _preferenceKey = 'paintbench_theme';

  static Future<PaintbenchTheme> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString(_preferenceKey);
    return PaintbenchTheme.values.firstWhere(
      (theme) => theme.name == savedTheme,
      orElse: () => PaintbenchTheme.darkGold,
    );
  }

  static Future<void> save(PaintbenchTheme theme) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, theme.name);
  }
}
