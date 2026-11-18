import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../paints/paint_repository.dart';
import 'project_repository.dart';

class StepPaintPickerDialog extends StatefulWidget {
  const StepPaintPickerDialog({
    super.key,
    required this.step,
    required this.paintRepository,
    required this.onSave,
  });

  final ProjectStep step;
  final PaintRepository paintRepository;
  final Future<void> Function(List<CatalogPaint> paints) onSave;

  @override
  State<StepPaintPickerDialog> createState() => _StepPaintPickerDialogState();
}

class _StepPaintPickerDialogState extends State<StepPaintPickerDialog> {
  final _searchController = TextEditingController();
  late final Set<String> _selectedIds;
  List<CatalogPaint> _paints = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.step.paints.map((paint) => paint.id).toSet();
    _loadPaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final paints = await widget.paintRepository.getCatalogPaints();
      if (!mounted) return;
      setState(() {
        _paints = paints;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = paintRepositoryErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _paints.where((paint) => _selectedIds.contains(paint.id)).toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = projectDetailsErrorMessage(error);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filteredPaints = _paints.where((paint) {
      return paint.name.toLowerCase().contains(query) ||
          (paint.brandName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return AlertDialog(
      title: Text('Paints for ${widget.step.title}'),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search paints or brands',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildPaintList(filteredPaints)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving || _isLoading || _error != null ? null : _save,
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
              : const Text('Save paints'),
        ),
      ],
    );
  }

  Widget _buildPaintList(List<CatalogPaint> paints) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadPaints,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_paints.isEmpty) {
      return const Center(child: Text('The paint catalog is empty.'));
    }
    if (paints.isEmpty) {
      return const Center(child: Text('No paints match your search.'));
    }
    return ListView.builder(
      itemCount: paints.length,
      itemBuilder: (context, index) {
        final paint = paints[index];
        final color = paint.color;
        return CheckboxListTile(
          value: _selectedIds.contains(paint.id),
          onChanged: _isSaving
              ? null
              : (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(paint.id);
                    } else {
                      _selectedIds.remove(paint.id);
                    }
                  });
                },
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(paint.name),
          subtitle: Text(paint.brandName ?? 'Unknown brand'),
          secondary: color == null
              ? null
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
        );
      },
    );
  }
}
