import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';

abstract interface class PaintRepository {
  Future<List<PaintBrand>> getBrands();

  Future<Map<String, String>> getBrandLogoUrls(List<PaintBrand> brands);

  Future<List<CatalogPaint>> getPaintsForBrand(String brandId);

  Future<void> setPaintStatus(String paintId, PaintOwnershipStatus status);
}

class SupabasePaintRepository implements PaintRepository {
  const SupabasePaintRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PaintBrand>> getBrands() async {
    final rows = await _client
        .from('paint_brands')
        .select('id, name, logo_path, paints!inner(hex_color)')
        .order('name')
        .order(
          'hex_color',
          ascending: true,
          nullsFirst: false,
          referencedTable: 'paints',
        )
        .limit(1, referencedTable: 'paints');
    return rows.map(PaintBrand.fromMap).toList();
  }

  @override
  Future<Map<String, String>> getBrandLogoUrls(List<PaintBrand> brands) async {
    final storage = _client.storage.from('Brand Logos');
    final urls = <String, String>{};
    for (final brand in brands) {
      final path = brand.logoPath?.trim();
      if (path != null && path.isNotEmpty) {
        urls[brand.id] = storage.getPublicUrl(path);
      }
    }
    return urls;
  }

  @override
  Future<List<CatalogPaint>> getPaintsForBrand(String brandId) async {
    final userId = _userId;
    final rows = await _client
        .from('paints')
        .select('id, name, paint_type, hex_color, user_paints(status)')
        .eq('brand_id', brandId)
        .eq('user_paints.user_id', userId)
        .order('name');
    return rows.map(CatalogPaint.fromMap).toList();
  }

  @override
  Future<void> setPaintStatus(
    String paintId,
    PaintOwnershipStatus status,
  ) async {
    final userId = _userId;
    final databaseValue = status.databaseValue;

    if (databaseValue == null) {
      await _client
          .from('user_paints')
          .delete()
          .eq('user_id', userId)
          .eq('paint_id', paintId);
      return;
    }

    await _client.from('user_paints').upsert({
      'user_id': userId,
      'paint_id': paintId,
      'status': databaseValue,
    }, onConflict: 'user_id,paint_id');
  }

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required to manage paint status.');
    }
    return userId;
  }
}

String paintRepositoryErrorMessage(Object error) {
  if (error is StateError) {
    return 'Your session has expired. Sign in again and retry.';
  }
  if (error is PostgrestException) {
    return 'Could not load the paint catalog. Check your connection and try again.';
  }
  return 'Something went wrong while loading paints. Please try again.';
}
