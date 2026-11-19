import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paint_app/app/app_theme.dart';
import 'package:paint_app/app/theme_preferences.dart';
import 'package:paint_app/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'theme preference defaults to Dark & Gold and persists selections',
    () async {
      expect(await ThemePreferences.load(), PaintbenchTheme.darkGold);

      await ThemePreferences.save(PaintbenchTheme.whiteGreen);

      expect(await ThemePreferences.load(), PaintbenchTheme.whiteGreen);
    },
  );

  test('each theme provides its requested palette', () {
    final warmWhite = AppTheme.themeFor(PaintbenchTheme.warmWhite);
    final whiteGreen = AppTheme.themeFor(PaintbenchTheme.whiteGreen);
    final lightRed = AppTheme.themeFor(PaintbenchTheme.lightRed);

    expect(warmWhite.scaffoldBackgroundColor, const Color(0xFFF1F0EC));
    expect(warmWhite.extension<AppPalette>()!.accent, const Color(0xFF82725D));
    expect(whiteGreen.scaffoldBackgroundColor, const Color(0xFFF7F8F7));
    expect(whiteGreen.extension<AppPalette>()!.accent, const Color(0xFF527452));
    expect(lightRed.scaffoldBackgroundColor, const Color(0xFFF2F1EE));
    expect(lightRed.extension<AppPalette>()!.accent, const Color(0xFF8C3434));
  });

  testWidgets('Profile selection updates the app theme immediately', (
    tester,
  ) async {
    var selectedTheme = PaintbenchTheme.darkGold;
    late StateSetter updateApp;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateApp = setState;
          return MaterialApp(
            theme: AppTheme.themeFor(selectedTheme),
            home: Scaffold(
              body: ProfileScreen(
                email: 'painter@example.com',
                selectedTheme: selectedTheme,
                onLogout: () async {},
                onThemeChanged: (theme) async {
                  selectedTheme = theme;
                  updateApp(() {});
                },
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('White & Green'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(selectedTheme, PaintbenchTheme.whiteGreen);
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFFF7F8F7));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
