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
                  foregroundColor: context.appPalette.accent,
                  backgroundColor: context.appPalette.surface,
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
      return Center(
        child: CircularProgressIndicator(color: context.appPalette.accent),
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
                  Icon(
                    Icons.palette_outlined,
                    color: context.appPalette.accent,
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
                      backgroundColor: context.appPalette.accent,
                      foregroundColor: context.appPalette.onAccent,
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
      color: context.appPalette.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        itemCount: _schemes.length,
        itemBuilder: (context, index) {
          final scheme = _schemes[index];
          return _SchemeRecipeCard(
            scheme: scheme,
            onTap: () => _openDetails(scheme),
            onEdit: () => _openForm(scheme),
            onDuplicate: () => _duplicate(scheme),
            onDelete: () => _delete(scheme),
          );
        },
      ),
    );
  }
}

class _SchemeRecipeCard extends StatelessWidget {
  const _SchemeRecipeCard({
    required this.scheme,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final PaintingScheme scheme;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final paints = {
      for (final paint in scheme.steps.expand((step) => step.paints))
        paint.id: paint,
    }.values.toList();
    final ownedCount = paints
        .where((paint) => paint.userStatus == PaintOwnershipStatus.owned)
        .length;
    final wantedCount = paints
        .where((paint) => paint.userStatus == PaintOwnershipStatus.wanted)
        .length;
    final stepCount = scheme.stepCount ?? scheme.steps.length;
    final photoUrl = scheme.previewUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: context.appPalette.surface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: context.appPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 142,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photoUrl == null)
                        const _SchemePlaceholder()
                      else
                        Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _SchemePlaceholder(),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 56,
                        bottom: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scheme.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (scheme.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                scheme.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE6E2DB),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.36),
                          shape: const CircleBorder(),
                          child: PopupMenuButton<String>(
                            tooltip: 'Scheme actions',
                            icon: const Icon(
                              Icons.more_horiz,
                              color: Colors.white,
                            ),
                            onSelected: (action) {
                              if (action == 'edit') onEdit();
                              if (action == 'duplicate') onDuplicate();
                              if (action == 'delete') onDelete();
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_list_numbered,
                        size: 15,
                        color: context.appPalette.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$stepCount steps',
                        style: TextStyle(
                          color: context.appPalette.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.color_lens_outlined,
                        size: 15,
                        color: context.appPalette.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          paints.isEmpty
                              ? 'No paints added'
                              : '$ownedCount/${paints.length} owned'
                                    '${wantedCount == 0 ? '' : ' · $wantedCount wanted'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appPalette.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (paints.isNotEmpty)
                        _PaintSwatchRow(paints: paints.take(6).toList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemePlaceholder extends StatelessWidget {
  const _SchemePlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          context.appPalette.elevatedSurface,
          context.appPalette.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(
        Icons.palette_outlined,
        color: context.appPalette.accent,
        size: 42,
      ),
    ),
  );
}

class _PaintSwatchRow extends StatelessWidget {
  const _PaintSwatchRow({required this.paints});

  final List<CatalogPaint> paints;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final paint in paints)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: paint.color ?? context.appPalette.elevatedSurface,
              shape: BoxShape.circle,
              border: Border.all(color: context.appPalette.border),
            ),
          ),
        ),
    ],
  );
}
