import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';

class SchemeStepFormDialog extends StatefulWidget {
  const SchemeStepFormDialog({super.key, this.step, required this.onSave});

  final PaintingSchemeStep? step;
  final Future<void> Function(String title, String description) onSave;

  @override
  State<SchemeStepFormDialog> createState() => _SchemeStepFormDialogState();
}

class _SchemeStepFormDialogState extends State<SchemeStepFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.step?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.step == null ? 'Add scheme step' : 'Edit scheme step'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Step name'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a step name.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Instructions and techniques'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save step'),
      ),
    ],
  );

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
