import 'package:flutter/material.dart';

import 'models.dart';

const sampleProjects = [
  PaintingProject(
    name: 'The Ashen Knight',
    subject: 'Space Marine · Intercessor',
    progress: 0.68,
    status: ProjectStatus.inProgress,
    icon: Icons.shield_outlined,
    colors: [Color(0xFF40536B), Color(0xFF202A38)],
  ),
  PaintingProject(
    name: 'Mossback Guardian',
    subject: 'Sylvaneth · Treelord',
    progress: 0.32,
    status: ProjectStatus.inProgress,
    icon: Icons.park_outlined,
    colors: [Color(0xFF637454), Color(0xFF29372F)],
  ),
  PaintingProject(
    name: 'The Gilded Wyrm',
    subject: 'Dungeons & Dragons · Dragon',
    progress: 1,
    status: ProjectStatus.completed,
    icon: Icons.whatshot_outlined,
    colors: [Color(0xFF9B7041), Color(0xFF493324)],
  ),
  PaintingProject(
    name: 'Crypt of the Lost',
    subject: 'Warhammer · Skeleton Warriors',
    progress: 0,
    status: ProjectStatus.planned,
    icon: Icons.nightlight_outlined,
    colors: [Color(0xFF6D687D), Color(0xFF302D3D)],
  ),
];

const samplePaints = [
  PaintEntry(
    name: 'Mephiston Red',
    brand: 'Citadel',
    type: 'Base',
    color: Color(0xFF9E1B25),
    status: PaintStatus.owned,
  ),
  PaintEntry(
    name: 'Leadbelcher',
    brand: 'Citadel',
    type: 'Base · Metallic',
    color: Color(0xFF727B7D),
    status: PaintStatus.owned,
  ),
  PaintEntry(
    name: 'XV-88',
    brand: 'Citadel',
    type: 'Base',
    color: Color(0xFF75553C),
    status: PaintStatus.owned,
  ),
  PaintEntry(
    name: 'Aethermatic Blue',
    brand: 'Citadel',
    type: 'Contrast',
    color: Color(0xFF4DB3C3),
    status: PaintStatus.wanted,
  ),
  PaintEntry(
    name: 'Pro Acryl Bold Titanium White',
    brand: 'Pro Acryl',
    type: 'Base',
    color: Color(0xFFE6E3D7),
    status: PaintStatus.wanted,
  ),
  PaintEntry(
    name: 'Nuln Oil',
    brand: 'Citadel',
    type: 'Shade',
    color: Color(0xFF30343A),
    status: PaintStatus.missing,
  ),
  PaintEntry(
    name: 'Ogryn Camo',
    brand: 'Citadel',
    type: 'Layer',
    color: Color(0xFF82966B),
    status: PaintStatus.missing,
  ),
];
