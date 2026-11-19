import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../schemes/painting_scheme_repository.dart';
import 'project_repository.dart';

class ProjectFormDialog extends StatefulWidget {
  const ProjectFormDialog({
    super.key,
    this.project,
    required this.onSave,
    this.schemes = const [],
    this.loadScheme,
    this.onCreateFromScheme,
  });

  final PaintingProject? project;
  final Future<PaintingProject> Function(PaintingProject project) onSave;
  final List<PaintingScheme> schemes;
  final Future<PaintingScheme> Function(String schemeId)? loadScheme;
  final Future<PaintingProject> Function({
    required String name,
    required String subject,
    required String schemeId,
  })?
  onCreateFromScheme;

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late bool _markCompleted;
  PaintingScheme? _selectedScheme;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _nameController = TextEditingController(text: project?.name ?? '');
    _subjectController = TextEditingController(text: project?.subject ?? '');
    _markCompleted = project?.status == ProjectStatus.completed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final project = PaintingProject(
      id: widget.project?.id,
      name: _nameController.text.trim(),
      subject: _subjectController.text.trim(),
      progress: widget.project?.progress ?? 0,
      status: _markCompleted ? ProjectStatus.completed : ProjectStatus.planned,
      icon: widget.project?.icon ?? Icons.shield_outlined,
      colors:
          widget.project?.colors ??
          const [Color(0xFF40536B), Color(0xFF202A38)],
    );

    try {
      final selectedScheme = _selectedScheme;
      final createFromScheme = widget.onCreateFromScheme;
      if (selectedScheme != null && createFromScheme == null) {
        throw StateError('Scheme-based project creation is unavailable.');
      }
      final saved = selectedScheme == null
          ? await widget.onSave(project)
          : await createFromScheme!(
              name: project.name,
              subject: project.subject,
              schemeId: selectedScheme.id,
            );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = projectErrorMessage(error);
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit project' : 'New project'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Project name'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter a project name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _subjectController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Miniature or subject'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter what you are painting.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (!_isEditing) ...[
                  _schemeSelector(),
                  const SizedBox(height: 14),
                ],
                if (_isEditing) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _markCompleted,
                    onChanged: _isSaving
                        ? null
                        : (value) =>
                              setState(() => _markCompleted = value ?? false),
                    title: const Text('Mark as completed'),
                    subtitle: const Text(
                      'Planned and in-progress statuses follow your completed steps.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: context.appPalette.accent,
            foregroundColor: context.appPalette.onAccent,
          ),
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appPalette.onAccent,
                  ),
                )
              : Text(_isEditing ? 'Save changes' : 'Create project'),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: context.appPalette.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Widget _schemeSelector() {
    final selected = _selectedScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Painting scheme (optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (selected == null)
          OutlinedButton.icon(
            onPressed: _isSaving || widget.schemes.isEmpty
                ? null
                : _chooseScheme,
            icon: const Icon(Icons.palette_outlined),
            label: Text(
              widget.schemes.isEmpty
                  ? 'No saved schemes'
                  : 'Choose a painting scheme',
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _schemeImage(selected.previewUrl, 54),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${selected.stepCount ?? selected.steps.length} steps',
                        style: TextStyle(color: context.appPalette.mutedText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Preview scheme',
                  onPressed: _previewScheme,
                  icon: const Icon(Icons.visibility_outlined),
                ),
                IconButton(
                  tooltip: 'Remove scheme',
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _selectedScheme = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (selected == null && widget.schemes.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isSaving ? null : _chooseScheme,
              child: const Text('Browse and preview schemes'),
            ),
          ),
      ],
    );
  }

  Future<void> _chooseScheme() async {
    final scheme = await showDialog<PaintingScheme>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose painting scheme'),
        content: SizedBox(
          width: 440,
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ListView.builder(
            itemCount: widget.schemes.length,
            itemBuilder: (context, index) {
              final scheme = widget.schemes[index];
              return ListTile(
                leading: _schemeImage(scheme.previewUrl, 48),
                title: Text(scheme.name),
                subtitle: Text(
                  '${scheme.stepCount ?? 0} steps'
                  '${scheme.description?.isNotEmpty == true ? ' • ${scheme.description}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Preview ${scheme.name}',
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => _previewScheme(scheme),
                ),
                onTap: () => Navigator.pop(context, scheme),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (scheme != null && mounted) {
      setState(() => _selectedScheme = scheme);
    }
  }

  Future<void> _previewScheme([PaintingScheme? scheme]) async {
    final selected = scheme ?? _selectedScheme;
    if (selected == null || widget.loadScheme == null) return;
    try {
      final detailed = await widget.loadScheme!(selected.id);
      if (!mounted) return;
      final useScheme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(detailed.name),
          content: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detailed.previewUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      detailed.previewUrl!,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _schemeImage(null, 130),
                    ),
                  ),
                if (detailed.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(detailed.description!),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final step in detailed.steps)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(step.title),
                          subtitle: Text(
                            step.description.isEmpty
                                ? step.paints
                                      .map((paint) => paint.name)
                                      .join(', ')
                                : step.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use this scheme'),
            ),
          ],
        ),
      );
      if (useScheme == true && mounted) {
        setState(() => _selectedScheme = selected);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = paintingSchemeErrorMessage(error));
      }
    }
  }

  Widget _schemeImage(String? url, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: url == null
          ? ColoredBox(
              color: context.appPalette.elevatedSurface,
              child: Icon(
                Icons.palette_outlined,
                color: context.appPalette.accent,
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.appPalette.elevatedSurface,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
    ),
  );
}
