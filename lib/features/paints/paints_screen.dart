import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';
import 'brand_paints_screen.dart';
import 'paint_repository.dart';

class PaintsScreen extends StatefulWidget {
  const PaintsScreen({super.key, this.repository});

  final PaintRepository? repository;

  @override
  State<PaintsScreen> createState() => _PaintsScreenState();
}

class _PaintsScreenState extends State<PaintsScreen> {
  late final PaintRepository _repository;
  List<PaintBrand> _brands = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? SupabasePaintRepository(Supabase.instance.client);
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final brands = await _repository.getBrands();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = paintRepositoryErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  void _openBrand(PaintBrand brand) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BrandPaintsScreen(brand: brand, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paints',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text('Browse colors by paint brand.'),
              ],
            ),
          ),
          Expanded(child: _buildBrands()),
        ],
      ),
    );
  }

  Widget _buildBrands() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_error != null) {
      return Center(
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
                onPressed: _loadBrands,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_brands.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined, color: AppTheme.accent, size: 42),
              SizedBox(height: 16),
              Text(
                'No paint brands yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Brands will appear here once paints are available in the catalog.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBrands,
      color: AppTheme.accent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BrandCard(brand: brand, onTap: () => _openBrand(brand)),
          );
        },
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand, required this.onTap});

  final PaintBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = brand.color;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color ?? AppTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.mutedText,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
