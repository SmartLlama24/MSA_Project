import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

abstract interface class ProjectRepository {
  Future<List<PaintingProject>> getProjects();

  Future<PaintingProject> createProject(PaintingProject project);

  Future<PaintingProject> updateProject(PaintingProject project);

  Future<void> deleteProject(String projectId);
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
