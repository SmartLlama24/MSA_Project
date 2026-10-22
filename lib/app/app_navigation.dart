import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../features/home/home_screen.dart';
import '../features/paints/paints_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/paints/paint_repository.dart';
import '../features/projects/project_details_screen.dart';
import '../features/projects/project_repository.dart';
import '../features/projects/projects_screen.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({
    super.key,
    required this.email,
    required this.onLogout,
    this.projectRepository,
    this.paintRepository,
  });

  final String email;
  final Future<void> Function() onLogout;
  final ProjectRepository? projectRepository;
  final PaintRepository? paintRepository;

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedIndex = 0;
  late final ProjectRepository _projectRepository;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _projectsKey = GlobalKey<ProjectsScreenState>();

  @override
  void initState() {
    super.initState();
    _projectRepository =
        widget.projectRepository ??
        SupabaseProjectRepository(Supabase.instance.client);
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
      ),
      ProjectsScreen(key: _projectsKey, repository: _projectRepository),
      PaintsScreen(repository: widget.paintRepository),
      ProfileScreen(email: widget.email, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette),
            label: 'Paints',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
