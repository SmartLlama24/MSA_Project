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
      backgroundColor: context.appPalette.background,
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
    }).toList()..sort(_comparePaintColors);

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
                  fillColor: context.appPalette.surface,
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

  int _comparePaintColors(CatalogPaint first, CatalogPaint second) {
    final firstColor = _PaintColorSortKey.fromHex(first.hexColor);
    final secondColor = _PaintColorSortKey.fromHex(second.hexColor);

    if (firstColor == null || secondColor == null) {
      if (firstColor == null && secondColor != null) return 1;
      if (firstColor != null && secondColor == null) return -1;
      return first.name.compareTo(second.name);
    }

    final categoryComparison = firstColor.category.index.compareTo(
      secondColor.category.index,
    );
    if (categoryComparison != 0) return categoryComparison;

    if (firstColor.category == _PaintColorCategory.neutral) {
      final brightnessComparison = firstColor.value.compareTo(
        secondColor.value,
      );
      if (brightnessComparison != 0) return brightnessComparison;
      final saturationComparison = firstColor.saturation.compareTo(
        secondColor.saturation,
      );
      if (saturationComparison != 0) return saturationComparison;
      return first.name.compareTo(second.name);
    }

    final hueBucketComparison = firstColor.hueBucket.compareTo(
      secondColor.hueBucket,
    );
    if (hueBucketComparison != 0) return hueBucketComparison;

    final saturationComparison = secondColor.saturation.compareTo(
      firstColor.saturation,
    );
    if (saturationComparison != 0) return saturationComparison;

    final brightnessComparison = firstColor.value.compareTo(secondColor.value);
    if (brightnessComparison != 0) return brightnessComparison;

    final hueComparison = firstColor.hue.compareTo(secondColor.hue);
    if (hueComparison != 0) return hueComparison;
    return first.name.compareTo(second.name);
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
      selectedColor: context.appPalette.accent,
      backgroundColor: context.appPalette.surface,
      labelStyle: TextStyle(
        color: _filter == filter
            ? context.appPalette.onAccent
            : context.appPalette.mutedText,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget _buildPaintList(List<CatalogPaint> filtered) {
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
              Icon(
                Icons.format_paint_outlined,
                color: context.appPalette.accent,
                size: 40,
              ),
              const SizedBox(height: 14),
              Text(
                'No paints for ${widget.brand.name}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This brand does not have any catalog paints yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appPalette.mutedText),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No paints match this search and filter.',
          style: TextStyle(color: context.appPalette.mutedText),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaints,
      color: context.appPalette.accent,
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

    final statusColor = switch (paint.userStatus) {
      PaintOwnershipStatus.owned => context.appPalette.accent,
      PaintOwnershipStatus.wanted => const Color(0xFFB7A58B),
      PaintOwnershipStatus.unowned => context.appPalette.mutedText,
    };

    return Material(
      color: context.appPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appPalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color ?? context.appPalette.elevatedSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appPalette.border),
                ),
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                    border: Border.all(
                      color: context.appPalette.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                            ?.copyWith(color: context.appPalette.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.32),
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PaintColorCategory { chromatic, neutral }

class _PaintColorSortKey {
  const _PaintColorSortKey({
    required this.category,
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final _PaintColorCategory category;
  final double hue;
  final double saturation;
  final double value;

  int get hueBucket => ((hue + 30) % 360 / 12).floor();

  static _PaintColorSortKey? fromHex(String? value) {
    final hex = value?.trim().replaceFirst('#', '');
    if (hex == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return null;
    }

    final red = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final green = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final blue = int.parse(hex.substring(4, 6), radix: 16) / 255;
    final maximum = [red, green, blue].reduce((a, b) => a > b ? a : b);
    final minimum = [red, green, blue].reduce((a, b) => a < b ? a : b);
    final delta = maximum - minimum;

    var hue = 0.0;
    if (delta != 0) {
      if (maximum == red) {
        hue = 60 * (((green - blue) / delta) % 6);
      } else if (maximum == green) {
        hue = 60 * ((blue - red) / delta + 2);
      } else {
        hue = 60 * ((red - green) / delta + 4);
      }
      if (hue < 0) hue += 360;
    }

    final saturation = maximum == 0 ? 0.0 : delta / maximum;
    return _PaintColorSortKey(
      category: saturation < 0.12
          ? _PaintColorCategory.neutral
          : _PaintColorCategory.chromatic,
      hue: hue,
      saturation: saturation,
      value: maximum,
    );
  }
}
