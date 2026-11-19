import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../../widgets/painting_step_paints.dart';
import '../paints/paint_repository.dart';
import '../projects/step_paint_picker_dialog.dart';
import 'painting_scheme_repository.dart';
import 'scheme_step_form_dialog.dart';

class PaintingSchemeDetailsScreen extends StatefulWidget {
  const PaintingSchemeDetailsScreen({
    super.key,
    required this.scheme,
    required this.repository,
    required this.paintRepository,
  });

  final PaintingScheme scheme;
  final PaintingSchemeRepository repository;
  final PaintRepository paintRepository;

  @override
  State<PaintingSchemeDetailsScreen> createState() =>
      _PaintingSchemeDetailsScreenState();
}

class _PaintingSchemeDetailsScreenState
    extends State<PaintingSchemeDetailsScreen> {
  late PaintingScheme _scheme;
  bool _isLoading = true;
  bool _isReordering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scheme = widget.scheme;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final scheme = await widget.repository.getScheme(_scheme.id);
      if (!mounted) return;
      setState(() {
        _scheme = scheme;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = paintingSchemeErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _editStep([PaintingSchemeStep? step]) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SchemeStepFormDialog(
        step: step,
        onSave: (title, description) async {
          if (step == null) {
            await widget.repository.createStep(
              schemeId: _scheme.id,
              title: title,
              description: description,
            );
          } else {
            await widget.repository.updateStep(
              PaintingSchemeStep(
                id: step.id,
                schemeId: step.schemeId,
                stepOrder: step.stepOrder,
                title: title,
                description: description,
                paints: step.paints,
              ),
            );
          }
        },
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _editPaints(PaintingSchemeStep step) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => StepPaintPickerDialog(
        stepTitle: step.title,
        selectedPaints: step.paints,
        paintRepository: widget.paintRepository,
        onSave: (paints) => widget.repository.setStepPaints(step, paints),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _deleteStep(PaintingSchemeStep step) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete step?'),
        content: Text('Delete "${step.title}" from this scheme?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.repository.deleteStep(step);
      if (mounted) await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_isReordering ||
        oldIndex < 0 ||
        oldIndex >= _scheme.steps.length ||
        newIndex < 0 ||
        newIndex >= _scheme.steps.length ||
        oldIndex == newIndex) {
      return;
    }

    final originalSteps = _scheme.steps;
    final steps = [..._scheme.steps];
    final step = steps.removeAt(oldIndex);
    // onReorderItem already adjusts newIndex when moving an item downward.
    steps.insert(newIndex, step);
    final reorderedSteps = [
      for (var index = 0; index < steps.length; index++)
        PaintingSchemeStep(
          id: steps[index].id,
          schemeId: steps[index].schemeId,
          stepOrder: index + 1,
          title: steps[index].title,
          description: steps[index].description,
          paints: steps[index].paints,
        ),
    ];
    setState(() {
      _isReordering = true;
      _scheme = _scheme.copyWith(steps: reorderedSteps);
    });
    try {
      await widget.repository.reorderSteps(
        _scheme.id,
        reorderedSteps.map((step) => step.id).toList(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _scheme = _scheme.copyWith(steps: originalSteps));
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(paintingSchemeErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_scheme.name)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editStep(),
      icon: const Icon(Icons.add),
      label: const Text('Add step'),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : _buildDetails(),
  );

  Widget _buildDetails() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_scheme.previewUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      _scheme.previewUrl!,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _previewPlaceholder(),
                    ),
                  )
                else
                  _previewPlaceholder(),
                const SizedBox(height: 16),
                if (_scheme.description?.isNotEmpty == true)
                  Text(
                    _scheme.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 16),
                Text(
                  '${_scheme.steps.length} ${_scheme.steps.length == 1 ? 'step' : 'steps'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Drag to reorder. Paint ownership is shown for reference only.',
                  style: TextStyle(color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
        ),
        if (_scheme.steps.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No steps yet. Add the first step.')),
          )
        else
          SliverReorderableList(
            itemCount: _scheme.steps.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final step = _scheme.steps[index];
              return _SchemeStepCard(
                key: ValueKey(step.id),
                step: step,
                index: index,
                canReorder: !_isReordering,
                onEdit: () => _editStep(step),
                onDelete: () => _deleteStep(step),
                onEditPaints: () => _editPaints(step),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _previewPlaceholder() => Container(
    height: 190,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Icon(Icons.palette_outlined, color: AppTheme.accent, size: 44),
  );
}

class _SchemeStepCard extends StatelessWidget {
  const _SchemeStepCard({
    super.key,
    required this.step,
    required this.index,
    required this.canReorder,
    required this.onEdit,
    required this.onDelete,
    required this.onEditPaints,
  });

  final PaintingSchemeStep step;
  final int index;
  final bool canReorder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditPaints;

  @override
  Widget build(BuildContext context) => Card(
    key: key,
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    color: AppTheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                enabled: canReorder,
                child: const Icon(Icons.drag_handle, color: AppTheme.mutedText),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 15,
                backgroundColor: AppTheme.elevatedSurface,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit step')),
                  PopupMenuItem(value: 'delete', child: Text('Delete step')),
                ],
              ),
            ],
          ),
          if (step.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(step.description),
          ],
          const SizedBox(height: 12),
          PaintingStepPaints(paints: step.paints, onEdit: onEditPaints),
        ],
      ),
    ),
  );
}
