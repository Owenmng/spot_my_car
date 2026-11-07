import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/fact_sheet_service.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:spot_my_car/services/wishlist_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class ModelDetailScreen extends StatefulWidget {
  final List<dynamic> modelsList;
  final int initialIndex;
  final bool isSpotted;
  final Map<String, dynamic> brand;

  const ModelDetailScreen({super.key, required this.modelsList, required this.initialIndex, required this.isSpotted, required this.brand});

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.modelsList.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _ModelPage(
              model: Map<String, dynamic>.from(widget.modelsList[i] as Map),
              brand: widget.brand,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _Glass(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                const Spacer(),
                StreamBuilder<List<String>>(
                  stream: WishlistService.instance.watch(),
                  builder: (context, snap) {
                    final list = snap.data ?? const [];
                    final id = (widget.modelsList[_index] as Map)['id'] as String?;
                    final on = id != null && list.contains(id);
                    return Pressable(
                      onTap: id == null
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              final ok = await WishlistService.instance.toggle(id, add: !on, current: list.length);
                              if (!context.mounted) return;
                              showAppSnack(
                                context,
                                !ok
                                    ? 'Viseur plein : ${WishlistService.maxTargets} cibles maximum.'
                                    : on
                                        ? 'Retirée du viseur'
                                        : 'Dans le viseur ! +${WishlistService.bonusXp} XP bonus quand tu la spotteras.',
                                icon: Icons.gps_fixed_rounded,
                              );
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: on ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(on ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded, size: 17, color: on ? Theme.of(context).colorScheme.onPrimary : Colors.white),
                            const SizedBox(width: 6),
                            Text(on ? 'Dans le viseur' : 'Viser', style: AppText.body(13, weight: FontWeight.w800, color: on ? Theme.of(context).colorScheme.onPrimary : Colors.white)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
                  child: Text('${_index + 1} / ${widget.modelsList.length}', style: AppText.mono(12, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Glass({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      );
}

class _ModelPage extends StatelessWidget {
  final Map<String, dynamic> model;
  final Map<String, dynamic> brand;

  const _ModelPage({required this.model, required this.brand});

  @override
  Widget build(BuildContext context) {
    final rarity = rarityFor(brand: brand, model: model);
    final name = model['name'] as String? ?? '';
    final size = MediaQuery.sizeOf(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: size.width * 0.82,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CarImage(urls: [model['imageUrl'] as String?], brandName: brand['name'] as String?, modelName: name),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.3, 0.65, 1],
                      colors: [Color(0x99000000), Colors.transparent, Colors.transparent, AppColors.paper],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((brand['name'] as String? ?? '').toUpperCase(), style: AppText.label(12.5, color: AppColors.inkSoft)),
                      Text(name, style: AppText.display(38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 32 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RarityBadge(rarity: rarity),
                    Text('+${rarity.xp} XP au spot', style: AppText.mono(12.5, color: rarity.color)),
                    if (model['production_years'] != null)
                      Text('${model['production_years']}'.replaceAll("Aujourd'hui", 'auj.'), style: AppText.mono(12.5, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 26),
                Text('FICHE TECHNIQUE', style: AppText.label(12, color: AppColors.inkSoft)),
                const SizedBox(height: 12),
                SpecsGrid(model: model),
                const SizedBox(height: 28),
                _Dossier(model: model, brand: brand),
                const SizedBox(height: 28),
                Text('MES SPOTS', style: AppText.label(12, color: AppColors.inkSoft)),
                const SizedBox(height: 12),
                _MySpots(modelId: model['id'] as String?),
                if (model['imageCredit'] != null) ...[
                  const SizedBox(height: 24),
                  PhotoCredit(model: model),
                ],
              ],
            ).animate().fadeIn(duration: 300.ms),
          ),
        ),
      ],
    );
  }
}

class _Dossier extends StatefulWidget {
  final Map<String, dynamic> model;
  final Map<String, dynamic> brand;
  const _Dossier({required this.model, required this.brand});

  @override
  State<_Dossier> createState() => _DossierState();
}

class _DossierState extends State<_Dossier> {
  FactSheet? _sheet;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final id = widget.model['id'] as String?;
    if (id != null) {
      FactSheetService.cached(id).then((s) {
        if (mounted && s != null) setState(() => _sheet = s);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await FactSheetService.load(
        modelId: widget.model['id'] as String? ?? '${widget.brand['id']}_${widget.model['name']}',
        brand: widget.brand['name'] as String? ?? '',
        model: widget.model['name'] as String? ?? '',
        years: widget.model['production_years'] as String?,
      );
      if (mounted) setState(() => _sheet = s);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de charger la fiche pour le moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final s = _sheet;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text('LE DOSSIER', style: AppText.label(12, color: accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (s == null) ...[
            Text('Histoire, moteur, chiffres clés, anecdotes et détails pour la reconnaître dans la rue.', style: AppText.body(14, color: AppColors.inkSoft)),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: AppText.body(13, color: AppColors.danger)),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_loading ? 'Rédaction en cours…' : 'Ouvrir le dossier'),
            ),
          ] else ...[
            Text(s.summary, style: AppText.body(15, color: AppColors.ink).copyWith(height: 1.5)),
            _block('Moteur', s.engine),
            _block('Chiffres clés', s.keyFigures),
            _block('Production', s.production),
            if (s.anecdotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('ANECDOTES', style: AppText.label(11, color: AppColors.inkMuted)),
              const SizedBox(height: 6),
              for (final a in s.anecdotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(a, style: AppText.body(14, color: AppColors.ink).copyWith(height: 1.45))),
                    ],
                  ),
                ),
            ],
            _block('Comment la reconnaître', s.howToSpot),
            const SizedBox(height: 12),
            Text('Rédigé par IA à partir de ses connaissances : vérifie les chiffres importants.', style: AppText.body(11.5, color: AppColors.inkMuted)),
          ],
        ],
      ),
    );
  }

  Widget _block(String title, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppText.label(11, color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          Text(text, style: AppText.body(14, color: AppColors.ink).copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

class _MySpots extends StatelessWidget {
  final String? modelId;
  const _MySpots({required this.modelId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || modelId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).where('modelId', isEqualTo: modelId).snapshots(),
      builder: (context, snap) {
        final docs = [...?snap.data?.docs]
          ..sort((a, b) => ((b.data()['spottedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a.data()['spottedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: AppColors.inkSoft),
                const SizedBox(width: 12),
                Expanded(child: Text('Pas encore spottée. Ouvre l’œil !', style: AppText.body(14, color: AppColors.inkSoft))),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final d in docs)
              Pressable(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpottedCarDetailScreen(carId: d.id, carData: d.data()))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                  child: Row(
                    children: [
                      SizedBox(width: 72, height: 50, child: SpotImage(carId: d.id, car: d.data(), borderRadius: BorderRadius.circular(AppRadius.sm))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: PlateBadge(plate: d.data()['plate'] as String? ?? '', countryCode: d.data()['plateCountryCode'] as String?, scale: 0.6),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (d.data()['spottedAt'] is Timestamp) DateFormat('d MMM yyyy', 'fr_FR').format((d.data()['spottedAt'] as Timestamp).toDate()),
                                if (d.data()['locationName'] != null) d.data()['locationName'],
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(12.5, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
