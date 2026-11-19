import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

abstract interface class ProjectRepository {
  Future<List<PaintingProject>> getProjects();

  Future<List<PaintingProject>> getRecentProjects();

  Future<PaintingProject> getProject(String projectId);

  Future<PaintingProject> createProject(PaintingProject project);

  Future<PaintingProject> updateProject(PaintingProject project);

  Future<void> deleteProject(String projectId);

  Future<List<ProjectStep>> getProjectSteps(String projectId);

  Future<void> setProjectStepCompleted(
    ProjectStep step, {
    required bool isCompleted,
  });

  Future<void> setProjectStepPaints(
    ProjectStep step,
    List<CatalogPaint> paints,
  );

  Future<ProjectStep> createProjectStep({
    required String projectId,
    required String title,
    required String instructions,
  });

  Future<ProjectStep> updateProjectStep(ProjectStep step);

  Future<void> deleteProjectStep(ProjectStep step);

  Future<void> reorderProjectSteps(
    String projectId,
    List<String> orderedStepIds,
  );
}

class SupabaseProjectRepository implements ProjectRepository {
  const SupabaseProjectRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required to access projects.');
    }
    return userId;
  }

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw StateError('A signed-in user is required to access project steps.');
    }
  }

  @override
  Future<List<PaintingProject>> getProjects() async {
    final userId = _userId;
    final rows = await _client
        .from('projects')
        .select(
          'id, name, subject, status, progress, cover_photo_id, '
          'project_steps(is_completed)',
        )
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return rows.map(PaintingProject.fromMap).toList();
  }

  @override
  Future<List<PaintingProject>> getRecentProjects() async {
    final userId = _userId;
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from('projects')
          .select(
            'id, name, subject, status, progress, cover_photo_id, '
            'last_step_completed_at, project_steps(is_completed)',
          )
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
    } on PostgrestException catch (error) {
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;

      debugPrint(
        '[Projects] last_step_completed_at is unavailable; '
        'apply the latest Supabase migration to prioritize completed projects.',
      );
      rows = await _client
          .from('projects')
          .select(
            'id, name, subject, status, progress, cover_photo_id, '
            'project_steps(is_completed)',
          )
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
    }
    final projects = rows.map(PaintingProject.fromMap).toList();
    if (projects.isEmpty) return projects;

    var featuredProjectIndex = 0;
    for (var index = 1; index < projects.length; index++) {
      final candidateTime = projects[index].lastStepCompletedAt;
      final featuredTime = projects[featuredProjectIndex].lastStepCompletedAt;
      if (candidateTime != null &&
          (featuredTime == null || candidateTime.isAfter(featuredTime))) {
        featuredProjectIndex = index;
      }
    }

    final featuredProject = projects[featuredProjectIndex];
    return [
      featuredProject,
      ...projects
          .where((project) => !identical(project, featuredProject))
          .take(2),
    ];
  }

  @override
  Future<PaintingProject> getProject(String projectId) async {
    final userId = _userId;
    final row = await _client
        .from('projects')
        .select('id, name, subject, status, progress, cover_photo_id')
        .eq('id', projectId)
        .eq('user_id', userId)
        .single();
    return PaintingProject.fromMap(row);
  }

  @override
  Future<PaintingProject> createProject(PaintingProject project) async {
    final userId = _userId;
    final insertMap = project.toInsertMap(userId: userId)
      ..['status'] = 'planned'
      ..['progress'] = 0;
    final row = await _client
        .from('projects')
        .insert(insertMap)
        .select(
          'id, name, subject, status, progress, cover_photo_id, '
          'project_steps(is_completed)',
        )
        .single();

    return PaintingProject.fromMap(row);
  }

  @override
  Future<PaintingProject> updateProject(PaintingProject project) async {
    final userId = _userId;
    final projectId = project.id;
    if (projectId == null) {
      throw ArgumentError('A project ID is required to update a project.');
    }

    final steps = await _client
        .from('project_steps')
        .select('is_completed')
        .eq('project_id', projectId);
    final hasCompletedSteps = steps.any((step) => step['is_completed'] == true);
    final status = project.status == ProjectStatus.completed
        ? ProjectStatus.completed
        : hasCompletedSteps
        ? ProjectStatus.inProgress
        : ProjectStatus.planned;
    final row = await _client
        .from('projects')
        .update({...project.toUpdateMap(), 'status': _statusToDatabase(status)})
        .eq('id', projectId)
        .eq('user_id', userId)
        .select(
          'id, name, subject, status, progress, cover_photo_id, '
          'project_steps(is_completed)',
        )
        .single();

    return PaintingProject.fromMap(row);
  }

  String _statusToDatabase(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => 'planned',
    ProjectStatus.inProgress => 'in_progress',
    ProjectStatus.completed => 'completed',
  };

  @override
  Future<void> deleteProject(String projectId) async {
    final userId = _userId;
    await _client
        .from('projects')
        .delete()
        .eq('id', projectId)
        .eq('user_id', userId);
  }

  @override
  Future<List<ProjectStep>> getProjectSteps(String projectId) async {
    _requireSignedIn();
    final rows = await _client
        .from('project_steps')
        .select(
          'id, project_id, step_order, title, instructions, is_completed, '
          'step_paints(paints(id, name, paint_type, hex_color, paint_brands(name)))',
        )
        .eq('project_id', projectId)
        .order('step_order');
    return rows.map(ProjectStep.fromMap).toList();
  }

  @override
  Future<void> setProjectStepCompleted(
    ProjectStep step, {
    required bool isCompleted,
  }) async {
    _requireSignedIn();
    final stepId = step.id;
    if (stepId == null) {
      throw ArgumentError('A step ID is required to update completion.');
    }

    await _client
        .from('project_steps')
        .update({'is_completed': isCompleted})
        .eq('id', stepId)
        .eq('project_id', step.projectId)
        .select('id')
        .single();
  }

  @override
  Future<void> setProjectStepPaints(
    ProjectStep step,
    List<CatalogPaint> paints,
  ) async {
    _requireSignedIn();
    final stepId = step.id;
    if (stepId == null) {
      throw ArgumentError('A step ID is required to manage its paints.');
    }

    final existingIds = step.paints.map((paint) => paint.id).toSet();
    final selectedPaints = {for (final paint in paints) paint.id: paint};
    final selectedIds = selectedPaints.keys.toSet();
    final addedIds = selectedIds.difference(existingIds);
    final removedIds = existingIds.difference(selectedIds);

    if (addedIds.isNotEmpty) {
      await _client
          .from('step_paints')
          .upsert(
            addedIds
                .map((paintId) => {'step_id': stepId, 'paint_id': paintId})
                .toList(),
            onConflict: 'step_id,paint_id',
            ignoreDuplicates: true,
          );
    }
    for (final paintId in removedIds) {
      await _client
          .from('step_paints')
          .delete()
          .eq('step_id', stepId)
          .eq('paint_id', paintId);
    }
  }

  @override
  Future<ProjectStep> createProjectStep({
    required String projectId,
    required String title,
    required String instructions,
  }) async {
    _requireSignedIn();
    final steps = await _client
        .from('project_steps')
        .select('id, project_id, step_order, title, instructions')
        .eq('project_id', projectId)
        .order('step_order');
    final existingSteps = steps.map(ProjectStep.fromMap).toList();
    await _persistStepOrder(
      projectId,
      existingSteps,
      existingSteps.map((step) => step.id!).toList(),
    );
    final nextOrder = existingSteps.length + 1;
    final row = await _client
        .from('project_steps')
        .insert({
          'project_id': projectId,
          'step_order': nextOrder,
          'title': title,
          'instructions': instructions,
        })
        .select('id, project_id, step_order, title, instructions')
        .single();
    return ProjectStep.fromMap(row);
  }

  @override
  Future<ProjectStep> updateProjectStep(ProjectStep step) async {
    _requireSignedIn();
    final stepId = step.id;
    if (stepId == null) {
      throw ArgumentError('A step ID is required to update a step.');
    }
    final row = await _client
        .from('project_steps')
        .update(step.toUpdateMap())
        .eq('id', stepId)
        .eq('project_id', step.projectId)
        .select('id, project_id, step_order, title, instructions')
        .single();
    return ProjectStep.fromMap(row);
  }

  @override
  Future<void> deleteProjectStep(ProjectStep step) async {
    _requireSignedIn();
    final stepId = step.id;
    if (stepId == null) {
      throw ArgumentError('A step ID is required to delete a step.');
    }
    await _client
        .from('project_steps')
        .delete()
        .eq('id', stepId)
        .eq('project_id', step.projectId)
        .select('id')
        .single();
    final remainingSteps = await getProjectSteps(step.projectId);
    for (var index = 0; index < remainingSteps.length; index++) {
      final remainingStep = remainingSteps[index];
      final compactedOrder = index + 1;
      if (remainingStep.stepOrder != compactedOrder) {
        await _setStepOrder(step.projectId, remainingStep.id!, compactedOrder);
      }
    }
  }

  @override
  Future<void> reorderProjectSteps(
    String projectId,
    List<String> orderedStepIds,
  ) async {
    _requireSignedIn();
    final rows = await _client
        .from('project_steps')
        .select('id, project_id, step_order, title, instructions')
        .eq('project_id', projectId)
        .order('step_order');
    final steps = rows.map(ProjectStep.fromMap).toList();
    await _persistStepOrder(projectId, steps, orderedStepIds);
  }

  Future<void> _persistStepOrder(
    String projectId,
    List<ProjectStep> steps,
    List<String> orderedStepIds,
  ) async {
    final existingIds = steps.map((step) => step.id!).toSet();
    if (orderedStepIds.length != steps.length ||
        orderedStepIds.toSet().length != orderedStepIds.length ||
        !orderedStepIds.toSet().containsAll(existingIds) ||
        !existingIds.containsAll(orderedStepIds)) {
      throw ArgumentError('The reordered steps do not match this project.');
    }

    if (steps.isEmpty) return;
    final maximumOrder = steps
        .map((step) => step.stepOrder)
        .reduce((first, second) => first > second ? first : second);
    final temporaryStart = maximumOrder + steps.length + 1;
    for (var index = 0; index < orderedStepIds.length; index++) {
      await _setStepOrder(
        projectId,
        orderedStepIds[index],
        temporaryStart + index,
      );
    }
    for (var index = 0; index < orderedStepIds.length; index++) {
      await _setStepOrder(projectId, orderedStepIds[index], index + 1);
    }
  }

  Future<void> _setStepOrder(String projectId, String stepId, int order) async {
    await _client
        .from('project_steps')
        .update({'step_order': order})
        .eq('id', stepId)
        .eq('project_id', projectId)
        .select('id')
        .single();
  }
}

String projectErrorMessage(Object error) {
  if (error is StateError) {
    return 'Your session is no longer available. Sign in again and retry.';
  }
  if (error is PostgrestException) {
    return 'Could not save or load this project. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

String projectDetailsErrorMessage(Object error) {
  if (error is StateError) {
    return 'Your session is no longer available. Sign in again and retry.';
  }
  if (error is PostgrestException &&
      (error.code == '42501' || error.code == 'PGRST116')) {
    return 'This project is unavailable or you do not have permission to view it.';
  }
  return projectErrorMessage(error);
}
