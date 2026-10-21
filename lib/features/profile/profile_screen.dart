import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';
import '../auth/auth_error_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.email, required this.onLogout});

  final String email;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppTheme.elevatedSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.accent,
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : const Icon(Icons.logout),
            label: Text(_isLoggingOut ? 'Signing out...' : 'Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Your painting journey starts here.',
              style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
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
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 10),
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
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.mutedText),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label will be available in a future step.')),
        );
      },
    );
  }
}
