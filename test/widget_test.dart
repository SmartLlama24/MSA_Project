import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paint_app/app/app_theme.dart';
import 'package:paint_app/app/app_navigation.dart';
import 'package:paint_app/data/models.dart';
import 'package:paint_app/data/sample_data.dart';
import 'package:paint_app/features/auth/auth_screen.dart';
import 'package:paint_app/features/auth/auth_service.dart';
import 'package:paint_app/features/projects/project_repository.dart';
import 'package:paint_app/features/projects/projects_screen.dart';

void main() {
  testWidgets('shows the four sections and switches between screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AppNavigation(
          email: 'painter@example.com',
          onLogout: () async {},
          projectRepository: _FakeProjectRepository(
            projects: sampleProjects
                .asMap()
                .entries
                .map(
                  (entry) => PaintingProject(
                    id: 'sample-${entry.key}',
                    name: entry.value.name,
                    subject: entry.value.subject,
                    progress: entry.value.progress,
                    status: entry.value.status,
                    icon: entry.value.icon,
                    colors: entry.value.colors,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    expect(find.text('Good evening, painter'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Paints'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('The Ashen Knight'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsNWidgets(2));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('PLANNED'), findsOneWidget);

    await tester.tap(find.text('Paints'));
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);

    await tester.tap(find.text('Wanted'));
    await tester.pumpAndSettle();
    expect(find.text('Aethermatic Blue'), findsOneWidget);
    expect(find.text('Mephiston Red'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('painter@example.com'), findsOneWidget);
  });

  testWidgets('validates registration fields and password confirmation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const AuthScreen(authService: _FakeAuthService()),
      ),
    );

    await tester.tap(find.text('New to Paintbench? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);
  });

  testWidgets('creates, edits, and deletes a project', (
    WidgetTester tester,
  ) async {
    final repository = _FakeProjectRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ProjectsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your workbench is clear'), findsOneWidget);
    await tester.ensureVisible(find.text('Create project'));
    await tester.tap(find.text('Create project').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Iron Sentinel');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dreadnought');
    await tester.tap(find.text('Create project').last);
    await tester.pumpAndSettle();

    expect(find.text('Iron Sentinel'), findsOneWidget);
    expect(repository.projects, hasLength(1));

    await tester.tap(find.byTooltip('Project actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Iron Sentinel Mk II',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Iron Sentinel Mk II'), findsOneWidget);

    await tester.tap(find.byTooltip('Project actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.projects, isEmpty);
    expect(find.text('Your workbench is clear'), findsOneWidget);
  });
}

class _FakeAuthService implements AuthService {
  const _FakeAuthService();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> signUp({
    required String email,
    required String password,
  }) async => false;
}

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository({List<PaintingProject>? projects})
    : projects = projects ?? [];

  final List<PaintingProject> projects;
  int _nextId = 0;

  @override
  Future<List<PaintingProject>> getProjects() async => [...projects];

  @override
  Future<PaintingProject> createProject(PaintingProject project) async {
    final created = PaintingProject(
      id: 'test-${_nextId++}',
      name: project.name,
      subject: project.subject,
      progress: project.progress,
      status: project.status,
      icon: project.icon,
      colors: project.colors,
    );
    projects.add(created);
    return created;
  }

  @override
  Future<void> deleteProject(String projectId) async {
    projects.removeWhere((project) => project.id == projectId);
  }

  @override
  Future<PaintingProject> updateProject(PaintingProject project) async {
    final index = projects.indexWhere((item) => item.id == project.id);
    projects[index] = project;
    return project;
  }
}
