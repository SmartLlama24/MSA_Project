import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';
import '../auth/auth_error_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.onLogout,
    this.selectedTheme = PaintbenchTheme.darkGold,
    required this.onThemeChanged,
  });

  final String email;
  final Future<void> Function() onLogout;
  final PaintbenchTheme selectedTheme;
  final Future<void> Function(PaintbenchTheme theme) onThemeChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  late PaintbenchTheme _selectedTheme = widget.selectedTheme;

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTheme != oldWidget.selectedTheme) {
      _selectedTheme = widget.selectedTheme;
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _selectTheme(PaintbenchTheme theme) async {
    if (theme == _selectedTheme) return;
    final previousTheme = _selectedTheme;
    setState(() => _selectedTheme = theme);
    try {
      await widget.onThemeChanged(theme);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedTheme = previousTheme);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your theme preference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = sampleProjects
        .where((project) => project.progress == 1)
        .length;
    final paintCount = samplePaints
        .where((paint) => paint.status == PaintStatus.owned)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.appPalette.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: context.appPalette.elevatedSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.appPalette.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    color: context.appPalette.accent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text('Signed in'),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _ProfileStat(value: '$completed', label: 'Finished'),
                    _ProfileStat(
                      value: '${sampleProjects.length}',
                      label: 'Projects',
                    ),
                    _ProfileStat(value: '$paintCount', label: 'Paints owned'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...PaintbenchTheme.values.map(
            (theme) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThemeOption(
                theme: theme,
                selected: theme == _selectedTheme,
                onTap: () => _selectTheme(theme),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const _ProfileOption(
            icon: Icons.brush_outlined,
            label: 'Painting preferences',
          ),
          const _ProfileOption(
            icon: Icons.notifications_none,
            label: 'Notifications',
          ),
          const _ProfileOption(
            icon: Icons.info_outline,
            label: 'About Paintbench',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appPalette.accent,
                    ),
                  )
                : const Icon(Icons.logout),
            label: Text(_isLoggingOut ? 'Signing out...' : 'Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appPalette.accent,
              side: BorderSide(
                color: context.appPalette.accent.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your painting journey starts here.',
              style: TextStyle(
                color: context.appPalette.mutedText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.appPalette.accent,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appPalette.mutedText, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(icon, color: context.appPalette.accent),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: context.appPalette.mutedText),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label will be available in a future step.')),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final PaintbenchTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final currentPalette = context.appPalette;
    return Material(
      color: selected ? currentPalette.elevatedSurface : currentPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? currentPalette.accent : currentPalette.border,
            ),
          ),
          child: Row(
            children: [
              _ThemePreview(palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      theme.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? currentPalette.accent
                    : currentPalette.mutedText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 38,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 24,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: palette.border),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 5,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
