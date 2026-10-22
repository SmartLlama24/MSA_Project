import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

abstract interface class ProjectRepository {
  Future<List<PaintingProject>> getProjects();

  Future<PaintingProject> getProject(String projectId);

  Future<PaintingProject> createProject(PaintingProject project);

  Future<PaintingProject> updateProject(PaintingProject project);

  Future<void> deleteProject(String projectId);

  Future<List<ProjectStep>> getProjectSteps(String projectId);

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
        .select('id, name, subject, status, progress')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return rows.map(PaintingProject.fromMap).toList();
  }

  @override
  Future<PaintingProject> getProject(String projectId) async {
    final userId = _userId;
    final row = await _client
        .from('projects')
        .select('id, name, subject, status, progress')
        .eq('id', projectId)
        .eq('user_id', userId)
        .single();
    return PaintingProject.fromMap(row);
  }

  @override
  Future<PaintingProject> createProject(PaintingProject project) async {
    final userId = _userId;
    final row = await _client
        .from('projects')
        .insert(project.toInsertMap(userId: userId))
        .select('id, name, subject, status, progress')
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

    final row = await _client
        .from('projects')
        .update(project.toUpdateMap())
        .eq('id', projectId)
        .eq('user_id', userId)
        .select('id, name, subject, status, progress')
        .single();

    return PaintingProject.fromMap(row);
  }

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
        .select('id, project_id, step_order, title, instructions')
        .eq('project_id', projectId)
        .order('step_order');
    return rows.map(ProjectStep.fromMap).toList();
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
