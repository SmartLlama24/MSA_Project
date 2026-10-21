import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'project_repository.dart';

class ProjectFormDialog extends StatefulWidget {
  const ProjectFormDialog({super.key, this.project, required this.onSave});

  final PaintingProject? project;
  final Future<PaintingProject> Function(PaintingProject project) onSave;

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late ProjectStatus _status;
  late double _progress;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _nameController = TextEditingController(text: project?.name ?? '');
    _subjectController = TextEditingController(text: project?.subject ?? '');
    _status = project?.status ?? ProjectStatus.planned;
    _progress = project?.progress ?? 0;
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
      progress: _progress,
      status: _status,
      icon: widget.project?.icon ?? Icons.shield_outlined,
      colors:
          widget.project?.colors ??
          const [Color(0xFF40536B), Color(0xFF202A38)],
    );

    try {
      final saved = await widget.onSave(project);
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
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: _status,
                  decoration: _decoration('Status'),
                  items: const [
                    DropdownMenuItem(
                      value: ProjectStatus.planned,
                      child: Text('Planned'),
                    ),
                    DropdownMenuItem(
                      value: ProjectStatus.inProgress,
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(
                      value: ProjectStatus.completed,
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _status = value);
                        },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress'),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _progress,
                  divisions: 20,
                  activeColor: AppTheme.accent,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _progress = value),
                ),
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
            backgroundColor: AppTheme.accent,
            foregroundColor: const Color(0xFF201B12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF201B12),
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
    fillColor: AppTheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
