import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/models.dart';

class PaintingStepPaints extends StatelessWidget {
  const PaintingStepPaints({
    super.key,
    required this.paints,
    required this.onEdit,
  });

  final List<CatalogPaint> paints;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              paints.isEmpty ? 'No paints associated' : 'Paints',
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              paints.isEmpty ? Icons.add : Icons.palette_outlined,
              size: 18,
            ),
            label: Text(paints.isEmpty ? 'Add paints' : 'Edit paints'),
          ),
        ],
      ),
      for (final paint in paints)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: _PaintSwatch(paint: paint),
          title: Text(paint.name),
          subtitle: Text(paint.brandName ?? 'Unknown brand'),
          trailing: Tooltip(
            message: switch (paint.userStatus) {
              PaintOwnershipStatus.owned => 'Owned',
              PaintOwnershipStatus.wanted => 'Wanted',
              PaintOwnershipStatus.unowned => 'Unowned',
            },
            child: Icon(
              switch (paint.userStatus) {
                PaintOwnershipStatus.owned => Icons.check_circle_outline,
                PaintOwnershipStatus.wanted => Icons.bookmark,
                PaintOwnershipStatus.unowned => Icons.error_outline,
              },
              color: switch (paint.userStatus) {
                PaintOwnershipStatus.owned => const Color(0xFF70C98B),
                PaintOwnershipStatus.wanted => const Color(0xFFE2B85C),
                PaintOwnershipStatus.unowned => const Color(0xFFE07171),
              },
              size: 20,
            ),
          ),
        ),
    ],
  );
}

class _PaintSwatch extends StatelessWidget {
  const _PaintSwatch({required this.paint});

  final CatalogPaint paint;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: paint.color ?? AppTheme.elevatedSurface,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24),
    ),
    child: paint.color == null
        ? const Icon(Icons.palette_outlined, size: 16)
        : null,
  );
}
