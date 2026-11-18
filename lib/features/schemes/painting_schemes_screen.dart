import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../paints/paint_repository.dart';
import 'painting_scheme_details_screen.dart';
import 'painting_scheme_form_screen.dart';
import 'painting_scheme_repository.dart';

class PaintingSchemesScreen extends StatefulWidget {
  const PaintingSchemesScreen({
    super.key,
    required this.repository,
    required this.paintRepository,
    required this.previewPicker,
  });

  final PaintingSchemeRepository repository;
  final PaintRepository paintRepository;
  final SchemePreviewPicker previewPicker;

  @override
  State<PaintingSchemesScreen> createState() => _PaintingSchemesScreenState();
}

class _PaintingSchemesScreenState extends State<PaintingSchemesScreen> {
  List<PaintingScheme> _schemes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final schemes = await widget.repository.getSchemes();
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
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

  Future<void> _openForm([PaintingScheme? scheme]) async {
    final result = await Navigator.of(context).push<PaintingScheme>(
      MaterialPageRoute(
        builder: (_) => PaintingSchemeFormScreen(
          repository: widget.repository,
          previewPicker: widget.previewPicker,
          scheme: scheme,
        ),
      ),
    );
    if (result != null && mounted) await _load();
  }

  Future<void> _openDetails(PaintingScheme scheme) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PaintingSchemeDetailsScreen(
          scheme: scheme,
          repository: widget.repository,
          paintRepository: widget.paintRepository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _duplicate(PaintingScheme scheme) async {
    try {
      await widget.repository.duplicateScheme(scheme);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Painting scheme duplicated.')),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(PaintingScheme scheme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete painting scheme?'),
        content: Text(
          'Delete "${scheme.name}"? Projects created from it will not be affected.',
        ),
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
      await widget.repository.deleteScheme(scheme);
      if (mounted) await _load();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(paintingSchemeErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
                      'Painting Schemes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text('Reusable recipes for your next miniature.'),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Create painting scheme',
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  backgroundColor: AppTheme.surface,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _content()),
      ],
    ),
  );

  Widget _content() {
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
              Text(_error!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_schemes.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.palette_outlined,
                    color: AppTheme.accent,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No painting schemes yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a reusable set of steps and paints.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create scheme'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF201B12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        itemCount: _schemes.length,
        itemBuilder: (context, index) {
          final scheme = _schemes[index];
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDetails(scheme),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 110,
                    child: scheme.previewUrl == null
                        ? const ColoredBox(
                            color: AppTheme.elevatedSurface,
                            child: Icon(
                              Icons.palette_outlined,
                              color: AppTheme.accent,
                            ),
                          )
                        : Image.network(
                            scheme.previewUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppTheme.elevatedSurface,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scheme.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (scheme.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              scheme.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.mutedText),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Text(
                            '${scheme.stepCount ?? scheme.steps.length} steps',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Scheme actions',
                    onSelected: (action) {
                      if (action == 'edit') _openForm(scheme);
                      if (action == 'duplicate') _duplicate(scheme);
                      if (action == 'delete') _delete(scheme);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
