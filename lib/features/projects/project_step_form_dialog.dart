import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'project_repository.dart';

class ProjectStepFormDialog extends StatefulWidget {
  const ProjectStepFormDialog({super.key, this.step, required this.onSave});

  final ProjectStep? step;
  final Future<ProjectStep> Function(String title, String instructions) onSave;

  @override
  State<ProjectStepFormDialog> createState() => _ProjectStepFormDialogState();
}

class _ProjectStepFormDialogState extends State<ProjectStepFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _instructionsController;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.step != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step?.title ?? '');
    _instructionsController = TextEditingController(
      text: widget.step?.instructions ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final saved = await widget.onSave(
        _titleController.text.trim(),
        _instructionsController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = projectDetailsErrorMessage(error);
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit step' : 'Add painting step'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  const Text(
                    'New steps are added to the end. Reorder them from the step list.',
                    style: TextStyle(color: AppTheme.mutedText),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Step title'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a step title.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _instructionsController,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Instructions or notes'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter instructions or notes.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
              : Text(_isEditing ? 'Save changes' : 'Add step'),
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
