import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
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
import 'package:paint_app/features/projects/project_repository.dart';
import 'package:paint_app/features/projects/projects_screen.dart';

void main() {
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
          photoRepository: _FakeProjectPhotoRepository(onCoverChanged: (_) {}),
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
          photoRepository: _FakeProjectPhotoRepository(onCoverChanged: (_) {}),
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

  testWidgets('home shows two recent projects and opens their details', (
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Ashen Knight'), findsOneWidget);
    expect(find.text('Mossback Guardian'), findsOneWidget);
    expect(find.text('The Gilded Wyrm'), findsNothing);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    final recentProgressBars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(recentProgressBars[0].value, 0.4);
    expect(recentProgressBars[1].value, 0);

    await tester.tap(find.text('The Ashen Knight'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Painting steps'));
    expect(find.text('Painting steps'), findsOneWidget);
    expect(find.text('Painting steps'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('The Ashen Knight'), findsOneWidget);
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
        home: ProjectDetailsScreen(
          project: project,
          repository: repository,
          paintRepository: _FakePaintRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add progress photo'));
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      (await repository.getProjectSteps('project-steps')).first.isCompleted,
      isTrue,
    );
    await tester.tap(find.text('Prime armor'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add paints'));
    await tester.tap(find.widgetWithText(TextButton, 'Add paints'));
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
    expect(find.text('Mephiston Red · Citadel'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpDetails();
    expect(find.text('1/2'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    await tester.tap(find.text('Prime armor'));
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red · Citadel'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });
}

CatalogPaint _testPaint(String id, String name, String? hexColor) =>
    CatalogPaint(id: id, name: name, hexColor: hexColor);

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
  final Map<String, List<ProjectStep>> stepsByProject = {};

  @override
  Future<List<PaintingProject>> getProjects() async => [...projects];

  @override
  Future<List<PaintingProject>> getRecentProjects() async =>
      projects.take(2).toList();

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
