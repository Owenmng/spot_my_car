import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/brand_models_screen.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

enum _Sort { progress, name, rarity }

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with AutomaticKeepAliveClientMixin {
  _Sort _sort = _Sort.progress;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final data = context.watch<DataManager>();
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).snapshots(),
        builder: (context, snap) {
          final spotted = <String, Set<String>>{};
          for (final d in snap.data?.docs ?? const []) {
            final b = d.data()['brandId'] as String?;
            final m = d.data()['modelId'] as String?;
            if (b != null && m != null) spotted.putIfAbsent(b, () => {}).add(m);
          }

          final brands = data.brands.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).where((b) => data.visibleModels(b['id'] as String).isNotEmpty).toList();
          int total(Map b) => data.visibleModels(b['id'] as String).length;
          int got(Map b) => (spotted[b['id']]?.length ?? 0).clamp(0, total(b));
          double pct(Map b) => total(b) == 0 ? 0 : got(b) / total(b);

          brands.sort((a, b) {
            switch (_sort) {
              case _Sort.progress:
                final c = pct(b).compareTo(pct(a));
                return c != 0 ? c : (a['name'] as String).compareTo(b['name'] as String);
              case _Sort.name:
                return (a['name'] as String).compareTo(b['name'] as String);
              case _Sort.rarity:
                return ((b['rarete'] as num?) ?? 0).compareTo((a['rarete'] as num?) ?? 0);
            }
          });

          final allModels = brands.fold<int>(0, (s, b) => s + total(b));
          final allGot = brands.fold<int>(0, (s, b) => s + got(b));
          final started = brands.where((b) => got(b) > 0).length;
          final top = MediaQuery.paddingOf(context).top;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collection', style: AppText.display(32)),
                      const SizedBox(height: 6),
                      Text(
                        allGot == 0
                            ? 'Chaque modèle spotté remplit ton album. ${allModels.toString()} modèles t’attendent.'
                            : '$allGot modèles sur $allModels, chez $started marques. Continue comme ça.',
                        style: AppText.body(15, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in {_Sort.progress: 'Avancement', _Sort.name: 'A → Z', _Sort.rarity: 'Les plus rares'}.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(e.value),
                                  selected: _sort == e.key,
                                  onSelected: (_) => setState(() => _sort = e.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: brands.length,
                  itemBuilder: (context, i) {
                    final b = brands[i];
                    return Pressable(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BrandModelsScreen(brand: b, showAsGrayscaleCollection: true)),
                      ),
                      child: _BrandTile(brand: b, got: got(b), total: total(b)),
                    ).animate().fadeIn(delay: (25 * (i % 12)).ms, duration: 250.ms);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final Map<String, dynamic> brand;
  final int got;
  final int total;

  const _BrandTile({required this.brand, required this.got, required this.total});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final done = total > 0 && got >= total;
    final progress = total == 0 ? 0.0 : got / total;
    final name = brand['name'] as String;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: done ? AppColors.panelHi : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: done ? const Color(0xFFFFD447) : AppColors.line),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      color: done ? const Color(0xFFFFD447) : accent,
                      backgroundColor: done ? Colors.white12 : AppColors.paperDeep,
                    ),
                  ),
                ),
                Opacity(
                  opacity: got == 0 ? 0.45 : 1,
                  child: ColorFiltered(
                    colorFilter: got == 0
                        ? const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: BrandLogo(url: brand['logoUrl'] as String?, name: name, size: 48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(13, weight: FontWeight.w800, color: done ? Colors.white : AppColors.ink),
          ),
          Text(
            done ? 'COMPLÈTE' : '$got / $total',
            style: AppText.body(11.5, weight: FontWeight.w600, color: done ? const Color(0xFFFFD447) : AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
