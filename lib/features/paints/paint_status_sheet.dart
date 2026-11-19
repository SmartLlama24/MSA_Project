import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'paint_repository.dart';

class PaintStatusSheet extends StatefulWidget {
  const PaintStatusSheet({
    super.key,
    required this.paint,
    required this.onSave,
  });

  final CatalogPaint paint;
  final Future<void> Function(PaintOwnershipStatus status) onSave;

  @override
  State<PaintStatusSheet> createState() => _PaintStatusSheetState();
}

class _PaintStatusSheetState extends State<PaintStatusSheet> {
  late final PaintOwnershipStatus _status = widget.paint.userStatus;
  bool _isSaving = false;
  String? _error;

  Future<void> _save(PaintOwnershipStatus status) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(status);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = paintRepositoryErrorMessage(error);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.paint.color;
    final type = widget.paint.paintType?.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appPalette.mutedText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color ?? context.appPalette.elevatedSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.paint.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (type != null && type.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          type,
                          style: TextStyle(color: context.appPalette.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Your status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(PaintOwnershipStatus.owned, 'Owned'),
                _statusChip(PaintOwnershipStatus.wanted, 'Wanted'),
                _statusChip(PaintOwnershipStatus.unowned, 'Unowned'),
              ],
            ),
            if (_isSaving) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(color: context.appPalette.accent),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(PaintOwnershipStatus status, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == status,
      onSelected: _isSaving ? null : (_) => _save(status),
      selectedColor: context.appPalette.accent,
      backgroundColor: context.appPalette.surface,
      labelStyle: TextStyle(
        color: _status == status
            ? context.appPalette.onAccent
            : context.appPalette.mutedText,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }
}
