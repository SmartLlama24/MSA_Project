import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../projects/project_photo_repository.dart';
import '../projects/project_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onCreateProject,
    required this.onOpenProject,
    required this.projectRepository,
    this.photoRepository,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onCreateProject;
  final ValueChanged<PaintingProject> onOpenProject;
  final ProjectRepository projectRepository;
  final ProjectPhotoRepository? photoRepository;

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
      var projects = await widget.projectRepository.getRecentProjects();
      final photoRepository = widget.photoRepository;
      if (photoRepository != null) {
        projects = await Future.wait(
          projects.map((project) async {
            final photoId = project.coverPhotoId;
            if (photoId == null) return project;
            final url = await photoRepository.getSignedUrlForPhoto(photoId);
            return project.copyWith(coverPhotoUrl: url);
          }),
        );
      }
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
    final currentProject = _recentProjects.isEmpty
        ? null
        : _recentProjects.first;
    final otherProjects = _recentProjects.length < 2
        ? const <PaintingProject>[]
        : _recentProjects.skip(1).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAINTBENCH  /  YOUR WORKSPACE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.25,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.subtleBorder),
                ),
                child: const Icon(
                  Icons.brush_outlined,
                  color: AppTheme.accent,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionHeading(title: 'CURRENT PROJECT'),
          const SizedBox(height: 8),
          if (_isLoadingProjects)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 54),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            )
          else if (_projectsError != null)
            _ProjectLoadError(
              message: _projectsError!,
              onRetry: loadRecentProjects,
            )
          else if (currentProject == null)
            _EmptyWorkbench(onCreateProject: widget.onCreateProject)
          else
            _CurrentProjectFeature(
              project: currentProject,
              onTap: () => widget.onOpenProject(currentProject),
            ),
          const SizedBox(height: 14),
          _SectionHeading(
            title: 'RECENT PROJECTS',
            action: TextButton(
              onPressed: () => widget.onNavigate(1),
              child: const Text('All projects'),
            ),
          ),
          const SizedBox(height: 4),
          if (!_isLoadingProjects &&
              _projectsError == null &&
              otherProjects.isNotEmpty)
            ...otherProjects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProjectPreviewCard(
                  project: project,
                  onTap: () => widget.onOpenProject(project),
                ),
              ),
            )
          else if (!_isLoadingProjects &&
              _projectsError == null &&
              currentProject != null)
            const Text(
              'Your next miniature starts here.',
              style: TextStyle(color: AppTheme.mutedText),
            ),
          const SizedBox(height: 24),
          const _SectionHeading(title: 'QUICK ACCESS'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickAccess(
                  icon: Icons.palette_outlined,
                  label: 'Paint collection',
                  onTap: () => widget.onNavigate(2),
                ),
              ),
              Expanded(
                child: _QuickAccess(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Painting schemes',
                  onTap: () => widget.onNavigate(3),
                ),
              ),
              Expanded(
                child: _QuickAccess(
                  icon: Icons.add_circle_outline,
                  label: 'New project',
                  onTap: widget.onCreateProject,
                  highlighted: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _ProjectLoadError extends StatelessWidget {
  const _ProjectLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.subtleBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: AppTheme.mutedText)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _EmptyWorkbench extends StatelessWidget {
  const _EmptyWorkbench({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.subtleBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.model_training_outlined, color: AppTheme.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your desk is clear',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Start a project to track your next miniature.',
                style: TextStyle(color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCreateProject,
          tooltip: 'New project',
          color: AppTheme.accent,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class _CurrentProjectFeature extends StatelessWidget {
  const _CurrentProjectFeature({required this.project, required this.onTap});

  final PaintingProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = project.totalStepCount == 0
        ? 0.0
        : project.completedStepCount / project.totalStepCount;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.subtleBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3.2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProjectArtwork(project: project),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.68),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _ProjectStatus(status: project.status),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            project.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE6E2DB),
                              fontSize: 12,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(progress * 100).round()}% complete',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
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
                        const SizedBox(width: 14),
                        Text(
                          '${project.completedStepCount}/${project.totalStepCount}',
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.brush_outlined, size: 18),
                        label: const Text('Continue painting'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectArtwork extends StatelessWidget {
  const _ProjectArtwork({required this.project});

  final PaintingProject project;

  @override
  Widget build(BuildContext context) {
    final photoUrl = project.coverPhotoUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: project.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: photoUrl == null
          ? Center(
              child: Icon(
                project.icon,
                size: 64,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            )
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  project.icon,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
    );
  }
}

class _ProjectStatus extends StatelessWidget {
  const _ProjectStatus({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ProjectStatus.inProgress => 'IN PROGRESS',
      ProjectStatus.planned => 'ON THE DESK',
      ProjectStatus.completed => 'COMPLETED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
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
    final progress = project.totalStepCount == 0
        ? 0.0
        : project.completedStepCount / project.totalStepCount;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.subtleBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ProjectArtwork(project: project),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      project.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppTheme.elevatedSurface,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${project.completedStepCount}/${project.totalStepCount}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: highlighted ? AppTheme.elevatedSurface : AppTheme.surface,
              border: Border.all(
                color: highlighted
                    ? AppTheme.accent.withValues(alpha: 0.38)
                    : AppTheme.subtleBorder,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: highlighted ? AppTheme.accent : AppTheme.primaryText,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}
