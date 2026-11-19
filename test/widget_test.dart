import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:paint_app/features/projects/project_photo_repository.dart';
import 'package:paint_app/features/projects/project_form_dialog.dart';
import 'package:paint_app/features/projects/project_repository.dart';
import 'package:paint_app/features/projects/projects_screen.dart';
import 'package:paint_app/features/schemes/painting_scheme_details_screen.dart';
import 'package:paint_app/features/schemes/painting_scheme_repository.dart';
import 'package:paint_app/features/schemes/painting_schemes_screen.dart';

void main() {
  test('project reads its latest step completion event', () {
    final project = PaintingProject.fromMap({
      'id': 'completion-project',
      'name': 'Completion project',
      'subject': 'Miniature',
      'progress': 0,
      'status': 'in_progress',
      'last_step_completed_at': '2026-11-18T12:00:00Z',
      'project_steps': [
        {'is_completed': false},
      ],
    });

    expect(project.lastStepCompletedAt, DateTime.parse('2026-11-18T12:00:00Z'));
  });

  test('project status derives from steps unless marked completed', () {
    final noSteps = PaintingProject.fromMap({
      'name': 'Unstarted Miniature',
      'subject': 'Scout',
      'progress': 1,
      'status': 'in_progress',
      'project_steps': [],
    });
    final partialSteps = PaintingProject.fromMap({
      'name': 'In Progress Miniature',
      'subject': 'Knight',
      'progress': 0,
      'status': 'planned',
      'project_steps': [
        {'is_completed': true},
        {'is_completed': false},
      ],
    });
    final allStepsComplete = PaintingProject.fromMap({
      'name': 'Finished Steps Miniature',
      'subject': 'Knight',
      'progress': 0,
      'status': 'planned',
      'project_steps': [
        {'is_completed': true},
        {'is_completed': true},
      ],
    });
    final manuallyCompleted = PaintingProject.fromMap({
      'name': 'Completed Miniature',
      'subject': 'Knight',
      'progress': 0,
      'status': 'completed',
      'project_steps': [],
    });

    expect(noSteps.status, ProjectStatus.planned);
    expect(partialSteps.status, ProjectStatus.inProgress);
    expect(allStepsComplete.status, ProjectStatus.inProgress);
    expect(manuallyCompleted.status, ProjectStatus.completed);
  });

  testWidgets('shows the app sections and switches between screens', (
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
          photoRepository: _FakeProjectPhotoRepository(onCoverChanged: (_) {}),
          schemeRepository: _FakePaintingSchemeRepository(),
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

    await tester.tap(find.text('Schemes'));
    await tester.pumpAndSettle();
    expect(find.text('No painting schemes yet'), findsOneWidget);

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
          photoRepository: _FakeProjectPhotoRepository(onCoverChanged: (_) {}),
          schemeRepository: _FakePaintingSchemeRepository(),
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

  testWidgets('project creation applies a selected painting scheme', (
    WidgetTester tester,
  ) async {
    String? appliedSchemeId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ProjectFormDialog(
            schemes: const [
              PaintingScheme(
                id: 'scheme-1',
                name: 'Winter Armour',
                stepCount: 2,
              ),
            ],
            onSave: (project) async => project,
            onCreateFromScheme:
                ({required name, required subject, required schemeId}) async {
                  appliedSchemeId = schemeId;
                  return PaintingProject(
                    id: 'created',
                    name: name,
                    subject: subject,
                    progress: 0,
                    status: ProjectStatus.planned,
                    icon: Icons.shield_outlined,
                    colors: const [Color(0xFF40536B), Color(0xFF202A38)],
                  );
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New project');
    await tester.enterText(find.byType(TextFormField).at(1), 'Knight');
    await tester.tap(find.text('Choose a painting scheme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Winter Armour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create project').last);
    await tester.pumpAndSettle();

    expect(appliedSchemeId, 'scheme-1');
  });

  testWidgets(
    'painting schemes can be created, edited, duplicated and deleted',
    (WidgetTester tester) async {
      final repository = _FakePaintingSchemeRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: PaintingSchemesScreen(
              repository: repository,
              paintRepository: _FakePaintRepository(),
              previewPicker: DeviceSchemePreviewPicker(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No painting schemes yet'), findsOneWidget);

      await tester.ensureVisible(find.text('Create scheme'));
      await tester.tap(find.text('Create scheme'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Forest Guard');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Muted greens and weathered metal.',
      );
      await tester.tap(find.text('Create scheme'));
      await tester.pumpAndSettle();
      expect(find.text('Forest Guard'), findsOneWidget);

      await tester.tap(find.byTooltip('Scheme actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Forest Sentinel',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Forest Sentinel'), findsOneWidget);

      await tester.tap(find.byTooltip('Scheme actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('Forest Sentinel (copy)'), findsOneWidget);

      await tester.tap(find.byTooltip('Scheme actions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Forest Sentinel'), findsOneWidget);
      expect(find.text('Forest Sentinel (copy)'), findsNothing);
    },
  );

  testWidgets('scheme details show paint ownership icons', (
    WidgetTester tester,
  ) async {
    final paint = _testPaint('paint-1', 'Forest Green', '#24552D');
    final scheme = PaintingScheme(
      id: 'scheme-status',
      name: 'Forest Guard',
      steps: [
        PaintingSchemeStep(
          id: 'step-status',
          schemeId: 'scheme-status',
          stepOrder: 1,
          title: 'Basecoat',
          description: 'Apply the base layer.',
          paints: [
            paint.withUserStatus(PaintOwnershipStatus.owned),
            _testPaint(
              'paint-2',
              'Deep Shade',
              null,
            ).withUserStatus(PaintOwnershipStatus.wanted),
            _testPaint('paint-3', 'Highlight', null),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PaintingSchemeDetailsScreen(
          scheme: scheme,
          repository: _FakePaintingSchemeRepository(schemes: [scheme]),
          paintRepository: _FakePaintRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Owned'), findsOneWidget);
    expect(find.byTooltip('Wanted'), findsOneWidget);
    expect(find.byTooltip('Unowned'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Neither'), findsNothing);
  });

  testWidgets('new scheme steps append after existing steps', (
    WidgetTester tester,
  ) async {
    final scheme = PaintingScheme(
      id: 'scheme-order',
      name: 'Order test',
      steps: [
        PaintingSchemeStep(
          id: 'step-early',
          schemeId: 'scheme-order',
          stepOrder: 2,
          title: 'Earlier step',
          description: '',
        ),
        PaintingSchemeStep(
          id: 'step-late',
          schemeId: 'scheme-order',
          stepOrder: 8,
          title: 'Later step',
          description: '',
        ),
      ],
    );
    final repository = _FakePaintingSchemeRepository(schemes: [scheme]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PaintingSchemeDetailsScreen(
          scheme: scheme,
          repository: repository,
          paintRepository: _FakePaintRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Appended step');
    await tester.tap(find.text('Save step'));
    await tester.pumpAndSettle();

    final steps = (await repository.getScheme(scheme.id)).steps;
    expect(steps.map((step) => step.id), ['step-early', 'step-late', 'step-0']);
    expect(steps.map((step) => step.stepOrder), [2, 8, 9]);
  });

  testWidgets('reordering steps persists without reloading scheme details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scheme = PaintingScheme(
      id: 'scheme-reorder',
      name: 'Reorder test',
      steps: [
        for (var index = 0; index < 2; index++)
          PaintingSchemeStep(
            id: 'step-$index',
            schemeId: 'scheme-reorder',
            stepOrder: index + 1,
            title: 'Step $index',
            description: '',
          ),
      ],
    );
    final repository = _FakePaintingSchemeRepository(schemes: [scheme]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            gestureSettings: DeviceGestureSettings(touchSlop: 8),
          ),
          child: PaintingSchemeDetailsScreen(
            scheme: scheme,
            repository: repository,
            paintRepository: _FakePaintRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> dragFirstDown() async {
      final firstHandle = tester.getCenter(
        find.byIcon(Icons.drag_handle).first,
      );
      final drag = await tester.startGesture(firstHandle);
      await tester.pump(const Duration(milliseconds: 500));
      await drag.moveBy(const Offset(0, 10));
      await tester.pump();
      await drag.moveBy(const Offset(0, 90));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
    }

    await dragFirstDown();

    expect(repository.reorderStepsCalls, 1);
    final steps = (await repository.getScheme(scheme.id)).steps;
    expect(steps.map((step) => step.id), ['step-1', 'step-0']);
    expect(steps.map((step) => step.stepOrder), [1, 2]);
    expect(repository.getSchemeCalls, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.reorderError = StateError('save failed');
    await dragFirstDown();

    expect(
      find.text('Your session has expired. Sign in again and retry.'),
      findsOneWidget,
    );
    final unchangedSteps = (await repository.getScheme(scheme.id)).steps;
    expect(unchangedSteps.map((step) => step.id), ['step-1', 'step-0']);
  });

  testWidgets('home shows current and two recent projects', (
    WidgetTester tester,
  ) async {
    final projects = [
      ...sampleProjects.asMap().entries.map(
        (entry) => PaintingProject(
          id: 'recent-${entry.key}',
          name: entry.value.name,
          subject: entry.value.subject,
          progress: entry.value.progress,
          status: entry.value.status,
          icon: entry.value.icon,
          colors: entry.value.colors,
          completedStepCount: entry.key == 0 ? 2 : 0,
          totalStepCount: entry.key == 0 ? 5 : 0,
          lastStepCompletedAt: switch (entry.key) {
            0 => DateTime(2026, 11, 17),
            1 => DateTime(2026, 11, 18),
            _ => null,
          },
        ),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AppNavigation(
          email: 'painter@example.com',
          onLogout: () async {},
          projectRepository: _FakeProjectRepository(projects: projects),
          paintRepository: _FakePaintRepository(),
          photoRepository: _FakeProjectPhotoRepository(onCoverChanged: (_) {}),
          schemeRepository: _FakePaintingSchemeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Ashen Knight'), findsOneWidget);
    expect(find.text('Mossback Guardian'), findsOneWidget);
    expect(find.text('The Gilded Wyrm'), findsNothing);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('0% complete'), findsOneWidget);
    final recentProgressBars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(recentProgressBars, hasLength(2));
    expect(recentProgressBars[0].value, 0);
    expect(recentProgressBars[1].value, 0.4);

    await tester.tap(find.text('Mossback Guardian'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Painting steps'));
    expect(find.text('Painting steps'), findsOneWidget);
    expect(find.text('Painting steps'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mossback Guardian'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('The Gilded Wyrm'), findsOneWidget);
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
      tester.getTopLeft(find.text('Mephiston Red')).dy,
      lessThan(tester.getTopLeft(find.text('Leadbelcher')).dy),
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

  testWidgets('sorts brand paints by visual HSV color order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const namesInVisualOrder = [
      'Red near hue boundary',
      'Dark red',
      'Bright red',
      'Light red',
      'Orange',
      'Yellow',
      'Green',
      'Cyan',
      'Blue',
      'Purple',
      'Black',
      'Grey',
      'White',
      'Invalid color',
    ];
    final paints = [
      _testPaint('white', 'White', '#FFFFFF'),
      _testPaint('blue', 'Blue', '#0000FF'),
      _testPaint('missing', 'Invalid color', 'not-hex'),
      _testPaint('bright-red', 'Bright red', '#FF0000'),
      _testPaint('purple', 'Purple', '#8000FF'),
      _testPaint('black', 'Black', '#000000'),
      _testPaint('orange', 'Orange', '#FF8000'),
      _testPaint('red-edge', 'Red near hue boundary', '#FF0040'),
      _testPaint('green', 'Green', '#00FF00'),
      _testPaint('light-red', 'Light red', '#FF8080'),
      _testPaint('yellow', 'Yellow', '#FFFF00'),
      _testPaint('grey', 'Grey', '#777777'),
      _testPaint('dark-red', 'Dark red', '#800000'),
      _testPaint('cyan', 'Cyan', '#00FFFF'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BrandPaintsScreen(
          brand: const PaintBrand(id: 'test-brand', name: 'Test brand'),
          repository: _FakePaintRepository(
            paintsByBrand: {'test-brand': paints},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < namesInVisualOrder.length - 1; index++) {
      expect(
        tester.getTopLeft(find.text(namesInVisualOrder[index])).dy,
        lessThan(
          tester.getTopLeft(find.text(namesInVisualOrder[index + 1])).dy,
        ),
        reason:
            '${namesInVisualOrder[index]} should precede '
            '${namesInVisualOrder[index + 1]}',
      );
    }
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
        home: Scaffold(
          body: ProjectsScreen(
            repository: repository,
            paintRepository: _FakePaintRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your workbench is clear'), findsOneWidget);
    await tester.ensureVisible(find.text('Create project'));
    await tester.tap(find.text('Create project').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Iron Sentinel');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dreadnought');
    expect(find.text('Status'), findsNothing);
    expect(find.text('Progress'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.text('Create project').last);
    await tester.pumpAndSettle();

    expect(find.text('Iron Sentinel'), findsOneWidget);
    expect(repository.projects, hasLength(1));
    expect(repository.projects.single.status, ProjectStatus.planned);
    expect(repository.projects.single.progress, 0);

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
    expect(repository.projects.single.status, ProjectStatus.planned);

    await tester.tap(find.byTooltip('Project actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as completed'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.projects.single.status, ProjectStatus.completed);
    expect(find.text('COMPLETED'), findsOneWidget);

    await tester.tap(find.byTooltip('Project actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.projects, isEmpty);
    expect(find.text('Your workbench is clear'), findsOneWidget);
  });

  testWidgets(
    'projects list shows step progress instead of manual percentage',
    (WidgetTester tester) async {
      final project = PaintingProject.fromMap({
        'id': 'project-progress',
        'name': 'Iron Sentinel',
        'subject': 'Dreadnought',
        'progress': 0.8,
        'status': 'in_progress',
        'project_steps': [
          {'is_completed': true},
          {'is_completed': false},
          {'is_completed': true},
          {'is_completed': false},
          {'is_completed': false},
        ],
      });
      final emptyProject = PaintingProject.fromMap({
        'id': 'project-empty',
        'name': 'Unstarted Miniature',
        'subject': 'Scout',
        'progress': 1,
        'status': 'planned',
        'project_steps': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ProjectsScreen(
              repository: _FakeProjectRepository(
                projects: [project, emptyProject],
              ),
              paintRepository: _FakePaintRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
      expect(find.text('80%'), findsNothing);
      final progressBars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(progressBars[0].value, 0.4);
      expect(progressBars[1].value, 0);
    },
  );

  testWidgets('shows selected cover images in projects and recent cards', (
    WidgetTester tester,
  ) async {
    final project = PaintingProject(
      id: 'cover-project',
      name: 'Covered Project',
      subject: 'Miniature',
      progress: 0,
      status: ProjectStatus.planned,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFF40536B), Color(0xFF202A38)],
      coverPhotoId: 'cover-photo',
    );
    final photoRepository = _FakeProjectPhotoRepository(onCoverChanged: (_) {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AppNavigation(
          email: 'painter@example.com',
          onLogout: () async {},
          projectRepository: _FakeProjectRepository(projects: [project]),
          paintRepository: _FakePaintRepository(),
          photoRepository: photoRepository,
          schemeRepository: _FakePaintingSchemeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('manages ordered painting steps in project details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        home: MediaQuery(
          data: const MediaQueryData(
            gestureSettings: DeviceGestureSettings(touchSlop: 8),
          ),
          child: ProjectDetailsScreen(
            project: project,
            repository: repository,
            paintRepository: _FakePaintRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No painting steps yet'));
    expect(find.text('Iron Sentinel'), findsNWidgets(2));
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
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
    expect(find.text('0/0'), findsOneWidget);

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

    final firstHandle = find.byIcon(Icons.drag_handle).first;
    await tester.ensureVisible(firstHandle);
    await tester.pumpAndSettle();
    final firstPosition = tester.getCenter(firstHandle);
    expect(
      tester
          .widget<ReorderableDragStartListener>(
            find.byType(ReorderableDragStartListener).first,
          )
          .enabled,
      isTrue,
    );
    final drag = await tester.startGesture(firstPosition);
    await tester.pump(const Duration(milliseconds: 500));
    await drag.moveBy(const Offset(0, 10));
    await tester.pump();
    await drag.moveBy(const Offset(0, 40));
    await tester.pump();
    await drag.moveBy(const Offset(0, 40));
    await tester.pump();
    await drag.moveBy(const Offset(0, 40));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(repository.reorderProjectStepsCalls, 1);
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
    await tester.tap(find.text('Edit step'));
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
    await tester.tap(find.text('Delete step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Basecoat revised'), findsNothing);
    expect(repository.stepsByProject['project-1'], hasLength(1));
    expect((await repository.getProjectSteps('project-1')).single.stepOrder, 1);
  });

  testWidgets('manages reference, cover, and step progress photos', (
    WidgetTester tester,
  ) async {
    final project = PaintingProject(
      id: 'photo-project',
      name: 'Iron Sentinel',
      subject: 'Dreadnought',
      progress: 0,
      status: ProjectStatus.planned,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFF40536B), Color(0xFF202A38)],
    );
    final projectRepository = _FakeProjectRepository(projects: [project]);
    projectRepository.stepsByProject['photo-project'] = [
      const ProjectStep(
        id: 'photo-step',
        projectId: 'photo-project',
        stepOrder: 1,
        title: 'Prime armor',
        instructions: 'Apply primer.',
      ),
    ];
    final photoRepository = _FakeProjectPhotoRepository(
      onCoverChanged: (photoId) {
        projectRepository.coverPhotoId = photoId;
      },
    );
    final photoPicker = _FakeProjectPhotoPicker([
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'reference-one.png',
        mimeType: 'image/png',
      ),
      XFile.fromData(
        Uint8List.fromList([4, 5, 6]),
        name: 'reference-two.png',
        mimeType: 'image/png',
      ),
    ]);

    Future<void> pumpDetails() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ProjectDetailsScreen(
            project: project,
            repository: projectRepository,
            paintRepository: _FakePaintRepository(),
            photoRepository: photoRepository,
            photoPicker: photoPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> chooseGallery() async {
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
    }

    await pumpDetails();
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();
    await chooseGallery();
    expect(photoRepository.photos, hasLength(2));
    expect(find.byTooltip('Set as project cover'), findsNWidgets(2));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Set as project cover').first);
    await tester.tap(find.byTooltip('Set as project cover').first);
    await tester.pumpAndSettle();
    final firstCoverId = photoRepository.photos.first.id;
    expect(projectRepository.coverPhotoId, firstCoverId);

    await tester.ensureVisible(find.byTooltip('Set as project cover').last);
    await tester.tap(find.byTooltip('Set as project cover').last);
    await tester.pumpAndSettle();
    final selectedCoverId = photoRepository.photos.last.id;
    expect(projectRepository.coverPhotoId, selectedCoverId);

    await tester.ensureVisible(find.byTooltip('Delete picture').last);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Delete picture').last);
    await tester.tap(find.byTooltip('Delete picture').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(photoRepository.photos, hasLength(1));
    expect(projectRepository.coverPhotoId, isNull);

    await tester.tap(find.byTooltip('Set as project cover').first);
    await tester.pumpAndSettle();
    expect(projectRepository.coverPhotoId, firstCoverId);
    await tester.pumpWidget(const SizedBox());
    await pumpDetails();
    expect(find.byTooltip('Project cover'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Step actions').first);
    await tester.tap(find.byTooltip('Step actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add progress photo'));
    await tester.pumpAndSettle();
    await chooseGallery();
    expect(photoRepository.photos, hasLength(3));
    expect(find.byTooltip('Delete progress photo'), findsNWidgets(2));
    expect(
      (await projectRepository.getProjectSteps('photo-project'))
          .single
          .isCompleted,
      isFalse,
    );

    await tester.ensureVisible(find.text('Prime armor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.broken_image_outlined).last);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete progress photo').first);
    await tester.pumpAndSettle();
    expect(photoRepository.photos, hasLength(2));
    expect(projectRepository.coverPhotoId, firstCoverId);
  });

  testWidgets('shows detailed photo upload diagnostics in app', (
    WidgetTester tester,
  ) async {
    final project = PaintingProject(
      id: 'diagnostic-project',
      name: 'Diagnostic Project',
      subject: 'Miniature',
      progress: 0,
      status: ProjectStatus.planned,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFF40536B), Color(0xFF202A38)],
    );
    final photoRepository = _FakeProjectPhotoRepository(
      onCoverChanged: (_) {},
      uploadError: ProjectPhotoDiagnosticException(
        stage: 'Storage upload (bucket=project-progress)',
        error: '403 Unauthorized',
        stackTrace: StackTrace.current,
        supabaseDetails:
            'Supabase Storage HTTP status: 403\n'
            'Supabase Storage message: new row violates row-level security policy',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ProjectDetailsScreen(
          project: project,
          repository: _FakeProjectRepository(projects: [project]),
          paintRepository: _FakePaintRepository(),
          photoRepository: photoRepository,
          photoPicker: _FakeProjectPhotoPicker([
            XFile.fromData(
              Uint8List.fromList([1, 2, 3]),
              name: 'test.png',
              mimeType: 'image/png',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Photo upload failed'), findsOneWidget);
    expect(
      find.textContaining('Storage upload (bucket=project-progress)'),
      findsNWidgets(2),
    );
    expect(find.textContaining('403 Unauthorized'), findsOneWidget);
    expect(
      find.textContaining('new row violates row-level security policy'),
      findsOneWidget,
    );
    expect(find.textContaining('Stack trace:'), findsOneWidget);

    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Photo upload failed'), findsOneWidget);
  });

  testWidgets('tracks step completion and associated catalog paints', (
    WidgetTester tester,
  ) async {
    final project = PaintingProject(
      id: 'project-steps',
      name: 'Iron Sentinel',
      subject: 'Dreadnought',
      progress: 0.9,
      status: ProjectStatus.inProgress,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFF40536B), Color(0xFF202A38)],
    );
    final repository = _FakeProjectRepository(projects: [project]);
    repository.stepsByProject['project-steps'] = [
      const ProjectStep(
        id: 'step-1',
        projectId: 'project-steps',
        stepOrder: 1,
        title: 'Prime armor',
        instructions: 'Apply primer.',
      ),
      const ProjectStep(
        id: 'step-2',
        projectId: 'project-steps',
        stepOrder: 2,
        title: 'Basecoat armor',
        instructions: 'Apply the base color.',
      ),
    ];
    final paints = _FakePaintRepository();

    Future<void> pumpDetails() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ProjectDetailsScreen(
            project: project,
            repository: repository,
            paintRepository: paints,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpDetails();
    expect(find.text('0/2'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          )
          .value,
      0,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          )
          .value,
      0.5,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      (await repository.getProjectSteps('project-steps')).first.isCompleted,
      isTrue,
    );
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Add paints').first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Add paints').first);
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(paints.statuses, isEmpty);
    await tester.tap(find.text('Mephiston Red'));
    await tester.tap(find.text('Save paints'));
    await tester.pumpAndSettle();
    expect(
      (await repository.getProjectSteps('project-steps'))
          .first
          .paints
          .single
          .id,
      'red',
    );
    expect(find.text('Mephiston Red'), findsOneWidget);
    expect(find.text('Citadel'), findsOneWidget);
    expect(find.byTooltip('Unowned'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpDetails();
    expect(find.text('1/2'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(find.text('Mephiston Red'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('0/2'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    expect(
      (await repository.getProjectSteps('project-steps')).first.isCompleted,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    await pumpDetails();
    expect(find.text('0/2'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });
}

CatalogPaint _testPaint(String id, String name, String? hexColor) =>
    CatalogPaint(id: id, name: name, hexColor: hexColor);

class _FakePaintingSchemeRepository implements PaintingSchemeRepository {
  _FakePaintingSchemeRepository({List<PaintingScheme>? schemes})
    : schemes = schemes ?? [];

  final List<PaintingScheme> schemes;
  final Map<String, List<PaintingSchemeStep>> _steps = {};
  int _nextSchemeId = 0;
  int _nextStepId = 0;
  int getSchemeCalls = 0;
  int reorderStepsCalls = 0;
  Object? reorderError;

  @override
  Future<List<PaintingScheme>> getSchemes() async => [
    for (final scheme in schemes)
      scheme.copyWith(
        steps: const [],
        stepCount: _steps[scheme.id]?.length ?? scheme.steps.length,
      ),
  ];

  @override
  Future<PaintingScheme> getScheme(String schemeId) async {
    getSchemeCalls++;
    final scheme = schemes.firstWhere((scheme) => scheme.id == schemeId);
    final steps = _steps.putIfAbsent(schemeId, () => [...scheme.steps]);
    steps.sort((first, second) => first.stepOrder.compareTo(second.stepOrder));
    return scheme.copyWith(steps: [...steps]);
  }

  @override
  Future<PaintingScheme> createScheme({
    required String name,
    String? description,
    XFile? previewImage,
  }) async {
    final scheme = PaintingScheme(
      id: 'scheme-${_nextSchemeId++}',
      name: name,
      description: description,
    );
    schemes.add(scheme);
    return scheme;
  }

  @override
  Future<PaintingScheme> updateScheme({
    required PaintingScheme scheme,
    required String name,
    String? description,
    XFile? previewImage,
    bool removePreview = false,
  }) async {
    final updated = scheme.copyWith(
      name: name,
      description: description,
      clearDescription: description?.trim().isEmpty ?? true,
    );
    schemes[schemes.indexWhere((item) => item.id == scheme.id)] = updated;
    return updated;
  }

  @override
  Future<void> deleteScheme(PaintingScheme scheme) async {
    schemes.removeWhere((item) => item.id == scheme.id);
    _steps.remove(scheme.id);
  }

  @override
  Future<PaintingScheme> duplicateScheme(PaintingScheme scheme) async {
    final original = await getScheme(scheme.id);
    final copy = PaintingScheme(
      id: 'scheme-${_nextSchemeId++}',
      name: '${original.name} (copy)',
      description: original.description,
    );
    schemes.add(copy);
    _steps[copy.id] = [
      for (final step in original.steps)
        PaintingSchemeStep(
          id: 'step-${_nextStepId++}',
          schemeId: copy.id,
          stepOrder: step.stepOrder,
          title: step.title,
          description: step.description,
          paints: step.paints,
        ),
    ];
    return copy;
  }

  @override
  Future<PaintingSchemeStep> createStep({
    required String schemeId,
    required String title,
    required String description,
  }) async {
    final steps = _steps.putIfAbsent(
      schemeId,
      () => [...schemes.firstWhere((scheme) => scheme.id == schemeId).steps],
    );
    final maxOrder = steps.fold<int>(
      0,
      (maximum, step) => maximum > step.stepOrder ? maximum : step.stepOrder,
    );
    final step = PaintingSchemeStep(
      id: 'step-${_nextStepId++}',
      schemeId: schemeId,
      stepOrder: maxOrder + 1,
      title: title,
      description: description,
    );
    steps.add(step);
    steps.sort((first, second) => first.stepOrder.compareTo(second.stepOrder));
    return step;
  }

  @override
  Future<void> updateStep(PaintingSchemeStep step) async {
    final steps = _steps[step.schemeId]!;
    final index = steps.indexWhere((item) => item.id == step.id);
    steps[index] = step;
  }

  @override
  Future<void> deleteStep(PaintingSchemeStep step) async {
    final steps = _steps.putIfAbsent(
      step.schemeId,
      () => [
        ...schemes.firstWhere((scheme) => scheme.id == step.schemeId).steps,
      ],
    );
    steps.removeWhere((item) => item.id == step.id);
    await reorderSteps(step.schemeId, steps.map((step) => step.id).toList());
  }

  @override
  Future<void> setStepPaints(
    PaintingSchemeStep step,
    List<CatalogPaint> paints,
  ) async {
    final steps = _steps.putIfAbsent(
      step.schemeId,
      () => [
        ...schemes.firstWhere((scheme) => scheme.id == step.schemeId).steps,
      ],
    );
    final index = steps.indexWhere((item) => item.id == step.id);
    final existing = steps[index];
    steps[index] = PaintingSchemeStep(
      id: existing.id,
      schemeId: existing.schemeId,
      stepOrder: existing.stepOrder,
      title: existing.title,
      description: existing.description,
      paints: paints,
    );
  }

  @override
  Future<void> reorderSteps(
    String schemeId,
    List<String> orderedStepIds,
  ) async {
    reorderStepsCalls++;
    if (reorderError != null) throw reorderError!;
    final steps = _steps.putIfAbsent(
      schemeId,
      () => [...schemes.firstWhere((scheme) => scheme.id == schemeId).steps],
    );
    final byId = {for (final step in steps) step.id: step};
    _steps[schemeId] = [
      for (var index = 0; index < orderedStepIds.length; index++)
        PaintingSchemeStep(
          id: byId[orderedStepIds[index]]!.id,
          schemeId: schemeId,
          stepOrder: index + 1,
          title: byId[orderedStepIds[index]]!.title,
          description: byId[orderedStepIds[index]]!.description,
          paints: byId[orderedStepIds[index]]!.paints,
        ),
    ];
  }

  @override
  Future<String> createProjectFromScheme({
    required String name,
    required String subject,
    required String schemeId,
  }) => Future.error(UnsupportedError('Not used in this test.'));
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
  String? coverPhotoId;
  int reorderProjectStepsCalls = 0;
  final Map<String, List<ProjectStep>> stepsByProject = {};

  @override
  Future<List<PaintingProject>> getProjects() async => [...projects];

  @override
  Future<List<PaintingProject>> getRecentProjects() async {
    if (projects.isEmpty) return [];
    final completedProjects =
        projects
            .where((project) => project.lastStepCompletedAt != null)
            .toList()
          ..sort(
            (first, second) => second.lastStepCompletedAt!.compareTo(
              first.lastStepCompletedAt!,
            ),
          );
    final featuredProject = completedProjects.isEmpty
        ? projects.first
        : completedProjects.first;
    return [
      featuredProject,
      ...projects
          .where((project) => !identical(project, featuredProject))
          .take(2),
    ];
  }

  @override
  Future<PaintingProject> getProject(String projectId) async {
    final project = projects.firstWhere((project) => project.id == projectId);
    return project.copyWith(coverPhotoId: coverPhotoId);
  }

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
  Future<void> setProjectStepCompleted(
    ProjectStep step, {
    required bool isCompleted,
  }) async {
    final steps = stepsByProject[step.projectId]!;
    final index = steps.indexWhere((item) => item.id == step.id);
    steps[index] = steps[index].copyWith(isCompleted: isCompleted);
    _refreshProjectStatus(step.projectId);
  }

  @override
  Future<void> setProjectStepPaints(
    ProjectStep step,
    List<CatalogPaint> paints,
  ) async {
    final steps = stepsByProject[step.projectId]!;
    final index = steps.indexWhere((item) => item.id == step.id);
    steps[index] = steps[index].copyWith(paints: paints);
  }

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
    _refreshProjectStatus(projectId);
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
        isCompleted: step.isCompleted,
        paints: step.paints,
      );
    }
    _refreshProjectStatus(step.projectId);
  }

  @override
  Future<void> reorderProjectSteps(
    String projectId,
    List<String> orderedStepIds,
  ) async {
    reorderProjectStepsCalls++;
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
          isCompleted: stepsById[orderedStepIds[index]]!.isCompleted,
          paints: stepsById[orderedStepIds[index]]!.paints,
        ),
    ];
  }

  @override
  Future<PaintingProject> updateProject(PaintingProject project) async {
    final index = projects.indexWhere((item) => item.id == project.id);
    final saved = _projectWithCurrentStepStatus(project);
    projects[index] = saved;
    return saved;
  }

  void _refreshProjectStatus(String projectId) {
    final index = projects.indexWhere((project) => project.id == projectId);
    if (index == -1) return;
    projects[index] = _projectWithCurrentStepStatus(projects[index]);
  }

  PaintingProject _projectWithCurrentStepStatus(PaintingProject project) {
    final steps = stepsByProject[project.id] ?? [];
    final completedCount = steps.where((step) => step.isCompleted).length;
    final status = project.status == ProjectStatus.completed
        ? ProjectStatus.completed
        : completedCount == 0
        ? ProjectStatus.planned
        : ProjectStatus.inProgress;
    return PaintingProject(
      id: project.id,
      name: project.name,
      subject: project.subject,
      progress: project.progress,
      status: status,
      icon: project.icon,
      colors: project.colors,
      completedStepCount: completedCount,
      totalStepCount: steps.length,
    );
  }
}

class _FakePaintRepository implements PaintRepository {
  _FakePaintRepository({
    List<PaintBrand>? brands,
    Map<String, List<CatalogPaint>>? paintsByBrand,
  }) : brands =
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
           ],
       paintsByBrand = paintsByBrand ?? _defaultPaintsByBrand;

  final List<PaintBrand> brands;
  final Map<String, List<CatalogPaint>> paintsByBrand;
  String? lastRequestedBrandId;
  final Map<String, PaintOwnershipStatus> statuses = {};

  static const _defaultPaintsByBrand = {
    'citadel': [
      CatalogPaint(
        id: 'red',
        name: 'Mephiston Red',
        brandName: 'Citadel',
        paintType: 'Base',
        hexColor: '#9E1B25',
      ),
      CatalogPaint(
        id: 'metal',
        name: 'Leadbelcher',
        brandName: 'Citadel',
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
    return (paintsByBrand[brandId] ?? [])
        .map(
          (paint) => paint.withUserStatus(
            statuses[paint.id] ?? PaintOwnershipStatus.unowned,
          ),
        )
        .toList();
  }

  @override
  Future<List<CatalogPaint>> getCatalogPaints() async => [
    for (final paints in paintsByBrand.values) ...paints,
  ];

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

class _FakeProjectPhotoPicker implements ProjectPhotoPicker {
  const _FakeProjectPhotoPicker(this.images);

  final List<XFile> images;

  @override
  Future<List<XFile>> pickImages({required bool fromCamera}) async => images;
}

class _FakeProjectPhotoRepository implements ProjectPhotoRepository {
  _FakeProjectPhotoRepository({required this.onCoverChanged, this.uploadError});

  final void Function(String?) onCoverChanged;
  final Object? uploadError;
  final List<ProjectPhoto> photos = [];
  int _nextId = 0;
  String? _coverPhotoId;

  @override
  Future<List<ProjectPhoto>> getProjectPhotos(String projectId) async =>
      photos.where((photo) => photo.projectId == projectId).toList();

  @override
  Future<ProjectPhoto> uploadPhoto({
    required String projectId,
    required XFile image,
    String? projectStepId,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    final photo = ProjectPhoto(
      id: 'photo-${_nextId++}',
      projectId: projectId,
      projectStepId: projectStepId,
      storagePath: '$projectId/${image.name}',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    photos.add(photo);
    return photo;
  }

  @override
  Future<void> setCoverPhoto(String projectId, String? photoId) async {
    _coverPhotoId = photoId;
    onCoverChanged(photoId);
  }

  @override
  Future<void> deletePhoto(ProjectPhoto photo) async {
    photos.removeWhere((item) => item.id == photo.id);
    if (_coverPhotoId == photo.id) {
      _coverPhotoId = null;
      onCoverChanged(null);
    }
  }

  @override
  Future<String> getSignedUrlForPhoto(String photoId) async =>
      'https://example.test/$photoId';
}
