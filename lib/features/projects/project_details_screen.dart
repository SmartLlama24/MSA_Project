import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'project_form_dialog.dart';
import 'project_repository.dart';
import 'project_step_form_dialog.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.project,
    required this.repository,
  });

  final PaintingProject project;
  final ProjectRepository repository;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late PaintingProject _project;
  List<ProjectStep> _steps = [];
  bool _isLoading = true;
  String? _error;

  String? get _projectId => _project.id;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadProject();
  }

  Future<void> _loadProject() async {
    final projectId = _projectId;
    if (projectId == null) {
      setState(() {
        _error = 'This project does not have a valid ID.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final project = await widget.repository.getProject(projectId);
      final steps = await widget.repository.getProjectSteps(projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _steps = [...steps]..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = projectDetailsErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _addStep() async {
    final projectId = _projectId;
    if (projectId == null) return;

    final step = await showDialog<ProjectStep>(
      context: context,
      builder: (_) => ProjectStepFormDialog(
        onSave: (title, instructions) => widget.repository.createProjectStep(
          projectId: projectId,
          title: title,
          instructions: instructions,
        ),
      ),
    );
    if (step != null) await _loadProject();
  }

  Future<void> _editProject() async {
    final updated = await showDialog<PaintingProject>(
      context: context,
      builder: (_) => ProjectFormDialog(
        project: _project,
        onSave: widget.repository.updateProject,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _project = updated);
    await _loadProject();
  }

  Future<void> _editStep(ProjectStep step) async {
    final updated = await showDialog<ProjectStep>(
      context: context,
      builder: (_) => ProjectStepFormDialog(
        step: step,
        onSave: (title, instructions) => widget.repository.updateProjectStep(
          ProjectStep(
            id: step.id,
            projectId: step.projectId,
            stepOrder: step.stepOrder,
            title: title,
            instructions: instructions,
          ),
        ),
      ),
    );
    if (updated != null) await _loadProject();
  }

  Future<void> _deleteStep(ProjectStep step) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete step?'),
        content: Text('Delete "${step.title}"? This cannot be undone.'),
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
      await widget.repository.deleteProjectStep(step);
      await _loadProject();
    } catch (error) {
      _showError(projectDetailsErrorMessage(error));
    }
  }

  Future<void> _moveStep(int index, int direction) async {
    final projectId = _projectId;
    if (projectId == null) return;

    final reorderedSteps = [..._steps];
    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= reorderedSteps.length) return;
    final movedStep = reorderedSteps.removeAt(index);
    reorderedSteps.insert(targetIndex, movedStep);
    final orderedStepIds = reorderedSteps.map((step) => step.id).toList();
    if (orderedStepIds.any((id) => id == null)) {
      _showError('Could not reorder a step without a saved ID.');
      return;
    }

    try {
      await widget.repository.reorderProjectSteps(
        projectId,
        orderedStepIds.whereType<String>().toList(),
      );
      await _loadProject();
    } catch (error) {
      _showError(projectDetailsErrorMessage(error));
      await _loadProject();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_project.status) {
      ProjectStatus.inProgress => 'In progress',
      ProjectStatus.planned => 'Planned',
      ProjectStatus.completed => 'Completed',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_project.name),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            onPressed: _isLoading || _error != null ? null : _editProject,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadProject,
              color: AppTheme.accent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildProjectSummary(status),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Painting steps',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                        label: const Text('Add step'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF201B12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_steps.isEmpty)
                    _buildEmptySteps()
                  else
                    ..._steps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StepCard(
                          step: entry.value,
                          stepNumber: entry.key + 1,
                          canMoveUp: entry.key > 0,
                          canMoveDown: entry.key < _steps.length - 1,
                          onMoveUp: () => _moveStep(entry.key, -1),
                          onMoveDown: () => _moveStep(entry.key, 1),
                          onEdit: () => _editStep(entry.value),
                          onDelete: () => _deleteStep(entry.value),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildError() => Center(
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
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildProjectSummary(String status) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _project.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Icon(_project.icon, color: Colors.white, size: 60),
        ),
      ),
      const SizedBox(height: 20),
      Text(_project.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(_project.subject, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(status, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${(_project.progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _project.progress,
                minHeight: 7,
                backgroundColor: AppTheme.elevatedSurface,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Progress remains the manually set project percentage.',
              style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildEmptySteps() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      children: [
        Icon(Icons.format_list_numbered, color: AppTheme.accent, size: 36),
        SizedBox(height: 12),
        Text(
          'No painting steps yet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'Add your first step to plan this miniature’s painting process.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedText),
        ),
      ],
    ),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.stepNumber,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectStep step;
  final int stepNumber;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$stepNumber',
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(step.instructions),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Step actions',
          onSelected: (action) {
            if (action == 'edit') onEdit();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        Column(
          children: [
            IconButton(
              tooltip: 'Move step up',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move step down',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ],
    ),
  );
}
