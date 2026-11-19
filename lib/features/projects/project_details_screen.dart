import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../../widgets/painting_step_paints.dart';
import '../paints/paint_repository.dart';
import 'project_form_dialog.dart';
import 'project_photo_repository.dart';
import 'project_photo_viewer.dart';
import 'project_repository.dart';
import 'project_step_form_dialog.dart';
import 'step_paint_picker_dialog.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.project,
    required this.repository,
    required this.paintRepository,
    this.photoRepository,
    this.photoPicker,
  });

  final PaintingProject project;
  final ProjectRepository repository;
  final PaintRepository paintRepository;
  final ProjectPhotoRepository? photoRepository;
  final ProjectPhotoPicker? photoPicker;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late PaintingProject _project;
  List<ProjectStep> _steps = [];
  bool _isLoading = true;
  bool _isReorderingSteps = false;
  String? _error;
  final Set<String> _updatingSteps = {};
  List<ProjectPhoto> _photos = [];
  bool _isUploadingReferencePhotos = false;
  final Set<String> _uploadingStepPhotos = {};
  late final ProjectPhotoPicker _photoPicker;

  String? get _projectId => _project.id;
  ProjectPhoto? get _coverPhoto {
    final coverPhotoId = _project.coverPhotoId;
    if (coverPhotoId == null) return null;
    for (final photo in _photos) {
      if (photo.id == coverPhotoId) return photo;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _photoPicker = widget.photoPicker ?? DeviceProjectPhotoPicker();
    _loadProject();
  }

  Future<void> _loadProject() async {
    final projectId = _projectId;
    if (projectId == null) {
      setState(() {
        _error = 'This project does not have a valid ID.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final project = await widget.repository.getProject(projectId);
      final steps = await widget.repository.getProjectSteps(projectId);
      final photos = widget.photoRepository == null
          ? <ProjectPhoto>[]
          : await widget.photoRepository!.getProjectPhotos(projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _steps = [...steps]..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
        _photos = photos;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = projectDetailsErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _addStep() async {
    final projectId = _projectId;
    if (projectId == null) return;

    final step = await showDialog<ProjectStep>(
      context: context,
      builder: (_) => ProjectStepFormDialog(
        onSave: (title, instructions) => widget.repository.createProjectStep(
          projectId: projectId,
          title: title,
          instructions: instructions,
        ),
      ),
    );
    if (step != null) await _loadProject();
  }

  Future<void> _editProject() async {
    final updated = await showDialog<PaintingProject>(
      context: context,
      builder: (_) => ProjectFormDialog(
        project: _project,
        onSave: widget.repository.updateProject,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _project = updated);
    await _loadProject();
  }

  Future<void> _editStep(ProjectStep step) async {
    final updated = await showDialog<ProjectStep>(
      context: context,
      builder: (_) => ProjectStepFormDialog(
        step: step,
        onSave: (title, instructions) => widget.repository.updateProjectStep(
          ProjectStep(
            id: step.id,
            projectId: step.projectId,
            stepOrder: step.stepOrder,
            title: title,
            instructions: instructions,
            isCompleted: step.isCompleted,
            paints: step.paints,
          ),
        ),
      ),
    );
    if (updated != null) await _loadProject();
  }

  Future<void> _reorderSteps(int oldIndex, int newIndex) async {
    final projectId = _projectId;
    if (projectId == null ||
        _isReorderingSteps ||
        oldIndex < 0 ||
        oldIndex >= _steps.length ||
        newIndex < 0 ||
        newIndex >= _steps.length ||
        oldIndex == newIndex) {
      return;
    }

    final originalSteps = _steps;
    final reorderedSteps = [..._steps];
    final movedStep = reorderedSteps.removeAt(oldIndex);
    // onReorderItem already adjusts newIndex when moving an item downward.
    reorderedSteps.insert(newIndex, movedStep);
    final orderedSteps = [
      for (var index = 0; index < reorderedSteps.length; index++)
        ProjectStep(
          id: reorderedSteps[index].id,
          projectId: reorderedSteps[index].projectId,
          stepOrder: index + 1,
          title: reorderedSteps[index].title,
          instructions: reorderedSteps[index].instructions,
          isCompleted: reorderedSteps[index].isCompleted,
          paints: reorderedSteps[index].paints,
        ),
    ];
    final orderedStepIds = orderedSteps.map((step) => step.id).toList();
    if (orderedStepIds.any((id) => id == null)) {
      _showError('Could not reorder a step without a saved ID.');
      return;
    }

    setState(() {
      _isReorderingSteps = true;
      _steps = orderedSteps;
    });
    try {
      await widget.repository.reorderProjectSteps(
        projectId,
        orderedStepIds.whereType<String>().toList(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _steps = originalSteps);
        _showError(projectDetailsErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isReorderingSteps = false);
    }
  }

  Future<void> _toggleStep(ProjectStep step, bool isCompleted) async {
    final stepId = step.id;
    if (stepId == null || _updatingSteps.contains(stepId)) return;
    final index = _steps.indexWhere((item) => item.id == stepId);
    if (index == -1) return;

    setState(() {
      _updatingSteps.add(stepId);
      _steps[index] = step.copyWith(isCompleted: isCompleted);
    });
    try {
      await widget.repository.setProjectStepCompleted(
        step,
        isCompleted: isCompleted,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          final currentIndex = _steps.indexWhere((item) => item.id == stepId);
          if (currentIndex != -1) {
            _steps[currentIndex] = _steps[currentIndex].copyWith(
              isCompleted: step.isCompleted,
            );
          }
        });
        _showError(projectDetailsErrorMessage(error));
      }
    } finally {
      _updatingSteps.remove(stepId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _manageStepPaints(ProjectStep step) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StepPaintPickerDialog(
        stepTitle: step.title,
        selectedPaints: step.paints,
        paintRepository: widget.paintRepository,
        onSave: (paints) =>
            widget.repository.setProjectStepPaints(step, paints),
      ),
    );
    if (saved == true) await _loadProject();
  }

  Future<void> _choosePhotos({String? projectStepId}) async {
    if (widget.photoRepository == null) {
      _showError('Photo management is unavailable right now.');
      return;
    }
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.appPalette.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (fromCamera == null || !mounted) return;
    await _pickAndUploadPhotos(
      projectStepId: projectStepId,
      fromCamera: fromCamera,
    );
  }

  Future<void> _pickAndUploadPhotos({
    required bool fromCamera,
    String? projectStepId,
  }) async {
    final projectId = _projectId;
    if (projectId == null) return;
    if (projectStepId == null) {
      setState(() => _isUploadingReferencePhotos = true);
    } else {
      setState(() => _uploadingStepPhotos.add(projectStepId));
    }

    try {
      final images = await _photoPicker.pickImages(fromCamera: fromCamera);
      debugPrint(
        '[ProjectPhoto] Upload flow received ${images.length} selected '
        'image(s): ${images.map((image) => image.name).join(", ")}.',
      );
      for (final image in images) {
        final photo = await widget.photoRepository!.uploadPhoto(
          projectId: projectId,
          image: image,
          projectStepId: projectStepId,
        );
        if (mounted) setState(() => _photos = [..._photos, photo]);
      }
    } catch (error, stackTrace) {
      debugPrint('[ProjectPhoto] Upload flow failed: $error');
      debugPrint('[ProjectPhoto] Upload flow stack trace:\n$stackTrace');
      await _showPhotoDiagnostic(error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingReferencePhotos = false;
          if (projectStepId != null) {
            _uploadingStepPhotos.remove(projectStepId);
          }
        });
      }
    }
  }

  Future<void> _selectCover(ProjectPhoto photo) async {
    try {
      await widget.photoRepository!.setCoverPhoto(_project.id!, photo.id);
      if (mounted) {
        setState(() => _project = _project.copyWith(coverPhotoId: photo.id));
      }
    } catch (error) {
      _showError(projectPhotoErrorMessage(error));
    }
  }

  Future<void> _deletePhoto(ProjectPhoto photo) async {
    try {
      await widget.photoRepository!.deletePhoto(photo);
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((item) => item.id != photo.id).toList();
        if (_project.coverPhotoId == photo.id) {
          _project = _project.copyWith(clearCover: true);
        }
      });
    } catch (error) {
      _showError(projectPhotoErrorMessage(error));
    }
  }

  Future<void> _openPhoto(ProjectPhoto photo) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ProjectPhotoViewer(photo: photo)),
  );

  Future<void> _deleteStep(ProjectStep step) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete step?'),
        content: Text(
          'Delete "${step.title}" and its progress photos? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      if (widget.photoRepository != null) {
        for (final photo in _photos.where(
          (photo) => photo.projectStepId == step.id,
        )) {
          await widget.photoRepository!.deletePhoto(photo);
        }
      }
      await widget.repository.deleteProjectStep(step);
      await _loadProject();
    } catch (error) {
      _showError(projectDetailsErrorMessage(error));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPhotoDiagnostic(Object error, StackTrace stackTrace) async {
    if (!mounted) return;
    final diagnostic = error is ProjectPhotoDiagnosticException
        ? error.toString()
        : ProjectPhotoDiagnosticException(
            stage: 'image selection/upload flow',
            error: error,
            stackTrace: stackTrace,
          ).toString();
    final friendlyMessage = projectPhotoErrorMessage(error);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Photo upload failed'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friendlyMessage),
                const SizedBox(height: 12),
                const Text(
                  'Diagnostic details (copy these to share the error):',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  diagnostic,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: diagnostic));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Diagnostics copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy diagnostics'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = _project.status == ProjectStatus.completed
        ? ProjectStatus.completed
        : _steps.any((step) => step.isCompleted)
        ? ProjectStatus.inProgress
        : ProjectStatus.planned;
    final status = switch (effectiveStatus) {
      ProjectStatus.inProgress => 'In progress',
      ProjectStatus.planned => 'Planned',
      ProjectStatus.completed => 'Completed',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_project.name),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            onPressed: _isLoading || _error != null ? null : _editProject,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.appPalette.accent,
              ),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadProject,
              color: context.appPalette.accent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildProjectSummary(status),
                        const SizedBox(height: 18),
                        _buildReferencePhotos(),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Painting steps',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _addStep,
                              icon: const Icon(Icons.add),
                              label: const Text('Add step'),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.appPalette.accent,
                                foregroundColor: context.appPalette.onAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drag to reorder. Use the checkbox to track progress.',
                          style: TextStyle(color: context.appPalette.mutedText),
                        ),
                        const SizedBox(height: 14),
                        if (_steps.isEmpty) _buildEmptySteps(),
                      ]),
                    ),
                  ),
                  if (_steps.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverReorderableList(
                        itemCount: _steps.length,
                        onReorderItem: _reorderSteps,
                        itemBuilder: (context, index) {
                          final step = _steps[index];
                          return _StepCard(
                            key: ValueKey(step.id ?? 'unsaved-$index'),
                            step: step,
                            stepNumber: index + 1,
                            canReorder: !_isReorderingSteps && step.id != null,
                            onEdit: () => _editStep(step),
                            onDelete: () => _deleteStep(step),
                            onToggleCompleted: (isCompleted) =>
                                _toggleStep(step, isCompleted),
                            isUpdating: _updatingSteps.contains(step.id),
                            onManagePaints: () => _manageStepPaints(step),
                            photos: _photos
                                .where(
                                  (photo) => photo.projectStepId == step.id,
                                )
                                .toList(),
                            isUploadingPhotos: _uploadingStepPhotos.contains(
                              step.id,
                            ),
                            onAddPhoto: () =>
                                _choosePhotos(projectStepId: step.id),
                            onPhotoTap: _openPhoto,
                            onPhotoDelete: _deletePhoto,
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: context.appPalette.mutedText),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildReferencePhotos() {
    final referencePhotos = _photos
        .where((photo) => photo.projectStepId == null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Reference pictures',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed:
                  _isUploadingReferencePhotos || widget.photoRepository == null
                  ? null
                  : () => _choosePhotos(),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (referencePhotos.isEmpty && !_isUploadingReferencePhotos)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.collections_outlined,
                  color: context.appPalette.accent,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep inspiration close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add reference pictures for this project.',
                  style: TextStyle(color: context.appPalette.mutedText),
                ),
                TextButton.icon(
                  onPressed: widget.photoRepository == null
                      ? null
                      : () => _choosePhotos(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add reference pictures'),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount:
                referencePhotos.length + (_isUploadingReferencePhotos ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == referencePhotos.length) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.appPalette.accent,
                  ),
                );
              }
              final photo = referencePhotos[index];
              final isCover = _project.coverPhotoId == photo.id;
              return _ProjectPhotoTile(
                photo: photo,
                isCover: isCover,
                onTap: () => _openPhoto(photo),
                onSelectCover: isCover ? null : () => _selectCover(photo),
                onDelete: () => _confirmDeletePhoto(photo),
              );
            },
          ),
        if (referencePhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _project.coverPhotoId == null
                  ? 'Choose a picture to use as the project cover.'
                  : 'The star marks this project’s cover picture.',
              style: TextStyle(
                color: context.appPalette.mutedText,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDeletePhoto(ProjectPhoto photo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete picture?'),
        content: const Text('This picture will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await _deletePhoto(photo);
  }

  Widget _buildProjectSummary(String status) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _project.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_coverPhoto?.signedUrl != null)
              Image.network(
                _coverPhoto!.signedUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    '[ProjectPhoto] Cover image load failed: '
                    'photo=${_project.coverPhotoId}, error=$error\n$stackTrace',
                  );
                  return Center(
                    child: Icon(_project.icon, color: Colors.white, size: 60),
                  );
                },
              )
            else
              Center(child: Icon(_project.icon, color: Colors.white, size: 60)),
            if (_coverPhoto != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber.shade300,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(_project.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(_project.subject, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appPalette.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(status, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${_steps.where((step) => step.isCompleted).length}/${_steps.length}',
                  style: TextStyle(
                    color: context.appPalette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _steps.isEmpty
                    ? 0
                    : _steps.where((step) => step.isCompleted).length /
                          _steps.length,
                minHeight: 7,
                backgroundColor: context.appPalette.elevatedSurface,
                color: context.appPalette.accent,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildEmptySteps() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: context.appPalette.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(
          Icons.format_list_numbered,
          color: context.appPalette.accent,
          size: 36,
        ),
        SizedBox(height: 12),
        Text(
          'No painting steps yet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'Add your first step to plan this miniature’s painting process.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appPalette.mutedText),
        ),
      ],
    ),
  );
}

class _ProjectPhotoTile extends StatelessWidget {
  const _ProjectPhotoTile({
    required this.photo,
    required this.isCover,
    required this.onTap,
    required this.onSelectCover,
    required this.onDelete,
  });

  final ProjectPhoto photo;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback? onSelectCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: context.appPalette.elevatedSurface,
          child: InkWell(
            onTap: onTap,
            child: photo.signedUrl == null
                ? const Center(child: Icon(Icons.broken_image_outlined))
                : Image.network(
                    photo.signedUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        '[ProjectPhoto] Gallery image load failed: '
                        'photo=${photo.id}, error=$error\n$stackTrace',
                      );
                      return const Center(
                        child: Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            tooltip: 'Delete picture',
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              minimumSize: const Size(30, 30),
            ),
            icon: const Icon(Icons.delete_outline, size: 17),
          ),
        ),
        Positioned(
          left: 3,
          bottom: 3,
          child: isCover
              ? const Tooltip(
                  message: 'Project cover',
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.star, color: Colors.amber, size: 18),
                  ),
                )
              : IconButton(
                  tooltip: 'Set as project cover',
                  onPressed: onSelectCover,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(30, 30),
                  ),
                  icon: const Icon(Icons.star_border, size: 18),
                ),
        ),
      ],
    ),
  );
}

class _StepPhotoPreview extends StatelessWidget {
  const _StepPhotoPreview({
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  final ProjectPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: context.appPalette.elevatedSurface,
            child: InkWell(
              onTap: onTap,
              child: photo.signedUrl == null
                  ? const Icon(Icons.broken_image_outlined, size: 18)
                  : Image.network(
                      photo.signedUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                          '[ProjectPhoto] Step preview load failed: '
                          'photo=${photo.id}, error=$error\n$stackTrace',
                        );
                        return const Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                        );
                      },
                    ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Delete progress photo',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 20, height: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.close, size: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.canReorder,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleCompleted,
    required this.isUpdating,
    required this.onManagePaints,
    required this.photos,
    required this.isUploadingPhotos,
    required this.onAddPhoto,
    required this.onPhotoTap,
    required this.onPhotoDelete,
  });

  final ProjectStep step;
  final int stepNumber;
  final bool canReorder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleCompleted;
  final bool isUpdating;
  final VoidCallback onManagePaints;
  final List<ProjectPhoto> photos;
  final bool isUploadingPhotos;
  final VoidCallback onAddPhoto;
  final ValueChanged<ProjectPhoto> onPhotoTap;
  final ValueChanged<ProjectPhoto> onPhotoDelete;

  @override
  Widget build(BuildContext context) => Card(
    key: key,
    margin: const EdgeInsets.only(bottom: 8),
    color: context.appPalette.surface,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: stepNumber - 1,
                enabled: canReorder,
                child: Icon(
                  Icons.drag_handle,
                  color: context.appPalette.mutedText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appPalette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.appPalette.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                    color: context.appPalette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  step.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: step.isCompleted
                    ? 'Mark step incomplete'
                    : 'Mark step complete',
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Checkbox(
                    value: step.isCompleted,
                    onChanged: isUpdating
                        ? null
                        : (value) {
                            if (value != null) onToggleCompleted(value);
                          },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Step actions',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                onSelected: (action) {
                  if (action == 'photo') {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onAddPhoto(),
                    );
                  }
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'photo',
                    enabled: !isUploadingPhotos,
                    child: Text(
                      isUploadingPhotos
                          ? 'Uploading progress photo'
                          : 'Add progress photo',
                    ),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit step')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete step'),
                  ),
                ],
              ),
            ],
          ),
          if (step.instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 41, top: 4),
              child: Text(
                step.instructions,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appPalette.mutedText,
                  height: 1.35,
                ),
              ),
            ),
          if (photos.isNotEmpty || isUploadingPhotos)
            Padding(
              padding: EdgeInsets.only(
                left: 41,
                top: step.instructions.isEmpty ? 8 : 6,
              ),
              child: photos.isEmpty
                  ? Row(
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: context.appPalette.mutedText,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Adding progress photo',
                            style: TextStyle(
                              color: context.appPalette.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: context.appPalette.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: context.appPalette.mutedText,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${photos.length}',
                            style: TextStyle(
                              color: context.appPalette.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final photo in photos)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _StepPhotoPreview(
                                      photo: photo,
                                      onTap: () => onPhotoTap(photo),
                                      onDelete: () => onPhotoDelete(photo),
                                    ),
                                  ),
                                if (isUploadingPhotos)
                                  SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: context.appPalette.accent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          PaintingStepPaints(paints: step.paints, onEdit: onManagePaints),
        ],
      ),
    ),
  );
}
