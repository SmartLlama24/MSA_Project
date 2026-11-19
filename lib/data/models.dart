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
    this.completedStepCount = 0,
    this.totalStepCount = 0,
    this.coverPhotoId,
    this.coverPhotoUrl,
    this.lastStepCompletedAt,
  });

  final String? id;
  final String name;
  final String subject;
  final double progress;
  final ProjectStatus status;
  final IconData icon;
  final List<Color> colors;
  final int completedStepCount;
  final int totalStepCount;
  final String? coverPhotoId;
  final String? coverPhotoUrl;
  final DateTime? lastStepCompletedAt;

  factory PaintingProject.fromMap(Map<String, dynamic> map) {
    final storedStatus = switch (map['status']) {
      'in_progress' => ProjectStatus.inProgress,
      'completed' => ProjectStatus.completed,
      _ => ProjectStatus.planned,
    };
    final progressValue = map['progress'];
    final progress = progressValue is num
        ? progressValue.toDouble().clamp(0.0, 1.0)
        : 0.0;
    final stepRows = map['project_steps'];
    final stepMaps = stepRows is List
        ? stepRows.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final completedStepCount = stepMaps
        .where((step) => step['is_completed'] == true)
        .length;
    final lastCompletionValue = map['last_step_completed_at'];
    final lastStepCompletedAt = lastCompletionValue is DateTime
        ? lastCompletionValue
        : lastCompletionValue is String
        ? DateTime.tryParse(lastCompletionValue)
        : null;
    final status = stepRows is! List || storedStatus == ProjectStatus.completed
        ? storedStatus
        : completedStepCount == 0
        ? ProjectStatus.planned
        : ProjectStatus.inProgress;
    return PaintingProject(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Untitled project',
      subject: map['subject'] as String? ?? '',
      progress: progress,
      status: status,
      icon: _projectIcon(status),
      colors: _projectColors(status),
      completedStepCount: completedStepCount,
      totalStepCount: stepMaps.length,
      coverPhotoId: map['cover_photo_id'] as String?,
      coverPhotoUrl: map['cover_photo_url'] as String?,
      lastStepCompletedAt: lastStepCompletedAt,
    );
  }

  PaintingProject copyWith({
    ProjectStatus? status,
    int? completedStepCount,
    int? totalStepCount,
    String? coverPhotoId,
    String? coverPhotoUrl,
    DateTime? lastStepCompletedAt,
    bool clearCover = false,
  }) => PaintingProject(
    id: id,
    name: name,
    subject: subject,
    progress: progress,
    status: status ?? this.status,
    icon: icon,
    colors: colors,
    completedStepCount: completedStepCount ?? this.completedStepCount,
    totalStepCount: totalStepCount ?? this.totalStepCount,
    coverPhotoId: clearCover ? null : coverPhotoId ?? this.coverPhotoId,
    coverPhotoUrl: clearCover ? null : coverPhotoUrl ?? this.coverPhotoUrl,
    lastStepCompletedAt: lastStepCompletedAt ?? this.lastStepCompletedAt,
  );

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

class ProjectPhoto {
  const ProjectPhoto({
    required this.id,
    required this.projectId,
    required this.storagePath,
    required this.createdAt,
    this.projectStepId,
    this.signedUrl,
  });

  final String id;
  final String projectId;
  final String storagePath;
  final DateTime createdAt;
  final String? projectStepId;
  final String? signedUrl;

  factory ProjectPhoto.fromMap(Map<String, dynamic> map) => ProjectPhoto(
    id: map['id'] as String,
    projectId: map['project_id'] as String,
    storagePath: map['storage_path'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    projectStepId: map['project_step_id'] as String?,
    signedUrl: map['signed_url'] as String?,
  );

  ProjectPhoto withSignedUrl(String url) => ProjectPhoto(
    id: id,
    projectId: projectId,
    storagePath: storagePath,
    createdAt: createdAt,
    projectStepId: projectStepId,
    signedUrl: url,
  );
}

class PaintingScheme {
  const PaintingScheme({
    required this.id,
    required this.name,
    this.description,
    this.previewStoragePath,
    this.previewUrl,
    this.steps = const [],
    this.stepCount,
  });

  final String id;
  final String name;
  final String? description;
  final String? previewStoragePath;
  final String? previewUrl;
  final List<PaintingSchemeStep> steps;
  final int? stepCount;

  factory PaintingScheme.fromMap(Map<String, dynamic> map) => PaintingScheme(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    previewStoragePath: map['preview_storage_path'] as String?,
    steps: (map['painting_scheme_steps'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaintingSchemeStep.fromMap)
        .toList(),
  );

  PaintingScheme withPreviewUrl(String? url) => PaintingScheme(
    id: id,
    name: name,
    description: description,
    previewStoragePath: previewStoragePath,
    previewUrl: url,
    steps: steps,
    stepCount: stepCount,
  );

  PaintingScheme copyWith({
    String? name,
    String? description,
    String? previewStoragePath,
    String? previewUrl,
    List<PaintingSchemeStep>? steps,
    int? stepCount,
    bool clearDescription = false,
    bool clearPreview = false,
  }) => PaintingScheme(
    id: id,
    name: name ?? this.name,
    description: clearDescription ? null : description ?? this.description,
    previewStoragePath: clearPreview
        ? null
        : previewStoragePath ?? this.previewStoragePath,
    previewUrl: clearPreview ? null : previewUrl ?? this.previewUrl,
    steps: steps ?? this.steps,
    stepCount: stepCount ?? this.stepCount,
  );

  Map<String, dynamic> toInsertMap({required String userId}) => {
    'user_id': userId,
    'name': name.trim(),
    'description': _trimOrNull(description),
  };

  Map<String, dynamic> toUpdateMap() => {
    'name': name.trim(),
    'description': _trimOrNull(description),
  };
}

class PaintingSchemeStep {
  const PaintingSchemeStep({
    required this.id,
    required this.schemeId,
    required this.stepOrder,
    required this.title,
    required this.description,
    this.paints = const [],
  });

  final String id;
  final String schemeId;
  final int stepOrder;
  final String title;
  final String description;
  final List<CatalogPaint> paints;

  factory PaintingSchemeStep.fromMap(Map<String, dynamic> map) =>
      PaintingSchemeStep(
        id: map['id'] as String,
        schemeId: map['scheme_id'] as String,
        stepOrder: (map['step_order'] as num).toInt(),
        title: map['title'] as String,
        description: map['description'] as String? ?? '',
        paints: (map['painting_scheme_step_paints'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((row) => row['paints'])
            .whereType<Map<String, dynamic>>()
            .map(CatalogPaint.fromMap)
            .toList(),
      );

  Map<String, dynamic> toInsertMap() => {
    'scheme_id': schemeId,
    'step_order': stepOrder,
    'title': title.trim(),
    'description': description.trim(),
  };

  Map<String, dynamic> toUpdateMap() => {
    'title': title.trim(),
    'description': description.trim(),
  };
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class ProjectStep {
  const ProjectStep({
    this.id,
    required this.projectId,
    required this.stepOrder,
    required this.title,
    required this.instructions,
    this.isCompleted = false,
    this.paints = const [],
  });

  final String? id;
  final String projectId;
  final int stepOrder;
  final String title;
  final String instructions;
  final bool isCompleted;
  final List<CatalogPaint> paints;

  factory ProjectStep.fromMap(Map<String, dynamic> map) {
    final orderValue = map['step_order'];
    if (orderValue is! num) {
      throw const FormatException('Project step has an invalid order.');
    }
    final paintRows = map['step_paints'];
    final paints = paintRows is List
        ? paintRows
              .whereType<Map<String, dynamic>>()
              .map((row) => row['paints'])
              .whereType<Map<String, dynamic>>()
              .map(CatalogPaint.fromMap)
              .toList()
        : <CatalogPaint>[];

    return ProjectStep(
      id: map['id'] as String?,
      projectId: map['project_id'] as String,
      stepOrder: orderValue.toInt(),
      title: map['title'] as String? ?? 'Untitled step',
      instructions: map['instructions'] as String? ?? '',
      isCompleted: map['is_completed'] as bool? ?? false,
      paints: paints,
    );
  }

  ProjectStep copyWith({bool? isCompleted, List<CatalogPaint>? paints}) =>
      ProjectStep(
        id: id,
        projectId: projectId,
        stepOrder: stepOrder,
        title: title,
        instructions: instructions,
        isCompleted: isCompleted ?? this.isCompleted,
        paints: paints ?? this.paints,
      );

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
    this.brandName,
    this.paintType,
    this.hexColor,
    this.userStatus = PaintOwnershipStatus.unowned,
  });

  final String id;
  final String name;
  final String? brandName;
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
    final brandRow = map['paint_brands'];

    return CatalogPaint(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed paint',
      brandName: brandRow is Map<String, dynamic>
          ? brandRow['name'] as String?
          : null,
      paintType: map['paint_type'] as String?,
      hexColor: map['hex_color'] as String?,
      userStatus: PaintOwnershipStatus.fromDatabase(statusValue),
    );
  }

  CatalogPaint withUserStatus(PaintOwnershipStatus status) => CatalogPaint(
    id: id,
    name: name,
    brandName: brandName,
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
