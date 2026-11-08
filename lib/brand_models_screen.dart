import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/vehicle_recognition_service.dart';
import 'package:spot_my_car/shared/natural_sort.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

enum SortOption { nameAsc, yearDesc, yearAsc, rarity }

class BrandModelsScreen extends StatefulWidget {
  final Map<String, dynamic> brand;
  final bool showAsGrayscaleCollection;

  const BrandModelsScreen({super.key, required this.brand, this.showAsGrayscaleCollection = false});

  @override
  State<BrandModelsScreen> createState() => _BrandModelsScreenState();
}

class _BrandModelsScreenState extends State<BrandModelsScreen> {
  SortOption _sort = SortOption.nameAsc;
  String _q = '';
  bool _onlyMissing = false;

  static int _year(dynamic years) {
    final m = RegExp(r'(18|19|20)\d{2}').firstMatch('${years ?? ''}');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataManager>();
    final user = FirebaseAuth.instance.currentUser;
    final brandId = widget.brand['id'] as String;
    final all = data.modelsByBrand[brandId]?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? [];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).where('brandId', isEqualTo: brandId).snapshots(),
      builder: (context, snap) {
        final spotted = (snap.data?.docs ?? []).map((d) => d.data()['modelId']).whereType<String>().toSet();
        var models = all.where((m) => ((m['imageUrl'] as String?)?.isNotEmpty ?? false) || spotted.contains(m['id'])).toList();
        final total = models.length;
        final got = models.where((m) => spotted.contains(m['id'])).length;

        if (_q.isNotEmpty) {
          final q = VehicleRecognitionService.normalize(_q);
          models = models.where((m) => VehicleRecognitionService.normalize(m['name']).contains(q)).toList();
        }
        if (_onlyMissing) models = models.where((m) => !spotted.contains(m['id'])).toList();
        models.sort((a, b) {
          switch (_sort) {
            case SortOption.nameAsc:
              return naturalCompare('${a['name']}', '${b['name']}');
            case SortOption.yearDesc:
              return _year(b['production_years']).compareTo(_year(a['production_years']));
            case SortOption.yearAsc:
              return _year(a['production_years']).compareTo(_year(b['production_years']));
            case SortOption.rarity:
              return rarityFor(brand: widget.brand, model: b).index.compareTo(rarityFor(brand: widget.brand, model: a).index);
          }
        });

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.brand['name'] as String? ?? ''),
            actions: [
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: SortOption.nameAsc, child: Text('Nom (A → Z)')),
                  PopupMenuItem(value: SortOption.yearDesc, child: Text('Plus récents')),
                  PopupMenuItem(value: SortOption.yearAsc, child: Text('Plus anciens')),
                  PopupMenuItem(value: SortOption.rarity, child: Text('Plus rares')),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BrandLogo(url: widget.brand['logoUrl'] as String?, name: widget.brand['name'] as String? ?? '', size: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$got / $total', style: AppText.display(26)),
                                Text('modèles dans ta collection', style: AppText.body(13, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              value: total == 0 ? 0 : got / total,
                              strokeWidth: 4,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppColors.paperDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _q = v.trim()),
                        decoration: const InputDecoration(hintText: 'Chercher un modèle', prefixIcon: Icon(Icons.search_rounded)),
                      ),
                      const SizedBox(height: 10),
                      FilterChip(
                        label: const Text('À trouver seulement'),
                        selected: _onlyMissing,
                        onSelected: (v) => setState(() => _onlyMissing = v),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: models.length,
                  itemBuilder: (context, i) {
                    final m = models[i];
                    final isSpotted = spotted.contains(m['id']);
                    final rarity = rarityFor(brand: widget.brand, model: m);
                    final dim = widget.showAsGrayscaleCollection && !isSpotted;
                    return Pressable(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModelDetailScreen(modelsList: models, initialIndex: i, isSpotted: isSpotted, brand: widget.brand),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: isSpotted ? rarity.color.withValues(alpha: 0.7) : AppColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColorFiltered(
                                    colorFilter: dim
                                        ? const ColorFilter.matrix([0.25, 0.25, 0.25, 0, 0, 0.25, 0.25, 0.25, 0, 0, 0.25, 0.25, 0.25, 0, 0, 0, 0, 0, 1, 0])
                                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                    child: CarImage(urls: [m['imageUrl'] as String?], brandName: widget.brand['name'] as String?, modelName: m['name'] as String?),
                                  ),
                                  if (isSpotted)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(color: rarity.color, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(m['name'] as String? ?? '', maxLines: 1, style: AppText.body(14, weight: FontWeight.w800)),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(width: 7, height: 7, decoration: BoxDecoration(color: rarity.color, shape: BoxShape.circle)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          '${rarity.label}${m['production_years'] != null ? ' · ${_year(m['production_years'])}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.body(11.5, color: AppColors.inkSoft),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (15 * (i % 20)).ms, duration: 220.ms);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
