import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../features/home/home_screen.dart';
import '../features/paints/paints_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/paints/paint_repository.dart';
import '../features/projects/project_details_screen.dart';
import '../features/projects/project_photo_repository.dart';
import '../features/projects/project_repository.dart';
import '../features/projects/projects_screen.dart';
import '../features/schemes/painting_scheme_repository.dart';
import '../features/schemes/painting_schemes_screen.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({
    super.key,
    required this.email,
    required this.onLogout,
    this.projectRepository,
    this.paintRepository,
    this.photoRepository,
    this.schemeRepository,
    this.schemePreviewPicker,
  });

  final String email;
  final Future<void> Function() onLogout;
  final ProjectRepository? projectRepository;
  final PaintRepository? paintRepository;
  final ProjectPhotoRepository? photoRepository;
  final PaintingSchemeRepository? schemeRepository;
  final SchemePreviewPicker? schemePreviewPicker;

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedIndex = 0;
  late final ProjectRepository _projectRepository;
  late final PaintRepository _paintRepository;
  late final ProjectPhotoRepository _photoRepository;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _projectsKey = GlobalKey<ProjectsScreenState>();
  late final PaintingSchemeRepository _schemeRepository;
  late final SchemePreviewPicker _schemePreviewPicker;

  @override
  void initState() {
    super.initState();
    _projectRepository =
        widget.projectRepository ??
        SupabaseProjectRepository(Supabase.instance.client);
    _paintRepository =
        widget.paintRepository ??
        SupabasePaintRepository(Supabase.instance.client);
    _photoRepository =
        widget.photoRepository ??
        SupabaseProjectPhotoRepository(Supabase.instance.client);
    _schemeRepository =
        widget.schemeRepository ??
        SupabasePaintingSchemeRepository(Supabase.instance.client);
    _schemePreviewPicker =
        widget.schemePreviewPicker ?? DeviceSchemePreviewPicker();
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openCreateProject() {
    _selectTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _projectsKey.currentState?.openCreateProject();
    });
  }

  Future<void> _openProjectDetails(PaintingProject project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailsScreen(
          project: project,
          repository: _projectRepository,
          paintRepository: _paintRepository,
          photoRepository: _photoRepository,
        ),
      ),
    );
    if (mounted) await _homeKey.currentState?.loadRecentProjects();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: _homeKey,
        onNavigate: _selectTab,
        onCreateProject: _openCreateProject,
        onOpenProject: _openProjectDetails,
        projectRepository: _projectRepository,
        photoRepository: _photoRepository,
      ),
      ProjectsScreen(
        key: _projectsKey,
        repository: _projectRepository,
        paintRepository: _paintRepository,
        photoRepository: _photoRepository,
        schemeRepository: _schemeRepository,
      ),
      PaintsScreen(repository: _paintRepository),
      PaintingSchemesScreen(
        repository: _schemeRepository,
        paintRepository: _paintRepository,
        previewPicker: _schemePreviewPicker,
      ),
      ProfileScreen(email: widget.email, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 24),
            selectedIcon: Icon(Icons.home, size: 25),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined, size: 24),
            selectedIcon: Icon(Icons.view_kanban, size: 25),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined, size: 24),
            selectedIcon: Icon(Icons.palette, size: 25),
            label: 'Paints',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, size: 24),
            selectedIcon: Icon(Icons.auto_awesome, size: 25),
            label: 'Schemes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 24),
            selectedIcon: Icon(Icons.person, size: 25),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
