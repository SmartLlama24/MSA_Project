import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'painting_scheme_repository.dart';

class PaintingSchemeFormScreen extends StatefulWidget {
  const PaintingSchemeFormScreen({
    super.key,
    required this.repository,
    required this.previewPicker,
    this.scheme,
  });

  final PaintingSchemeRepository repository;
  final SchemePreviewPicker previewPicker;
  final PaintingScheme? scheme;

  @override
  State<PaintingSchemeFormScreen> createState() =>
      _PaintingSchemeFormScreenState();
}

class _PaintingSchemeFormScreenState extends State<PaintingSchemeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  XFile? _previewImage;
  bool _removePreview = false;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.scheme != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.scheme?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.scheme?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _choosePreview() async {
    try {
      final image = await widget.previewPicker.pickPreviewImage();
      if (mounted && image != null) {
        setState(() {
          _previewImage = image;
          _removePreview = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = paintingSchemeErrorMessage(error));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final scheme = widget.scheme;
      final saved = scheme == null
          ? await widget.repository.createScheme(
              name: _nameController.text,
              description: _descriptionController.text,
              previewImage: _previewImage,
            )
          : await widget.repository.updateScheme(
              scheme: scheme,
              name: _nameController.text,
              description: _descriptionController.text,
              previewImage: _previewImage,
              removePreview: _removePreview,
            );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = paintingSchemeErrorMessage(error);
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Edit painting scheme' : 'New painting scheme'),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Scheme name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a scheme name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Description (optional)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Preview image', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _preview(),
          Row(
            children: [
              TextButton.icon(
                onPressed: _isSaving ? null : _choosePreview,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _previewImage == null && widget.scheme?.previewUrl == null
                      ? 'Choose image'
                      : 'Change image',
                ),
              ),
              if (_previewImage != null ||
                  (widget.scheme?.previewUrl != null && !_removePreview))
                TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                          _previewImage = null;
                          _removePreview = true;
                        }),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF201B12),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save changes' : 'Create scheme'),
          ),
        ],
      ),
    ),
  );

  Widget _preview() {
    if (_previewImage case final image?) {
      return FutureBuilder(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _imageBox(
              const Text('Could not read the selected preview image.'),
            );
          }
          return _imageBox(
            snapshot.hasData
                ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                : const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    final url = _removePreview ? null : widget.scheme?.previewUrl;
    if (url != null) {
      return _imageBox(
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_outlined, size: 40),
        ),
      );
    }
    return _imageBox(
      const Icon(Icons.palette_outlined, color: AppTheme.accent, size: 42),
    );
  }

  Widget _imageBox(Widget child) => Container(
    height: 190,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Center(child: child),
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
