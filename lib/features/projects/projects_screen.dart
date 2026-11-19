import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../paints/paint_repository.dart';
import 'project_details_screen.dart';
import 'project_form_dialog.dart';
import 'project_photo_repository.dart';
import 'project_repository.dart';
import '../schemes/painting_scheme_repository.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    this.repository,
    this.paintRepository,
    this.photoRepository,
    this.schemeRepository,
  });

  final ProjectRepository? repository;
  final PaintRepository? paintRepository;
  final ProjectPhotoRepository? photoRepository;
  final PaintingSchemeRepository? schemeRepository;

  @override
  ProjectsScreenState createState() => ProjectsScreenState();
}

class ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectRepository _repository;
  late final PaintRepository _paintRepository;
  late final ProjectPhotoRepository? _photoRepository;
  List<PaintingProject> _projects = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        SupabaseProjectRepository(Supabase.instance.client);
    _paintRepository =
        widget.paintRepository ??
        SupabasePaintRepository(Supabase.instance.client);
    _photoRepository = widget.photoRepository;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var projects = await _repository.getProjects();
      if (widget.photoRepository != null) {
        projects = await Future.wait(
          projects.map((project) async {
            final photoId = project.coverPhotoId;
            if (photoId == null) return project;
            final url = await _photoRepository!.getSignedUrlForPhoto(photoId);
            return project.copyWith(coverPhotoUrl: url);
          }),
        );
      }
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = projectErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> openCreateProject() async {
    final schemeRepository = widget.schemeRepository;
    var schemes = <PaintingScheme>[];
    if (schemeRepository != null) {
      try {
        schemes = await schemeRepository.getSchemes();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(paintingSchemeErrorMessage(error))),
          );
        }
      }
    }
    if (!mounted) return;
    final project = await showDialog<PaintingProject>(
      context: context,
      builder: (_) => ProjectFormDialog(
        onSave: _repository.createProject,
        schemes: schemes,
        loadScheme: schemeRepository?.getScheme,
        onCreateFromScheme: schemeRepository == null
            ? null
            : ({required name, required subject, required schemeId}) async {
                final projectId = await schemeRepository
                    .createProjectFromScheme(
                      name: name,
                      subject: subject,
                      schemeId: schemeId,
                    );
                return _repository.getProject(projectId);
              },
      ),
    );
    if (project != null) await _loadProjects();
  }

  Future<void> _editProject(PaintingProject project) async {
    final updated = await showDialog<PaintingProject>(
      context: context,
      builder: (_) => ProjectFormDialog(
        project: project,
        onSave: _repository.updateProject,
      ),
    );
    if (updated != null) await _loadProjects();
  }

  Future<void> _deleteProject(PaintingProject project) async {
    final projectId = project.id;
    if (projectId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text('Delete "${project.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      final photoRepository = widget.photoRepository;
      if (photoRepository != null) {
        final photos = await photoRepository.getProjectPhotos(projectId);
        for (final photo in photos) {
          await photoRepository.deletePhoto(photo);
        }
      }
      await _repository.deleteProject(projectId);
      await _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Project deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(projectErrorMessage(error))));
      }
    }
  }

  Future<void> _openDetails(PaintingProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailsScreen(
          project: project,
          repository: _repository,
          paintRepository: _paintRepository,
          photoRepository: _photoRepository,
        ),
      ),
    );
    if (mounted) await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projects',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A little progress, one brushstroke at a time.',
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Create project',
                  onPressed: openCreateProject,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    backgroundColor: AppTheme.surface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildProjectList()),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppTheme.mutedText),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadProjects,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.brush_outlined,
                    color: AppTheme.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your workbench is clear',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a project to start tracking your next miniature.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: openCreateProject,
                  icon: const Icon(Icons.add),
                  label: const Text('Create project'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF201B12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: AppTheme.accent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ProjectCard(
              project: project,
              coverPhotoUrl: project.coverPhotoUrl,
              onTap: () => _openDetails(project),
              onEdit: () => _editProject(project),
              onDelete: () => _deleteProject(project),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.coverPhotoUrl,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final PaintingProject project;
  final String? coverPhotoUrl;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = switch (project.status) {
      ProjectStatus.inProgress => 'IN PROGRESS',
      ProjectStatus.planned => 'PLANNED',
      ProjectStatus.completed => 'COMPLETED',
    };
    final stepProgress = project.totalStepCount == 0
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
              SizedBox(
                height: 154,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: project.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: coverPhotoUrl == null
                          ? Center(
                              child: Icon(
                                project.icon,
                                size: 54,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            )
                          : Image.network(
                              coverPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Icon(
                                      project.icon,
                                      size: 54,
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  ),
                            ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 13,
                      right: 56,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white, fontSize: 19),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            project.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE6E2DB),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.36),
                        shape: const CircleBorder(),
                        child: PopupMenuButton<String>(
                          tooltip: 'Project actions',
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                          ),
                          onSelected: (action) {
                            if (action == 'edit') onEdit();
                            if (action == 'delete') onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusLabel(status: status),
                        const Spacer(),
                        Text(
                          '${(stepProgress * 100).round()}%',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${project.completedStepCount}/${project.totalStepCount}',
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stepProgress,
                        minHeight: 5,
                        backgroundColor: AppTheme.elevatedSurface,
                        color: AppTheme.accent,
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
