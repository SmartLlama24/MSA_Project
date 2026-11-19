import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../app/app_navigation.dart';
import 'auth_screen.dart';
import 'auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  final PaintbenchTheme selectedTheme;
  final Future<void> Function(PaintbenchTheme theme) onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final authService = SupabaseAuthService(client);

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: context.appPalette.accent,
              ),
            ),
          );
        }

        final session = snapshot.data!.session;
        if (session == null) {
          return AuthScreen(authService: authService);
        }

        return AppNavigation(
          email: session.user.email ?? '',
          onLogout: authService.signOut,
          selectedTheme: selectedTheme,
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}
