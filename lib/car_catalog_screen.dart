import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/brand_detail_screen.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/vehicle_recognition_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class CarCatalogScreen extends StatefulWidget {
  const CarCatalogScreen({super.key});

  @override
  State<CarCatalogScreen> createState() => _CarCatalogScreenState();
}

class _CarCatalogScreenState extends State<CarCatalogScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(Map<String, dynamic>, Map<String, dynamic>, int)> _results(DataManager data) {
    final words = VehicleRecognitionService.tokens(_q);
    if (words.isEmpty) return [];
    final out = <(Map<String, dynamic>, Map<String, dynamic>, int)>[];
    for (final b in data.brands.whereType<Map>()) {
      final brand = Map<String, dynamic>.from(b);
      final models = data.modelsByBrand[brand['id']] ?? const [];
      for (var i = 0; i < models.length; i++) {
        final m = models[i];
        if (m is! Map || ((m['imageUrl'] as String?)?.isEmpty ?? true)) continue;
        final hay = VehicleRecognitionService.normalize('${brand['name']} ${m['name']}');
        if (words.every(hay.contains)) out.add((brand, Map<String, dynamic>.from(m), i));
        if (out.length >= 60) return out;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataManager>();
    final brands = data.brands.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).where((b) => data.visibleModels(b['id'] as String).isNotEmpty).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final results = _results(data);
    final total = brands.fold<int>(0, (s, b) => s + data.visibleModels(b['id'] as String).length);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catalogue', style: AppText.display(32)),
                  const SizedBox(height: 6),
                  Text('${brands.length} marques, $total modèles. De la Twingo à la Chiron.', style: AppText.body(15, color: AppColors.inkSoft)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cherche une voiture… « golf gti », « 911 »',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _q = '';
                              }),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_q.trim().isNotEmpty)
            results.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: Icons.search_off_rounded, title: 'Aucun modèle', message: 'Essaie avec un autre mot-clé.'),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final (brand, model, index) = results[i];
                        final rarity = rarityFor(brand: brand, model: model);
                        return Pressable(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModelDetailScreen(
                                modelsList: data.modelsByBrand[brand['id']] ?? [],
                                initialIndex: index,
                                isSpotted: false,
                                brand: brand,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 92,
                                  height: 64,
                                  child: CarImage(
                                    urls: [model['imageUrl'] as String?],
                                    brandName: brand['name'] as String?,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((brand['name'] as String).toUpperCase(), style: AppText.label(10.5, color: AppColors.inkMuted)),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(model['name'] as String, maxLines: 1, style: AppText.body(16, weight: FontWeight.w800)),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          RarityBadge(rarity: rarity, compact: true),
                                          if (model['production_years'] != null) ...[
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                model['production_years'].toString(),
                                                overflow: TextOverflow.ellipsis,
                                                style: AppText.body(12, color: AppColors.inkSoft),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemCount: brands.length,
                itemBuilder: (context, i) {
                  final b = brands[i];
                  final count = data.visibleModels(b['id'] as String).length;
                  return Pressable(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BrandDetailScreen(brand: b))),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Expanded(child: Center(child: BrandLogo(url: b['logoUrl'] as String?, name: b['name'] as String, size: 54))),
                          const SizedBox(height: 8),
                          Text(b['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, weight: FontWeight.w800)),
                          Text('$count modèles', style: AppText.body(11.5, color: AppColors.inkSoft, weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (20 * (i % 15)).ms, duration: 250.ms);
                },
              ),
            ),
        ],
      ),
    );
  }
}
