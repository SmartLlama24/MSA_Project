import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

const projectPhotoBucket = 'project-progress';
const maxProjectPhotoBytes = 10 * 1024 * 1024;

abstract interface class ProjectPhotoRepository {
  Future<List<ProjectPhoto>> getProjectPhotos(String projectId);

  Future<ProjectPhoto> uploadPhoto({
    required String projectId,
    required XFile image,
    String? projectStepId,
  });

  Future<void> setCoverPhoto(String projectId, String? photoId);

  Future<void> deletePhoto(ProjectPhoto photo);

  Future<String> getSignedUrlForPhoto(String photoId);
}

abstract interface class ProjectPhotoPicker {
  Future<List<XFile>> pickImages({required bool fromCamera});
}

class DeviceProjectPhotoPicker implements ProjectPhotoPicker {
  DeviceProjectPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<XFile>> pickImages({required bool fromCamera}) async {
    try {
      if (fromCamera) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        final images = image == null ? <XFile>[] : [image];
        _logSelectedImages(images, source: 'camera');
        return images;
      }

      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      _logSelectedImages(images, source: 'gallery');
      return images;
    } catch (error, stackTrace) {
      throw _photoFailure('image picker', error, stackTrace);
    }
  }
}

class SupabaseProjectPhotoRepository implements ProjectPhotoRepository {
  const SupabaseProjectPhotoRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'A signed-in user is required to manage project photos.',
      );
    }
    return userId;
  }

  @override
  Future<List<ProjectPhoto>> getProjectPhotos(String projectId) async {
    try {
      _requireSignedIn();
      final rows = await _client
          .from('project_photos')
          .select('id, project_id, project_step_id, storage_path, created_at')
          .eq('project_id', projectId)
          .order('created_at');
      final photos = rows.map(ProjectPhoto.fromMap).toList();
      debugPrint(
        '[ProjectPhoto] Metadata load succeeded: ${photos.length} photo(s), '
        'project=$projectId.',
      );
      return await Future.wait(
        photos.map((photo) async {
          try {
            final url = await _createSignedUrl(photo.storagePath);
            debugPrint(
              '[ProjectPhoto] Signed URL generated: photo=${photo.id}, '
              'path=${photo.storagePath}.',
            );
            return photo.withSignedUrl(url);
          } catch (error, stackTrace) {
            throw _photoFailure(
              'signed URL generation while loading photo ${photo.id}',
              error,
              stackTrace,
            );
          }
        }),
      );
    } catch (error, stackTrace) {
      throw _photoFailure(
        'photo metadata load for project $projectId',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<ProjectPhoto> uploadPhoto({
    required String projectId,
    required XFile image,
    String? projectStepId,
  }) async {
    debugPrint(
      '[ProjectPhoto] Upload started: project=$projectId, '
      'step=${projectStepId ?? "reference"}, name=${image.name}, '
      'mime=${image.mimeType ?? "unknown"}.',
    );
    final String userId;
    try {
      userId = _userId;
    } catch (error, stackTrace) {
      throw _photoFailure(
        'authentication check before upload',
        error,
        stackTrace,
      );
    }
    final String contentType;
    try {
      contentType = _contentType(image);
    } catch (error, stackTrace) {
      throw _photoFailure(
        'image type validation (name=${image.name}, '
        'mime=${image.mimeType ?? "unknown"})',
        error,
        stackTrace,
      );
    }
    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw ArgumentError('Choose a JPEG, PNG, or WebP image.'),
    };
    late final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
      debugPrint(
        '[ProjectPhoto] Image read succeeded: name=${image.name}, '
        'bytes=${bytes.length}, contentType=$contentType.',
      );
    } catch (error, stackTrace) {
      throw _photoFailure(
        'reading selected image ${image.name}',
        error,
        stackTrace,
      );
    }
    if (bytes.isEmpty) {
      final error = ArgumentError('The selected image is empty.');
      throw _photoFailure(
        'image validation (empty file)',
        error,
        StackTrace.current,
      );
    }
    if (bytes.length > maxProjectPhotoBytes) {
      final error = ArgumentError('Images must be 10 MB or smaller.');
      throw _photoFailure(
        'image validation (size=${bytes.length} bytes)',
        error,
        StackTrace.current,
      );
    }

    final suffix = Random.secure().nextInt(0x1000000).toRadixString(16);
    final storagePath =
        '$userId/$projectId/${DateTime.now().microsecondsSinceEpoch}_$suffix.$extension';
    final storage = _client.storage.from(projectPhotoBucket);
    final pathSegments = storagePath.split('/');
    final pathUserId = pathSegments.isEmpty ? null : pathSegments.first;
    debugPrint('[ProjectPhoto] Pre-upload diagnostic:');
    debugPrint('[ProjectPhoto] Supabase currentUser.id=$userId');
    debugPrint('[ProjectPhoto] Project ID=$projectId');
    debugPrint(
      '[ProjectPhoto] Bucket=$projectPhotoBucket; exact Storage path=$storagePath',
    );
    debugPrint(
      '[ProjectPhoto] Path first segment=$pathUserId; '
      'user ID matches first segment=${pathUserId == userId}',
    );
    try {
      final projectRow = await _client
          .from('projects')
          .select('user_id')
          .eq('id', projectId)
          .maybeSingle();
      final projectOwnerId = projectRow?['user_id'] as String?;
      debugPrint(
        '[ProjectPhoto] Ownership check through authenticated projects SELECT: '
        'rowVisible=${projectRow != null}, project.user_id=$projectOwnerId, '
        'userOwnsProject=${projectOwnerId == userId}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[ProjectPhoto] Ownership diagnostic SELECT failed (upload will '
        'continue): $error\n$stackTrace',
      );
    }
    try {
      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      debugPrint(
        '[ProjectPhoto] Storage upload succeeded: bucket=$projectPhotoBucket, '
        'path=$storagePath.',
      );
    } catch (error, stackTrace) {
      throw _photoFailure(
        'Storage upload (bucket=$projectPhotoBucket, path=$storagePath)',
        error,
        stackTrace,
      );
    }

    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('project_photos')
          .insert({
            'project_id': projectId,
            'project_step_id': projectStepId,
            'storage_path': storagePath,
          })
          .select('id, project_id, project_step_id, storage_path, created_at')
          .single();
      debugPrint(
        '[ProjectPhoto] Metadata insert succeeded: photo=${row['id']}, '
        'project=$projectId, path=$storagePath.',
      );
    } catch (error, stackTrace) {
      final diagnostic = _photoFailure(
        'metadata insert (project=$projectId, path=$storagePath)',
        error,
        stackTrace,
      );
      try {
        await storage.remove([storagePath]);
        debugPrint(
          '[ProjectPhoto] Orphan cleanup succeeded after metadata insert '
          'failure: path=$storagePath.',
        );
      } catch (cleanupError, cleanupStackTrace) {
        final cleanupDiagnostic = _photoFailure(
          'Storage cleanup after metadata insert failure (path=$storagePath)',
          cleanupError,
          cleanupStackTrace,
        );
        throw ProjectPhotoDiagnosticException(
          stage: 'metadata insert and orphan cleanup',
          error: '$diagnostic\n$cleanupDiagnostic',
          stackTrace: stackTrace,
        );
      }
      throw diagnostic;
    }
    final photo = ProjectPhoto.fromMap(row);
    try {
      final url = await _createSignedUrl(storagePath);
      debugPrint(
        '[ProjectPhoto] Signed URL generated after upload: photo=${photo.id}, '
        'path=$storagePath.',
      );
      return photo.withSignedUrl(url);
    } catch (error, stackTrace) {
      throw _photoFailure(
        'signed URL generation after upload (photo=${photo.id}, '
        'path=$storagePath)',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> setCoverPhoto(String projectId, String? photoId) async {
    _requireSignedIn();
    await _client
        .from('projects')
        .update({'cover_photo_id': photoId})
        .eq('id', projectId)
        .eq('user_id', _userId)
        .select('id')
        .single();
  }

  @override
  Future<void> deletePhoto(ProjectPhoto photo) async {
    final userId = _userId;
    final project = await _client
        .from('projects')
        .select('cover_photo_id')
        .eq('id', photo.projectId)
        .eq('user_id', userId)
        .single();
    final wasCover = project['cover_photo_id'] == photo.id;

    await _client
        .from('project_photos')
        .delete()
        .eq('id', photo.id)
        .eq('project_id', photo.projectId)
        .select('id')
        .single();

    try {
      await _client.storage.from(projectPhotoBucket).remove([
        photo.storagePath,
      ]);
    } catch (error) {
      try {
        await _client.from('project_photos').insert({
          'id': photo.id,
          'project_id': photo.projectId,
          'project_step_id': photo.projectStepId,
          'storage_path': photo.storagePath,
          'created_at': photo.createdAt.toIso8601String(),
        });
        if (wasCover) {
          await setCoverPhoto(photo.projectId, photo.id);
        }
      } catch (restoreError) {
        throw StateError(
          'The photo file could not be deleted and its database record could '
          'not be restored. Storage error: $error. Restore error: $restoreError',
        );
      }
      rethrow;
    }
  }

  @override
  Future<String> getSignedUrlForPhoto(String photoId) async {
    _requireSignedIn();
    try {
      final row = await _client
          .from('project_photos')
          .select('storage_path')
          .eq('id', photoId)
          .single();
      final storagePath = row['storage_path'] as String;
      final url = await _createSignedUrl(storagePath);
      debugPrint(
        '[ProjectPhoto] Signed cover URL generated: photo=$photoId, '
        'path=$storagePath.',
      );
      return url;
    } catch (error, stackTrace) {
      throw _photoFailure(
        'cover metadata/signed URL load (photo=$photoId)',
        error,
        stackTrace,
      );
    }
  }

  Future<String> _createSignedUrl(String storagePath) => _client.storage
      .from(projectPhotoBucket)
      .createSignedUrl(storagePath, 60 * 60);

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw StateError(
        'A signed-in user is required to manage project photos.',
      );
    }
  }

  String _contentType(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType!;
    }

    final extension = image.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw ArgumentError('Choose a JPEG, PNG, or WebP image.'),
    };
  }
}

void _logSelectedImages(List<XFile> images, {required String source}) {
  debugPrint(
    '[ProjectPhoto] Image picker returned ${images.length} image(s) '
    'from $source.',
  );
  for (final image in images) {
    debugPrint(
      '[ProjectPhoto] Selected image: name=${image.name}, '
      'mime=${image.mimeType ?? "unknown"}.',
    );
  }
}

ProjectPhotoDiagnosticException _photoFailure(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  debugPrint('[ProjectPhoto] FAILED at $stage.');
  debugPrint('[ProjectPhoto] Original exception: $error');
  final supabaseDetails = StringBuffer();
  if (error is StorageException) {
    supabaseDetails
      ..writeln(
        'Supabase Storage HTTP status: ${error.statusCode ?? "unavailable"}',
      )
      ..writeln('Supabase Storage message: ${error.message}')
      ..writeln('Supabase Storage error: ${error.error ?? "none"}');
  } else if (error is PostgrestException) {
    supabaseDetails
      ..writeln('Supabase database code: ${error.code}')
      ..writeln('Supabase database message: ${error.message}')
      ..writeln('Supabase database details: ${error.details}')
      ..writeln('Supabase database hint: ${error.hint}');
  }
  debugPrint('[ProjectPhoto] Stack trace:\n$stackTrace');
  return ProjectPhotoDiagnosticException(
    stage: stage,
    error: error,
    stackTrace: stackTrace,
    supabaseDetails: supabaseDetails.toString().trim(),
  );
}

class ProjectPhotoDiagnosticException implements Exception {
  const ProjectPhotoDiagnosticException({
    required this.stage,
    required this.error,
    required this.stackTrace,
    this.supabaseDetails = '',
  });

  final String stage;
  final Object error;
  final StackTrace stackTrace;
  final String supabaseDetails;

  @override
  String toString() =>
      'Photo operation failed at: $stage\n'
      'Original exception: $error'
      '${supabaseDetails.isEmpty ? '' : '\n$supabaseDetails'}\n'
      'Stack trace:\n$stackTrace';
}

String projectPhotoErrorMessage(Object error) {
  if (error is ProjectPhotoDiagnosticException) {
    return 'Photo operation failed during ${error.stage}.';
  }
  if (error is StateError) {
    return 'Your session has expired or photo access is unavailable. Sign in '
        'again and retry.';
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? error.toString();
  }
  if (error is StorageException) {
    return 'Could not load or save this photo. Check your connection and '
        'Storage access, then try again.';
  }
  if (error is PostgrestException) {
    return 'Could not save this photo to your project. Check your connection '
        'and permissions, then try again.';
  }
  return 'Something went wrong while managing photos. Please try again.';
}
