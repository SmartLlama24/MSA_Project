import 'package:flutter/material.dart';

enum ProjectStatus { inProgress, planned, completed }

class PaintingProject {
  const PaintingProject({
    this.id,
    required this.name,
    required this.subject,
    required this.progress,
    required this.status,
    required this.icon,
    required this.colors,
  });

  final String? id;
  final String name;
  final String subject;
  final double progress;
  final ProjectStatus status;
  final IconData icon;
  final List<Color> colors;

  factory PaintingProject.fromMap(Map<String, dynamic> map) {
    final status = switch (map['status']) {
      'in_progress' => ProjectStatus.inProgress,
      'completed' => ProjectStatus.completed,
      _ => ProjectStatus.planned,
    };
    final progressValue = map['progress'];
    final progress = progressValue is num
        ? progressValue.toDouble().clamp(0.0, 1.0)
        : 0.0;

    return PaintingProject(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Untitled project',
      subject: map['subject'] as String? ?? '',
      progress: progress,
      status: status,
      icon: _projectIcon(status),
      colors: _projectColors(status),
    );
  }

  Map<String, dynamic> toInsertMap({required String userId}) => {
    'user_id': userId,
    'name': name,
    'subject': subject,
    'status': _statusToDatabase(status),
    'progress': progress,
  };

  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    'subject': subject,
    'status': _statusToDatabase(status),
    'progress': progress,
  };

  static String _statusToDatabase(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => 'planned',
    ProjectStatus.inProgress => 'in_progress',
    ProjectStatus.completed => 'completed',
  };

  static IconData _projectIcon(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => Icons.nightlight_outlined,
    ProjectStatus.inProgress => Icons.shield_outlined,
    ProjectStatus.completed => Icons.whatshot_outlined,
  };

  static List<Color> _projectColors(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => const [Color(0xFF6D687D), Color(0xFF302D3D)],
    ProjectStatus.inProgress => const [Color(0xFF40536B), Color(0xFF202A38)],
    ProjectStatus.completed => const [Color(0xFF9B7041), Color(0xFF493324)],
  };
}

class ProjectStep {
  const ProjectStep({
    this.id,
    required this.projectId,
    required this.stepOrder,
    required this.title,
    required this.instructions,
  });

  final String? id;
  final String projectId;
  final int stepOrder;
  final String title;
  final String instructions;

  factory ProjectStep.fromMap(Map<String, dynamic> map) {
    final orderValue = map['step_order'];
    if (orderValue is! num) {
      throw const FormatException('Project step has an invalid order.');
    }

    return ProjectStep(
      id: map['id'] as String?,
      projectId: map['project_id'] as String,
      stepOrder: orderValue.toInt(),
      title: map['title'] as String? ?? 'Untitled step',
      instructions: map['instructions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'project_id': projectId,
    'step_order': stepOrder,
    'title': title,
    'instructions': instructions,
  };

  Map<String, dynamic> toUpdateMap() => {
    'title': title,
    'instructions': instructions,
  };
}

enum PaintStatus { owned, wanted, missing }

class PaintEntry {
  const PaintEntry({
    required this.name,
    required this.brand,
    required this.type,
    required this.color,
    required this.status,
  });

  final String name;
  final String brand;
  final String type;
  final Color color;
  final PaintStatus status;
}

class PaintBrand {
  const PaintBrand({
    required this.id,
    required this.name,
    this.color,
    this.logoPath,
    this.logoUrl,
  });

  final String id;
  final String name;
  final Color? color;
  final String? logoPath;
  final String? logoUrl;

  PaintBrand withLogoUrl(String? url) => PaintBrand(
    id: id,
    name: name,
    color: color,
    logoPath: logoPath,
    logoUrl: url,
  );

  factory PaintBrand.fromMap(Map<String, dynamic> map) {
    final paintRows = map['paints'];
    Color? color;
    if (paintRows is List) {
      for (final row in paintRows) {
        if (row is Map<String, dynamic>) {
          color = parsePaintColor(row['hex_color']);
          if (color != null) break;
        }
      }
    }

    return PaintBrand(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown brand',
      color: color,
      logoPath: map['logo_path'] as String?,
    );
  }
}

class CatalogPaint {
  const CatalogPaint({
    required this.id,
    required this.name,
    this.paintType,
    this.hexColor,
    this.userStatus = PaintOwnershipStatus.unowned,
  });

  final String id;
  final String name;
  final String? paintType;
  final String? hexColor;
  final PaintOwnershipStatus userStatus;

  Color? get color => parsePaintColor(hexColor);

  factory CatalogPaint.fromMap(Map<String, dynamic> map) {
    final userPaints = map['user_paints'];
    final statusRow = userPaints is List && userPaints.isNotEmpty
        ? userPaints.first
        : null;
    final statusValue = statusRow is Map<String, dynamic>
        ? statusRow['status']
        : null;

    return CatalogPaint(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed paint',
      paintType: map['paint_type'] as String?,
      hexColor: map['hex_color'] as String?,
      userStatus: PaintOwnershipStatus.fromDatabase(statusValue),
    );
  }

  CatalogPaint withUserStatus(PaintOwnershipStatus status) => CatalogPaint(
    id: id,
    name: name,
    paintType: paintType,
    hexColor: hexColor,
    userStatus: status,
  );
}

enum PaintOwnershipStatus {
  unowned,
  owned,
  wanted;

  static PaintOwnershipStatus fromDatabase(Object? value) => switch (value) {
    'owned' => PaintOwnershipStatus.owned,
    'wanted' => PaintOwnershipStatus.wanted,
    _ => PaintOwnershipStatus.unowned,
  };

  String? get databaseValue => switch (this) {
    PaintOwnershipStatus.unowned => null,
    PaintOwnershipStatus.owned => 'owned',
    PaintOwnershipStatus.wanted => 'wanted',
  };
}

Color? parsePaintColor(String? value) {
  if (value == null) return null;
  final hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF$hex', radix: 16));
}
