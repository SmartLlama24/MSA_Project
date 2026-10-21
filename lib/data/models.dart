import 'package:flutter/material.dart';

enum ProjectStatus { inProgress, planned, completed }

class PaintingProject {
  const PaintingProject({
    required this.name,
    required this.subject,
    required this.progress,
    required this.status,
    required this.icon,
    required this.colors,
  });

  final String name;
  final String subject;
  final double progress;
  final ProjectStatus status;
  final IconData icon;
  final List<Color> colors;
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
