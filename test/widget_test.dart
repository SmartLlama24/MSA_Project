import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paint_app/app/app_theme.dart';
import 'package:paint_app/app/app_navigation.dart';
import 'package:paint_app/data/models.dart';
import 'package:paint_app/data/sample_data.dart';
import 'package:paint_app/features/auth/auth_screen.dart';
import 'package:paint_app/features/auth/auth_service.dart';
import 'package:paint_app/features/paints/brand_paints_screen.dart';
import 'package:paint_app/features/paints/paint_repository.dart';
import 'package:paint_app/features/paints/paints_screen.dart';
import 'package:paint_app/features/projects/project_details_screen.dart';
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
          paintRepository: _FakePaintRepository(),
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
    expect(find.text('Citadel'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('painter@example.com'), findsOneWidget);
  });

  testWidgets('home create action opens the project creation form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AppNavigation(
          email: 'painter@example.com',
          onLogout: () async {},
          projectRepository: _FakeProjectRepository(),
          paintRepository: _FakePaintRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsNWidgets(2));
    expect(find.text('Project name'), findsOneWidget);
    expect(find.text('Miniature or subject'), findsOneWidget);
    expect(find.text('Create project'), findsNWidgets(2));
  });

  testWidgets('shows brand paints and filters the selected brand', (
    WidgetTester tester,
  ) async {
    final repository = _FakePaintRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PaintsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Citadel'), findsOneWidget);
    expect(find.text('Pro Acryl'), findsOneWidget);
    expect(find.textContaining('#9E1B25'), findsNothing);
    expect(find.byIcon(Icons.palette_outlined), findsNothing);

    await tester.tap(find.text('Citadel'));
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(find.text('Leadbelcher'), findsOneWidget);
    expect(find.text('UNOWNED'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Leadbelcher')).dy,
      lessThan(tester.getTopLeft(find.text('Mephiston Red')).dy),
    );
    expect(repository.lastRequestedBrandId, 'citadel');

    await tester.tap(find.text('Mephiston Red'));
    await tester.pumpAndSettle();
    expect(find.text('Your status'), findsOneWidget);
    await tester.tap(find.text('Owned').last);
    await tester.pumpAndSettle();
    expect(find.text('OWNED'), findsOneWidget);

    await tester.tap(find.text('Owned').first);
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(find.text('Leadbelcher'), findsNothing);

    await tester.tap(find.text('All paints'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mephiston Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanted').last);
    await tester.pumpAndSettle();
    expect(find.text('WANTED'), findsOneWidget);

    await tester.tap(find.text('Wanted').last);
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(find.text('Leadbelcher'), findsNothing);

    await tester.tap(find.text('Unowned').first);
    await tester.pumpAndSettle();
    expect(find.text('UNOWNED'), findsOneWidget);
    expect(find.text('Leadbelcher'), findsOneWidget);
    expect(find.text('Mephiston Red'), findsNothing);

    await tester.tap(find.text('All paints'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'red');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(find.text('Leadbelcher'), findsNothing);
  });

  testWidgets('shows empty state when brand catalog has no entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PaintsScreen(repository: _FakePaintRepository(brands: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No paint brands yet'), findsOneWidget);
  });

  testWidgets('shows empty paint state for a brand without paints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BrandPaintsScreen(
          brand: const PaintBrand(id: 'empty-brand', name: 'Empty Brand'),
          repository: _FakePaintRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No paints for Empty Brand'), findsOneWidget);
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

  testWidgets('manages ordered painting steps in project details', (
    WidgetTester tester,
  ) async {
    final project = PaintingProject(
      id: 'project-1',
      name: 'Iron Sentinel',
      subject: 'Dreadnought',
      progress: 0.4,
      status: ProjectStatus.inProgress,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFF40536B), Color(0xFF202A38)],
    );
    final repository = _FakeProjectRepository(projects: [project]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ProjectDetailsScreen(project: project, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iron Sentinel'), findsNWidgets(2));
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('No painting steps yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Iron Sentinel Mk II',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'War machine');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Iron Sentinel Mk II'), findsNWidgets(2));
    expect(find.text('40%'), findsOneWidget);

    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Prime armor');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Apply a smooth black primer.',
    );
    await tester.tap(find.text('Add step').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Basecoat armor');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Block in the main armor color.',
    );
    await tester.tap(find.text('Add step').last);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up).last,
    );
    await tester.pumpAndSettle();
    expect(
      (await repository.getProjectSteps('project-1')).first.title,
      'Basecoat armor',
    );
    expect(
      (await repository.getProjectSteps('project-1'))
          .map((step) => step.stepOrder)
          .toList(),
      [1, 2],
    );

    await tester.tap(find.byTooltip('Step actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Basecoat revised',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Basecoat revised'), findsOneWidget);

    await tester.tap(find.byTooltip('Step actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Basecoat revised'), findsNothing);
    expect(repository.stepsByProject['project-1'], hasLength(1));
    expect((await repository.getProjectSteps('project-1')).single.stepOrder, 1);
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
  int _nextStepId = 0;
  final Map<String, List<ProjectStep>> stepsByProject = {};

  @override
  Future<List<PaintingProject>> getProjects() async => [...projects];

  @override
  Future<PaintingProject> getProject(String projectId) async =>
      projects.firstWhere((project) => project.id == projectId);

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
  Future<List<ProjectStep>> getProjectSteps(String projectId) async =>
      [...(stepsByProject[projectId] ?? [])]
        ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

  @override
  Future<ProjectStep> createProjectStep({
    required String projectId,
    required String title,
    required String instructions,
  }) async {
    final steps = stepsByProject.putIfAbsent(projectId, () => []);
    final step = ProjectStep(
      id: 'step-${_nextStepId++}',
      projectId: projectId,
      stepOrder: steps.isEmpty
          ? 1
          : steps
                    .map((item) => item.stepOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1,
      title: title,
      instructions: instructions,
    );
    steps.add(step);
    return step;
  }

  @override
  Future<ProjectStep> updateProjectStep(ProjectStep step) async {
    final steps = stepsByProject[step.projectId]!;
    final index = steps.indexWhere((item) => item.id == step.id);
    steps[index] = step;
    return step;
  }

  @override
  Future<void> deleteProjectStep(ProjectStep step) async {
    final steps = stepsByProject[step.projectId]!;
    steps.removeWhere((item) => item.id == step.id);
    steps.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      steps[index] = ProjectStep(
        id: step.id,
        projectId: step.projectId,
        stepOrder: index + 1,
        title: step.title,
        instructions: step.instructions,
      );
    }
  }

  @override
  Future<void> reorderProjectSteps(
    String projectId,
    List<String> orderedStepIds,
  ) async {
    final steps = stepsByProject[projectId]!;
    final stepsById = {for (final step in steps) step.id!: step};
    stepsByProject[projectId] = [
      for (var index = 0; index < orderedStepIds.length; index++)
        ProjectStep(
          id: stepsById[orderedStepIds[index]]!.id,
          projectId: projectId,
          stepOrder: index + 1,
          title: stepsById[orderedStepIds[index]]!.title,
          instructions: stepsById[orderedStepIds[index]]!.instructions,
        ),
    ];
  }

  @override
  Future<PaintingProject> updateProject(PaintingProject project) async {
    final index = projects.indexWhere((item) => item.id == project.id);
    projects[index] = project;
    return project;
  }
}

class _FakePaintRepository implements PaintRepository {
  _FakePaintRepository({List<PaintBrand>? brands})
    : brands =
          brands ??
          const [
            PaintBrand(
              id: 'citadel',
              name: 'Citadel',
              color: Color(0xFF9E1B25),
            ),
            PaintBrand(
              id: 'pro-acryl',
              name: 'Pro Acryl',
              color: Color(0xFFE6E3D7),
            ),
          ];

  final List<PaintBrand> brands;
  String? lastRequestedBrandId;
  final Map<String, PaintOwnershipStatus> statuses = {};

  static const _paintsByBrand = {
    'citadel': [
      CatalogPaint(
        id: 'red',
        name: 'Mephiston Red',
        paintType: 'Base',
        hexColor: '#9E1B25',
      ),
      CatalogPaint(
        id: 'metal',
        name: 'Leadbelcher',
        paintType: 'Base · Metallic',
        hexColor: '#727B7D',
      ),
    ],
  };

  @override
  Future<List<PaintBrand>> getBrands() async => brands;

  @override
  Future<Map<String, String>> getBrandLogoUrls(List<PaintBrand> brands) async =>
      {};

  @override
  Future<List<CatalogPaint>> getPaintsForBrand(String brandId) async {
    lastRequestedBrandId = brandId;
    return (_paintsByBrand[brandId] ?? [])
        .map(
          (paint) => paint.withUserStatus(
            statuses[paint.id] ?? PaintOwnershipStatus.unowned,
          ),
        )
        .toList();
  }

  @override
  Future<void> setPaintStatus(
    String paintId,
    PaintOwnershipStatus status,
  ) async {
    if (status == PaintOwnershipStatus.unowned) {
      statuses.remove(paintId);
    } else {
      statuses[paintId] = status;
    }
  }
}
