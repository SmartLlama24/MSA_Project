import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

const paintingSchemePreviewBucket = 'painting-scheme-previews';
const maxSchemePreviewBytes = 10 * 1024 * 1024;

abstract interface class PaintingSchemeRepository {
  Future<List<PaintingScheme>> getSchemes();

  Future<PaintingScheme> getScheme(String schemeId);

  Future<PaintingScheme> createScheme({
    required String name,
    String? description,
    XFile? previewImage,
  });

  Future<PaintingScheme> updateScheme({
    required PaintingScheme scheme,
    required String name,
    String? description,
    XFile? previewImage,
    bool removePreview = false,
  });

  Future<void> deleteScheme(PaintingScheme scheme);

  Future<PaintingScheme> duplicateScheme(PaintingScheme scheme);

  Future<PaintingSchemeStep> createStep({
    required String schemeId,
    required String title,
    required String description,
  });

  Future<void> updateStep(PaintingSchemeStep step);

  Future<void> deleteStep(PaintingSchemeStep step);

  Future<void> setStepPaints(
    PaintingSchemeStep step,
    List<CatalogPaint> paints,
  );

  Future<void> reorderSteps(String schemeId, List<String> orderedStepIds);

  Future<String> createProjectFromScheme({
    required String name,
    required String subject,
    required String schemeId,
  });
}

abstract interface class SchemePreviewPicker {
  Future<XFile?> pickPreviewImage();
}

class DeviceSchemePreviewPicker implements SchemePreviewPicker {
  DeviceSchemePreviewPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickPreviewImage() => _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1920,
    maxHeight: 1920,
  );
}

class SupabasePaintingSchemeRepository implements PaintingSchemeRepository {
  const SupabasePaintingSchemeRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('A signed-in user is required to manage schemes.');
    }
    return id;
  }

  @override
  Future<List<PaintingScheme>> getSchemes() async {
    final userId = _userId;
    final rows = await _client
        .from('painting_schemes')
        .select('id, name, description, preview_storage_path, created_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final schemes = rows.map(PaintingScheme.fromMap).toList();
    final schemeIds = schemes.map((scheme) => scheme.id).toList();
    final counts = <String, int>{};
    final stepsByScheme = <String, List<PaintingSchemeStep>>{};
    if (schemeIds.isNotEmpty) {
      final stepRows = await _client
          .from('painting_scheme_steps')
          .select(
            'id, scheme_id, step_order, title, description, '
            'painting_scheme_step_paints(paints(id, name, paint_type, '
            'hex_color, paint_brands(name)))',
          )
          .inFilter('scheme_id', schemeIds);
      final steps = await _loadStepPaintStatuses(stepRows);
      for (final row in stepRows) {
        final id = row['scheme_id'] as String;
        counts.update(id, (count) => count + 1, ifAbsent: () => 1);
      }
      for (final step in steps) {
        stepsByScheme.putIfAbsent(step.schemeId, () => []).add(step);
      }
    }

    return Future.wait(
      schemes.map((scheme) async {
        final previewUrl = scheme.previewStoragePath == null
            ? null
            : await _previewStorage.createSignedUrl(
                scheme.previewStoragePath!,
                60 * 60,
              );
        return PaintingScheme(
          id: scheme.id,
          name: scheme.name,
          description: scheme.description,
          previewStoragePath: scheme.previewStoragePath,
          previewUrl: previewUrl,
          steps: stepsByScheme[scheme.id] ?? const [],
          stepCount: counts[scheme.id] ?? 0,
        );
      }),
    );
  }

  @override
  Future<PaintingScheme> getScheme(String schemeId) async {
    final row = await _client
        .from('painting_schemes')
        .select('id, name, description, preview_storage_path')
        .eq('id', schemeId)
        .eq('user_id', _userId)
        .single();
    final stepRows = await _client
        .from('painting_scheme_steps')
        .select(
          'id, scheme_id, step_order, title, description, '
          'painting_scheme_step_paints(paints(id, name, paint_type, '
          'hex_color, paint_brands(name)))',
        )
        .eq('scheme_id', schemeId)
        .order('step_order');
    final steps = await _loadStepPaintStatuses(stepRows);
    final scheme = PaintingScheme(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      previewStoragePath: row['preview_storage_path'] as String?,
      steps: steps,
    );
    final path = scheme.previewStoragePath;
    return scheme.withPreviewUrl(
      path == null
          ? null
          : await _previewStorage.createSignedUrl(path, 60 * 60),
    );
  }

  Future<List<PaintingSchemeStep>> _loadStepPaintStatuses(
    List<Map<String, dynamic>> rows,
  ) async {
    final steps = rows.map(PaintingSchemeStep.fromMap).toList();
    final paintIds = steps
        .expand((step) => step.paints)
        .map((paint) => paint.id)
        .toSet()
        .toList();
    if (paintIds.isEmpty) return steps;

    final statusRows = await _client
        .from('user_paints')
        .select('paint_id, status')
        .eq('user_id', _userId)
        .inFilter('paint_id', paintIds);
    final statuses = {
      for (final row in statusRows)
        row['paint_id'] as String: PaintOwnershipStatus.fromDatabase(
          row['status'],
        ),
    };
    return steps
        .map(
          (step) => PaintingSchemeStep(
            id: step.id,
            schemeId: step.schemeId,
            stepOrder: step.stepOrder,
            title: step.title,
            description: step.description,
            paints: step.paints
                .map(
                  (paint) => paint.withUserStatus(
                    statuses[paint.id] ?? PaintOwnershipStatus.unowned,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Future<PaintingScheme> createScheme({
    required String name,
    String? description,
    XFile? previewImage,
  }) async {
    final row = await _client
        .from('painting_schemes')
        .insert({
          'user_id': _userId,
          'name': name.trim(),
          'description': _trimOrNull(description),
        })
        .select('id, name, description, preview_storage_path')
        .single();
    var scheme = PaintingScheme.fromMap(row);
    if (previewImage != null) {
      try {
        scheme = await _replacePreview(scheme, previewImage);
      } catch (error, stackTrace) {
        try {
          await _client
              .from('painting_schemes')
              .delete()
              .eq('id', scheme.id)
              .eq('user_id', _userId);
        } catch (cleanupError) {
          Error.throwWithStackTrace(
            StateError(
              'Preview creation failed ($error), and its empty scheme record '
              'could not be removed ($cleanupError).',
            ),
            stackTrace,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
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
    await _client
        .from('painting_schemes')
        .update({'name': name.trim(), 'description': _trimOrNull(description)})
        .eq('id', scheme.id)
        .eq('user_id', _userId);
    var updated = scheme.copyWith(
      name: name.trim(),
      description: description,
      clearDescription: _trimOrNull(description) == null,
    );
    if (previewImage != null) {
      updated = await _replacePreview(updated, previewImage);
    } else if (removePreview && scheme.previewStoragePath != null) {
      await _previewStorage.remove([scheme.previewStoragePath!]);
      await _client
          .from('painting_schemes')
          .update({'preview_storage_path': null})
          .eq('id', scheme.id)
          .eq('user_id', _userId);
      updated = updated.copyWith(clearPreview: true);
    }
    return updated;
  }

  Future<PaintingScheme> _replacePreview(
    PaintingScheme scheme,
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxSchemePreviewBytes) {
      throw ArgumentError('Choose an image between 1 byte and 10 MB.');
    }
    final mime = _contentType(image);
    final extension = switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw ArgumentError('Choose a JPEG, PNG, or WebP preview image.'),
    };
    final path =
        '$_userId/${scheme.id}/${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(0x1000000).toRadixString(16)}.$extension';
    await _previewStorage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    try {
      await _client
          .from('painting_schemes')
          .update({'preview_storage_path': path})
          .eq('id', scheme.id)
          .eq('user_id', _userId);
    } catch (error) {
      await _previewStorage.remove([path]);
      rethrow;
    }
    final oldPath = scheme.previewStoragePath;
    if (oldPath != null && oldPath != path) {
      await _previewStorage.remove([oldPath]);
    }
    return scheme.copyWith(
      previewStoragePath: path,
      previewUrl: await _previewStorage.createSignedUrl(path, 60 * 60),
    );
  }

  @override
  Future<void> deleteScheme(PaintingScheme scheme) async {
    if (scheme.previewStoragePath case final path?) {
      await _previewStorage.remove([path]);
    }
    await _client
        .from('painting_schemes')
        .delete()
        .eq('id', scheme.id)
        .eq('user_id', _userId);
  }

  @override
  Future<PaintingScheme> duplicateScheme(PaintingScheme scheme) async {
    final original = await getScheme(scheme.id);
    final copy = await createScheme(
      name: '${original.name} (copy)',
      description: original.description,
    );
    String? copiedPreviewPath;
    try {
      for (final step in original.steps) {
        final copiedStep = await createStep(
          schemeId: copy.id,
          title: step.title,
          description: step.description,
        );
        await setStepPaints(copiedStep, step.paints);
      }
      if (original.previewStoragePath != null) {
        final bytes = await _previewStorage.download(
          original.previewStoragePath!,
        );
        final extension = original.previewStoragePath!.split('.').last;
        final path =
            '$_userId/${copy.id}/${DateTime.now().microsecondsSinceEpoch}_'
            '${Random.secure().nextInt(0x1000000).toRadixString(16)}.$extension';
        copiedPreviewPath = path;
        await _previewStorage.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFromExtension(extension),
            upsert: false,
          ),
        );
        await _client
            .from('painting_schemes')
            .update({'preview_storage_path': path})
            .eq('id', copy.id)
            .eq('user_id', _userId);
      }
      return await getScheme(copy.id);
    } catch (error) {
      if (copiedPreviewPath != null) {
        await _previewStorage.remove([copiedPreviewPath]);
      }
      await _client
          .from('painting_schemes')
          .delete()
          .eq('id', copy.id)
          .eq('user_id', _userId);
      rethrow;
    }
  }

  @override
  Future<PaintingSchemeStep> createStep({
    required String schemeId,
    required String title,
    required String description,
  }) async {
    final rows = await _client
        .from('painting_scheme_steps')
        .select('step_order')
        .eq('scheme_id', schemeId);
    final maximumOrder = rows.fold<int>(
      0,
      (maximum, row) => max(maximum, (row['step_order'] as num).toInt()),
    );
    final row = await _client
        .from('painting_scheme_steps')
        .insert({
          'scheme_id': schemeId,
          'step_order': maximumOrder + 1,
          'title': title.trim(),
          'description': description.trim(),
        })
        .select('id, scheme_id, step_order, title, description')
        .single();
    return PaintingSchemeStep.fromMap(row);
  }

  @override
  Future<void> updateStep(PaintingSchemeStep step) async {
    await _client
        .from('painting_scheme_steps')
        .update(step.toUpdateMap())
        .eq('id', step.id)
        .eq('scheme_id', step.schemeId);
  }

  @override
  Future<void> deleteStep(PaintingSchemeStep step) async {
    await _client
        .from('painting_scheme_steps')
        .delete()
        .eq('id', step.id)
        .eq('scheme_id', step.schemeId);
    final remaining = await _client
        .from('painting_scheme_steps')
        .select('id, step_order')
        .eq('scheme_id', step.schemeId)
        .order('step_order');
    await reorderSteps(
      step.schemeId,
      remaining.map((row) => row['id'] as String).toList(),
    );
  }

  @override
  Future<void> setStepPaints(
    PaintingSchemeStep step,
    List<CatalogPaint> paints,
  ) async {
    final existingIds = step.paints.map((paint) => paint.id).toSet();
    final selectedIds = paints.map((paint) => paint.id).toSet();
    final addedIds = selectedIds.difference(existingIds);
    final removedIds = existingIds.difference(selectedIds);
    if (addedIds.isNotEmpty) {
      await _client
          .from('painting_scheme_step_paints')
          .upsert(
            addedIds.map((id) => {'step_id': step.id, 'paint_id': id}).toList(),
            onConflict: 'step_id,paint_id',
            ignoreDuplicates: true,
          );
    }
    if (removedIds.isNotEmpty) {
      await _client
          .from('painting_scheme_step_paints')
          .delete()
          .eq('step_id', step.id)
          .inFilter('paint_id', removedIds.toList());
    }
  }

  @override
  Future<void> reorderSteps(
    String schemeId,
    List<String> orderedStepIds,
  ) async {
    final rows = await _client
        .from('painting_scheme_steps')
        .select('id, step_order')
        .eq('scheme_id', schemeId);
    final existingIds = rows.map((row) => row['id'] as String).toSet();
    final requestedIds = orderedStepIds.toSet();
    if (orderedStepIds.length != rows.length ||
        requestedIds.length != orderedStepIds.length ||
        !requestedIds.containsAll(existingIds) ||
        !existingIds.containsAll(requestedIds)) {
      throw ArgumentError('The reordered steps do not match this scheme.');
    }
    if (orderedStepIds.isEmpty) return;

    final maxOrder = rows.fold<int>(
      0,
      (maximum, row) => max(maximum, (row['step_order'] as num).toInt()),
    );
    final offset = maxOrder + orderedStepIds.length + 1;
    for (var index = 0; index < orderedStepIds.length; index++) {
      await _client
          .from('painting_scheme_steps')
          .update({'step_order': offset + index})
          .eq('id', orderedStepIds[index])
          .eq('scheme_id', schemeId)
          .select('id')
          .single();
    }
    for (var index = 0; index < orderedStepIds.length; index++) {
      await _client
          .from('painting_scheme_steps')
          .update({'step_order': index + 1})
          .eq('id', orderedStepIds[index])
          .eq('scheme_id', schemeId)
          .select('id')
          .single();
    }
  }

  @override
  Future<String> createProjectFromScheme({
    required String name,
    required String subject,
    required String schemeId,
  }) async {
    final result = await _client.rpc(
      'create_project_from_painting_scheme',
      params: {
        'p_name': name.trim(),
        'p_subject': subject.trim(),
        'p_scheme_id': schemeId,
      },
    );
    return result as String;
  }

  StorageFileApi get _previewStorage =>
      _client.storage.from(paintingSchemePreviewBucket);

  String _contentType(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType!;
    }
    return _contentTypeFromExtension(image.name.split('.').last.toLowerCase());
  }

  String _contentTypeFromExtension(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw ArgumentError('Choose a JPEG, PNG, or WebP preview image.'),
  };
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String paintingSchemeErrorMessage(Object error) {
  if (error is StateError) {
    return 'Your session has expired. Sign in again and retry.';
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? error.toString();
  }
  if (error is PostgrestException) {
    return 'Could not save or load this painting scheme. Check your connection and permissions.';
  }
  if (error is StorageException) {
    return 'Could not save or load the scheme preview image. Check Storage access and try again.';
  }
  return 'Something went wrong while managing painting schemes.';
}
