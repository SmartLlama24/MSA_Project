import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../projects/project_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onCreateProject,
    required this.onOpenProject,
    required this.projectRepository,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onCreateProject;
  final ValueChanged<PaintingProject> onOpenProject;
  final ProjectRepository projectRepository;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<PaintingProject> _recentProjects = [];
  bool _isLoadingProjects = true;
  String? _projectsError;

  @override
  void initState() {
    super.initState();
    loadRecentProjects();
  }

  Future<void> loadRecentProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsError = null;
    });
    try {
      final projects = await widget.projectRepository.getRecentProjects();
      if (!mounted) return;
      setState(() {
        _recentProjects = projects;
        _isLoadingProjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _projectsError = projectErrorMessage(error);
        _isLoadingProjects = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAINTBENCH',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Good evening, painter',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(Icons.brush_outlined, color: AppTheme.accent),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _WorkshopCard(onCreateProject: widget.onCreateProject),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent projects',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () => widget.onNavigate(1),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._buildRecentProjects(context),
          const SizedBox(height: 14),
          _QuickAction(
            icon: Icons.palette_outlined,
            title: 'Browse your paints',
            subtitle: 'Check your collection and wishlist',
            onTap: () => widget.onNavigate(2),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentProjects(BuildContext context) {
    if (_isLoadingProjects) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
      ];
    }

    if (_projectsError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                _projectsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.mutedText),
              ),
              TextButton.icon(
                onPressed: loadRecentProjects,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ];
    }

    if (_recentProjects.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Your recent projects will appear here.',
            style: TextStyle(color: AppTheme.mutedText),
          ),
        ),
      ];
    }

    return [
      for (final project in _recentProjects) ...[
        ProjectPreviewCard(
          project: project,
          onTap: () => widget.onOpenProject(project),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF39352D), Color(0xFF242321)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'YOUR WORKSHOP',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Every great mini\nstarts with a first coat.',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 23, height: 1.2),
          ),
          const SizedBox(height: 10),
          const Text('Make space for your next masterpiece.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add, size: 19),
            label: const Text('New project'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF201B12),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectPreviewCard extends StatelessWidget {
  const ProjectPreviewCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  final PaintingProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = project.progress;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: project.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(project.icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppTheme.mutedText),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppTheme.elevatedSurface,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: AppTheme.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
