import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/map_screen.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/photo_store.dart';
import 'package:spot_my_car/services/share_service.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

enum _Filter { all, rare, week, photo }

class GarageScreen extends StatefulWidget {
  final VoidCallback? onAddSpot;

  const GarageScreen({super.key, this.onAddSpot});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _searching = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> car) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final hay = '${car['plate'] ?? ''} ${car['brandName'] ?? ''} ${car['modelName'] ?? ''} ${car['locationName'] ?? ''} ${car['color'] ?? ''}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.rare:
        return rarityOfSpot(car).index >= Rarity.rare.index;
      case _Filter.week:
        final t = (car['spottedAt'] as Timestamp?)?.toDate();
        return t != null && DateTime.now().difference(t).inDays < 7;
      case _Filter.photo:
        return car['userPhotoUrl'] != null || car['hasPhoto'] == true;
    }
  }

  Future<void> _delete(String id, Map<String, dynamic> car) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du garage ?'),
        content: Text('${car['brandName'] ?? ''} ${cleanModelName(car['modelName'] as String?)} sera supprimée, avec sa photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final url = car['userPhotoUrl'] as String?;
      if (url != null) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('spotted_cars').doc(id).delete();
      await PhotoStore.delete(id);
      if (mounted) showAppSnack(context, 'Voiture retirée du garage.', icon: Icons.delete_outline);
    } catch (_) {
      if (mounted) showAppSnack(context, 'La suppression a échoué.', icon: Icons.error_outline);
    }
  }

  void _quickActions(String id, Map<String, dynamic> car) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Partager la carte'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareSpot(this.context, car, carId: id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _delete(id, car);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('spotted_cars')
            .where('userId', isEqualTo: user.uid)
            .orderBy('spottedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final cars = docs.map((d) => d.data()).toList();
          final filtered = docs.where((d) => _matches(d.data())).toList();
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(uid: user.uid, cars: cars, onMap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()));
              })),
              if (cars.isNotEmpty) SliverToBoxAdapter(child: _toolbar()),
              if (loading)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Garage injoignable', message: "Impossible de charger tes voitures pour l'instant. Vérifie ta connexion."),
                )
              else if (cars.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'Ton garage attend sa première voiture',
                    message: 'Croise une belle auto, dégaine ton téléphone et prends-la en photo. Je m’occupe du reste.',
                    action: widget.onAddSpot == null
                        ? null
                        : ElevatedButton.icon(
                            onPressed: widget.onAddSpot,
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('Mon premier spot'),
                          ),
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.search_off_rounded, title: 'Rien par ici', message: 'Aucune voiture ne correspond à ta recherche.'),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final car = doc.data();
                      return Pressable(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SpottedCarDetailScreen(carId: doc.id, carData: car)),
                        ),
                        onLongPress: () => _quickActions(doc.id, car),
                        child: SpotCard(car: car, carId: doc.id, heroTag: 'carImage_${doc.id}'),
                      )
                          .animate()
                          .fadeIn(delay: (40 * (i % 10)).ms, duration: 280.ms)
                          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar() {
    final chips = {
      _Filter.all: 'Tout',
      _Filter.rare: 'Rares et +',
      _Filter.week: 'Cette semaine',
      _Filter.photo: 'Avec photo',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Ma collection', style: AppText.display(22))),
              IconButton(
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _search.clear();
                    _query = '';
                  }
                }),
                icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Plaque, marque, modèle, ville…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in chips.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nombre de jours consécutifs avec au moins un spot, en finissant aujourd'hui ou hier.
int spotStreak(List<Map<String, dynamic>> cars) {
  final days = cars
      .map((c) => (c['spottedAt'] as Timestamp?)?.toDate())
      .whereType<DateTime>()
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();
  if (days.isEmpty) return 0;
  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

class _Header extends StatelessWidget {
  final String uid;
  final List<Map<String, dynamic>> cars;
  final VoidCallback onMap;

  const _Header({required this.uid, required this.cars, required this.onMap});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Encore debout';
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Salut';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final pseudo = (data['pseudo'] as String?)?.trim();
        final xp = (data['totalXp'] as num?)?.toInt() ?? 0;
        final level = levelForXp(xp);
        final next = nextLevel(level);
        final progress = levelProgress(xp);
        final streak = spotStreak(cars);
        final rare = cars.where((c) => rarityOfSpot(c).index >= Rarity.rare.index).length;
        final brands = cars.map((c) => c['brandName']).whereType<String>().toSet().length;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: AppText.body(15, color: AppColors.inkSoft, weight: FontWeight.w600)),
                        Text(pseudo == null || pseudo.isEmpty ? 'Mon garage' : pseudo, style: AppText.display(30)),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: onMap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text('Carte', style: AppText.body(14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
                          child: Text('${level.level}', style: AppText.display(20, color: Theme.of(context).colorScheme.onPrimary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(level.title, style: AppText.display(18, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(
                                next == null ? '$xp XP · niveau max' : '$xp / ${next.xpRequired} XP',
                                style: AppText.body(13, color: Colors.white60, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (streak > 0)
                          Tooltip(
                            message: 'Jours de spot d’affilée',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFF8A3D)),
                                  const SizedBox(width: 4),
                                  Text('$streak j', style: AppText.body(14, color: Colors.white, weight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RevLights(value: progress),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: StatPill(value: '${cars.length}', label: 'spots', dark: true)),
                        Expanded(child: StatPill(value: '$brands', label: 'marques', dark: true)),
                        Expanded(child: StatPill(value: '$rare', label: 'rares et +', dark: true)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
              const SizedBox(height: 12),
              _ChallengeCard(
                cars: cars,
                claimed: (data['dailyClaims'] as Map?)?[DailyChallenge.todayKey()] == true,
              ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
            ],
          ),
        );
      },
    );
  }
}


class _ChallengeCard extends StatefulWidget {
  final List<Map<String, dynamic>> cars;
  final bool claimed;

  const _ChallengeCard({required this.cars, required this.claimed});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = DailyChallenge.forDay();
    final p = c.progress(widget.cars).clamp(0, c.target);
    final done = p >= c.target;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: done && !widget.claimed ? accent : AppColors.line, width: done && !widget.claimed ? 1.8 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(c.icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DÉFI DU JOUR · ${c.title.toUpperCase()}', style: AppText.label(10.5, color: AppColors.inkMuted)),
                const SizedBox(height: 3),
                Text(c.hint, style: AppText.body(15, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < c.target; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < p ? accent : AppColors.paperDeep,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text('+${c.reward} XP', style: AppText.body(12.5, color: AppColors.inkSoft, weight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          if (widget.claimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)
          else if (done)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final ok = await DailyChallenge.claim(c).catchError((_) => false);
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (ok) showAppSnack(context, 'Défi réussi ! +${c.reward} XP', icon: Icons.emoji_events_rounded);
                    },
              child: const Text('Réclamer'),
            ),
        ],
      ),
    );
  }
}
