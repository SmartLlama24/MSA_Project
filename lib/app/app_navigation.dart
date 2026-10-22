import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/paints/paints_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/paints/paint_repository.dart';
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
  final _projectsKey = GlobalKey<ProjectsScreenState>();

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openCreateProject() {
    _selectTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _projectsKey.currentState?.openCreateProject();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _selectTab, onCreateProject: _openCreateProject),
      ProjectsScreen(key: _projectsKey, repository: widget.projectRepository),
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
