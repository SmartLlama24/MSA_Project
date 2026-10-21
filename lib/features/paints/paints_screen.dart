import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';

class PaintsScreen extends StatefulWidget {
  const PaintsScreen({super.key});

  @override
  State<PaintsScreen> createState() => _PaintsScreenState();
}

class _PaintsScreenState extends State<PaintsScreen> {
  PaintStatus? _filter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final paints = samplePaints.where((paint) {
      final matchesFilter = _filter == null || paint.status == _filter;
      final matchesQuery =
          query.isEmpty ||
          paint.name.toLowerCase().contains(query) ||
          paint.brand.toLowerCase().contains(query) ||
          paint.type.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Paints', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Your color library, all in one place.'),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search paints',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == null,
                onSelected: () => setState(() => _filter = null),
              ),
              _FilterChip(
                label: 'Owned',
                selected: _filter == PaintStatus.owned,
                onSelected: () => setState(() => _filter = PaintStatus.owned),
              ),
              _FilterChip(
                label: 'Wanted',
                selected: _filter == PaintStatus.wanted,
                onSelected: () => setState(() => _filter = PaintStatus.wanted),
              ),
              _FilterChip(
                label: 'Missing',
                selected: _filter == PaintStatus.missing,
                onSelected: () => setState(() => _filter = PaintStatus.missing),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${paints.length} ${paints.length == 1 ? 'paint' : 'paints'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final paint in paints) ...[
            _PaintTile(paint: paint),
            const SizedBox(height: 10),
          ],
          if (paints.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No paints match this search.',
                  style: TextStyle(color: AppTheme.mutedText),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF201B12) : AppTheme.mutedText,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }
}

class _PaintTile extends StatelessWidget {
  const _PaintTile({required this.paint});

  final PaintEntry paint;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (paint.status) {
      PaintStatus.owned => 'OWNED',
      PaintStatus.wanted => 'WANTED',
      PaintStatus.missing => 'MISSING',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: paint.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.opacity, color: Colors.white70, size: 19),
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
                const SizedBox(height: 4),
                Text(
                  '${paint.brand}  ·  ${paint.type}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
