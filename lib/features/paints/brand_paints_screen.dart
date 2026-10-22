import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'paint_repository.dart';
import 'paint_status_sheet.dart';

enum _PaintFilter { all, owned, wanted, unowned }

class BrandPaintsScreen extends StatefulWidget {
  const BrandPaintsScreen({
    super.key,
    required this.brand,
    required this.repository,
  });

  final PaintBrand brand;
  final PaintRepository repository;

  @override
  State<BrandPaintsScreen> createState() => _BrandPaintsScreenState();
}

class _BrandPaintsScreenState extends State<BrandPaintsScreen> {
  final _searchController = TextEditingController();
  List<CatalogPaint> _paints = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  _PaintFilter _filter = _PaintFilter.all;

  @override
  void initState() {
    super.initState();
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
      final paints = await widget.repository.getPaintsForBrand(widget.brand.id);
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

  Future<void> _changeStatus(
    CatalogPaint paint,
    PaintOwnershipStatus status,
  ) async {
    await widget.repository.setPaintStatus(paint.id, status);
    if (!mounted) return;
    setState(() {
      final index = _paints.indexWhere((item) => item.id == paint.id);
      if (index != -1) _paints[index] = _paints[index].withUserStatus(status);
    });
  }

  Future<void> _openPaintStatus(CatalogPaint paint) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PaintStatusSheet(
        paint: paint,
        onSave: (status) => _changeStatus(paint, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = _paints.where((paint) {
      final matchesSearch =
          paint.name.toLowerCase().contains(query) ||
          (paint.paintType?.toLowerCase().contains(query) ?? false);
      final matchesFilter = switch (_filter) {
        _PaintFilter.all => true,
        _PaintFilter.owned => paint.userStatus == PaintOwnershipStatus.owned,
        _PaintFilter.wanted => paint.userStatus == PaintOwnershipStatus.wanted,
        _PaintFilter.unowned =>
          paint.userStatus == PaintOwnershipStatus.unowned,
      };
      return matchesSearch && matchesFilter;
    }).toList()..sort(_comparePaintHexColors);

    return Scaffold(
      appBar: AppBar(title: Text(widget.brand.name)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.brand.name} paints',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _buildFilters(),
            Expanded(child: _buildPaintList(filtered)),
          ],
        ),
      ),
    );
  }

  int _comparePaintHexColors(CatalogPaint first, CatalogPaint second) {
    final firstHex = first.hexColor?.trim().replaceFirst('#', '').toUpperCase();
    final secondHex = second.hexColor
        ?.trim()
        .replaceFirst('#', '')
        .toUpperCase();
    if (firstHex == null || firstHex.isEmpty) {
      return secondHex == null || secondHex.isEmpty ? 0 : 1;
    }
    if (secondHex == null || secondHex.isEmpty) return -1;
    return firstHex.compareTo(secondHex);
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          _filterChip(_PaintFilter.all, 'All paints'),
          const SizedBox(width: 8),
          _filterChip(_PaintFilter.owned, 'Owned'),
          const SizedBox(width: 8),
          _filterChip(_PaintFilter.wanted, 'Wanted'),
          const SizedBox(width: 8),
          _filterChip(_PaintFilter.unowned, 'Unowned'),
        ],
      ),
    );
  }

  Widget _filterChip(_PaintFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: _filter == filter ? const Color(0xFF201B12) : AppTheme.mutedText,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget _buildPaintList(List<CatalogPaint> filtered) {
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
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadPaints,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_paints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.format_paint_outlined,
                color: AppTheme.accent,
                size: 40,
              ),
              const SizedBox(height: 14),
              Text(
                'No paints for ${widget.brand.name}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'This brand does not have any catalog paints yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No paints match this search and filter.',
          style: TextStyle(color: AppTheme.mutedText),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaints,
      color: AppTheme.accent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        itemCount: filtered.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PaintTile(
            paint: filtered[index],
            onTap: () => _openPaintStatus(filtered[index]),
          ),
        ),
      ),
    );
  }
}

class _PaintTile extends StatelessWidget {
  const _PaintTile({required this.paint, required this.onTap});

  final CatalogPaint paint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = paint.color;
    final type = paint.paintType?.trim();
    final hex = paint.hexColor?.trim();
    final statusLabel = switch (paint.userStatus) {
      PaintOwnershipStatus.owned => 'OWNED',
      PaintOwnershipStatus.wanted => 'WANTED',
      PaintOwnershipStatus.unowned => 'UNOWNED',
    };
    final subtitleParts = [
      if (type != null && type.isNotEmpty) type,
      if (hex != null && parsePaintColor(hex) != null) hex.toUpperCase(),
    ];

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color ?? AppTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paint.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join('  ·  '),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppTheme.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  color: paint.userStatus == PaintOwnershipStatus.unowned
                      ? AppTheme.mutedText
                      : AppTheme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
