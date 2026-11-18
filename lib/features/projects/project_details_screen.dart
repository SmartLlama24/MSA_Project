import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import '../paints/paint_repository.dart';
import 'project_form_dialog.dart';
import 'project_photo_repository.dart';
import 'project_photo_viewer.dart';
import 'project_repository.dart';
import 'step_paint_picker_dialog.dart';
import 'project_step_form_dialog.dart';

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

  Future<void> _moveStep(int index, int direction) async {
    final projectId = _projectId;
    if (projectId == null) return;

    final reorderedSteps = [..._steps];
    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= reorderedSteps.length) return;
    final movedStep = reorderedSteps.removeAt(index);
    reorderedSteps.insert(targetIndex, movedStep);
    final orderedStepIds = reorderedSteps.map((step) => step.id).toList();
    if (orderedStepIds.any((id) => id == null)) {
      _showError('Could not reorder a step without a saved ID.');
      return;
    }

    try {
      await widget.repository.reorderProjectSteps(
        projectId,
        orderedStepIds.whereType<String>().toList(),
      );
      await _loadProject();
    } catch (error) {
      _showError(projectDetailsErrorMessage(error));
      await _loadProject();
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
        step: step,
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
      backgroundColor: AppTheme.surface,
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
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadProject,
              color: AppTheme.accent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
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
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF201B12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_steps.isEmpty)
                    _buildEmptySteps()
                  else
                    ..._steps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StepCard(
                          step: entry.value,
                          stepNumber: entry.key + 1,
                          canMoveUp: entry.key > 0,
                          canMoveDown: entry.key < _steps.length - 1,
                          onMoveUp: () => _moveStep(entry.key, -1),
                          onMoveDown: () => _moveStep(entry.key, 1),
                          onEdit: () => _editStep(entry.value),
                          onDelete: () => _deleteStep(entry.value),
                          onToggleCompleted: (isCompleted) =>
                              _toggleStep(entry.value, isCompleted),
                          isUpdating: _updatingSteps.contains(entry.value.id),
                          onManagePaints: () => _manageStepPaints(entry.value),
                          photos: _photos
                              .where(
                                (photo) =>
                                    photo.projectStepId == entry.value.id,
                              )
                              .toList(),
                          isUploadingPhotos: _uploadingStepPhotos.contains(
                            entry.value.id,
                          ),
                          onAddPhoto: () =>
                              _choosePhotos(projectStepId: entry.value.id),
                          onPhotoTap: _openPhoto,
                          onPhotoDelete: _deletePhoto,
                        ),
                      ),
                    ),
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
          const Icon(Icons.cloud_off_outlined, color: AppTheme.mutedText),
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.collections_outlined,
                  color: AppTheme.accent,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep inspiration close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add reference pictures for this project.',
                  style: TextStyle(color: AppTheme.mutedText),
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
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
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
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
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
          color: AppTheme.surface,
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
                  style: const TextStyle(
                    color: AppTheme.accent,
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
                backgroundColor: AppTheme.elevatedSurface,
                color: AppTheme.accent,
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
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      children: [
        Icon(Icons.format_list_numbered, color: AppTheme.accent, size: 36),
        SizedBox(height: 12),
        Text(
          'No painting steps yet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'Add your first step to plan this miniature’s painting process.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedText),
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
          color: AppTheme.elevatedSurface,
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
    width: 56,
    height: 56,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: AppTheme.elevatedSurface,
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
            top: -8,
            right: -8,
            child: IconButton(
              tooltip: 'Delete progress photo',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(26, 26),
              ),
              icon: const Icon(Icons.close, size: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StepCard extends StatefulWidget {
  const _StepCard({
    required this.step,
    required this.stepNumber,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
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
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
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
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: widget.step.isCompleted,
              onChanged: widget.isUpdating
                  ? null
                  : (value) {
                      if (value != null) widget.onToggleCompleted(value);
                    },
              visualDensity: VisualDensity.compact,
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.stepNumber}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.step.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(widget.step.instructions),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Step actions',
              onSelected: (action) {
                if (action == 'edit') widget.onEdit();
                if (action == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Move step up',
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: 'Move step down',
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ],
        ),
        if (widget.photos.isNotEmpty || widget.isUploadingPhotos)
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final photo in widget.photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StepPhotoPreview(
                      photo: photo,
                      onTap: () => widget.onPhotoTap(photo),
                      onDelete: () => widget.onPhotoDelete(photo),
                    ),
                  ),
                if (widget.isUploadingPhotos)
                  const SizedBox(
                    width: 56,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: widget.onAddPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Add photo'),
                  ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onAddPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Add progress photo'),
            ),
          ),
        if (_isExpanded) ...[
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Associated paints',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onManagePaints,
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: Text(widget.step.paints.isEmpty ? 'Add paints' : 'Edit'),
              ),
            ],
          ),
          if (widget.step.paints.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No paints associated with this step.',
                  style: TextStyle(color: AppTheme.mutedText),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.step.paints.map((paint) {
                  final color = paint.color;
                  return Chip(
                    avatar: color == null
                        ? null
                        : CircleAvatar(backgroundColor: color),
                    label: Text(
                      '${paint.name} · ${paint.brandName ?? 'Unknown brand'}',
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    ),
  );
}
