import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/screens/plate_lookup_screen.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/community_screen.dart';
import 'package:spot_my_car/map_screen.dart';
import 'package:spot_my_car/quiz_screen.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:spot_my_car/services/wishlist_service.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/notification_service.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/services/photo_store.dart';
import 'package:spot_my_car/services/share_service.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:spot_my_car/widgets/garage_hero.dart';
import 'package:spot_my_car/widgets/wanted_card.dart';
import 'package:spot_my_car/widgets/weekly_quests_card.dart';
import 'package:spot_my_car/screens/referral_screen.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/services/wanted_service.dart';

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
        title: Text(tr('Retirer du garage ?')),
        content: Text(tr('{0} sera supprimée, avec sa photo.', [fullCarName(car['brandName'] as String?, car['modelName'] as String?)])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Garder'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(tr('Supprimer')),
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
      if (mounted) showAppSnack(context, tr('Voiture retirée du garage.'), icon: Icons.delete_outline);
    } catch (_) {
      if (mounted) showAppSnack(context, tr('La suppression a échoué.'), icon: Icons.error_outline);
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
              title: Text(tr('Partager la carte')),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareSpot(this.context, car, carId: id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(tr('Supprimer'), style: TextStyle(color: AppColors.danger)),
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
          if (snap.hasData && !snap.data!.metadata.hasPendingWrites) {
            unawaited(NotificationService.instance.refresh(cars, streak: spotStreak(cars)));
            DuelService.instance.syncDebounced(cars);
          }
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
                  child: EmptyState(icon: Icons.cloud_off_rounded, title: tr('Garage injoignable'), message: tr('Impossible de charger tes voitures pour l\'instant. Vérifie ta connexion.')),
                )
              else if (cars.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: tr('Ton garage attend sa première voiture'),
                    message: tr('Croise une belle auto, dégaine ton téléphone et prends-la en photo. Je m’occupe du reste.'),
                    action: widget.onAddSpot == null
                        ? null
                        : ElevatedButton.icon(
                            onPressed: widget.onAddSpot,
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: Text(tr('Mon premier spot')),
                          ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.search_off_rounded, title: tr('Rien par ici'), message: tr('Aucune voiture ne correspond à ta recherche.')),
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
      _Filter.all: tr('Tout'),
      _Filter.rare: tr('Rares et +'),
      _Filter.week: tr('Cette semaine'),
      _Filter.photo: tr('Avec photo'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr('Ma collection'), style: AppText.display(22))),
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
                      decoration: InputDecoration(
                        hintText: tr('Plaque, marque, modèle, ville…'),
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
    if (h < 6) return tr('Encore debout');
    if (h < 12) return tr('Bonjour');
    if (h < 18) return tr('Salut');
    return tr('Bonsoir');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final pseudo = (data['pseudo'] as String?)?.trim();
        final xp = (data['totalXp'] as num?)?.toInt() ?? 0;
        final streak = spotStreak(cars);

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
                        Row(
                          children: [
                            Flexible(child: Text(pseudo == null || pseudo.isEmpty ? tr('Mon garage') : pseudo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(30))),
                            ListenableBuilder(
                              listenable: PlusService.instance,
                              builder: (context, _) => PlusService.instance.isPlus
                                  ? Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFC94D), Color(0xFFE59A1A)]),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text('PLUS', style: AppText.label(10, color: Colors.black)),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
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
                          Text(tr('Carte'), style: AppText.body(14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GarageHero(
                xp: xp,
                cars: cars,
                streak: streak,
                rarityOf: rarityOfSpot,
                onShare: RemoteConfig.instance.feature('shareStats')
                    ? () => ShareService.shareStats(context, GarageHero(xp: xp, cars: cars, streak: streak, rarityOf: rarityOfSpot))
                    : null,
              ),
              const SizedBox(height: 12),
              _ChallengeCard(
                cars: cars,
                claimed: (data['dailyClaims'] as Map?)?[DailyChallenge.todayKey()] == true,
              ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
              ListenableBuilder(
                listenable: RemoteConfig.instance,
                builder: (context, _) => RemoteConfig.instance.feature('wanted')
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: WantedCard(claimed: Wanted.claimed(data)).animate().fadeIn(delay: 160.ms, duration: 350.ms),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: WeeklyQuestsCard(cars: cars, user: data).animate().fadeIn(delay: 190.ms, duration: 350.ms),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([RemoteConfig.instance, PlusService.instance]),
                builder: (context, _) => showPlusBanner() ? const Padding(padding: EdgeInsets.only(top: 12), child: PlusBanner()) : const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('PADDOCK', style: AppText.label(11.5, color: AppColors.inkMuted)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
                    icon: const Icon(Icons.leaderboard_rounded, size: 16),
                    label: Text(tr('Amis & classement')),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _PlayStrip().animate().fadeIn(delay: 200.ms, duration: 350.ms),
              const _TargetsStrip(),
            ],
          ),
        );
      },
    );
  }
}

/// « Dans le viseur » : les modèles que le joueur veut croiser (bonus XP).
class _TargetsStrip extends StatelessWidget {
  const _TargetsStrip();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return StreamBuilder<List<String>>(
      stream: WishlistService.instance.watch(),
      builder: (context, snap) {
        final data = DataManager.instance;
        final targets = (snap.data ?? const []).map(data.modelById).whereType<Map<String, dynamic>>().toList();
        if (targets.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 15, color: accent),
                  const SizedBox(width: 6),
                  Text(tr('DANS LE VISEUR'), style: AppText.label(11.5, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(tr('+{0} XP chacune', [WishlistService.bonusXp]), style: AppText.body(12, color: AppColors.inkSoft, weight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: targets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final m = targets[i];
                    final brand = data.brandOfModel(m['id'] as String);
                    return Pressable(
                      onTap: brand == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ModelDetailScreen(modelsList: [m], initialIndex: 0, isSpotted: false, brand: brand)),
                              ),
                      child: SizedBox(
                        width: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CarImage(urls: [m['imageUrl'] as String?], brandName: brand?['name'] as String?, modelName: cleanModelName(m['name'] as String?)),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.45, 1],
                                    colors: [Colors.transparent, Color(0xCC000000)],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 7,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${brand?['name'] ?? ''}'.toUpperCase(), maxLines: 1, style: AppText.label(9, color: Colors.white70)),
                                    Text(cleanModelName(m['name'] as String?), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(15, color: Colors.white)),
                                  ],
                                ),
                              ),
                              Positioned(top: 6, right: 6, child: Icon(Icons.gps_fixed_rounded, size: 16, color: accent)),
                            ],
                          ),
                        ),
                      ),
                    );
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

/// Raccourcis jeu : duels entre amis et blind test du jour.
class _PlayStrip extends StatelessWidget {
  const _PlayStrip();

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return ListenableBuilder(
      listenable: RemoteConfig.instance,
      builder: (context, _) {
        final rc = RemoteConfig.instance;
        final duels = rc.feature('duels');
        final quiz = rc.feature('blindTest');
        return Column(
          children: [
            if (duels || quiz)
              Row(
      children: [
        if (duels) Expanded(
          child: StreamBuilder<List<Duel>>(
            stream: DuelService.instance.watch(),
            builder: (context, snap) {
              final duels = snap.data ?? [];
              final invites = duels.where((d) => d.isPending && d.opponentId == me).length;
              final live = duels.where((d) => d.isActive).toList();
              final toClaim = duels.where((d) => d.winner == me && d.claimed[me] != true).length;
              String sub;
              if (invites > 0) {
                sub = invites == 1 ? tr('1 défi reçu !') : tr('{0} défis reçus !', [invites]);
              } else if (toClaim > 0) {
                sub = tr('Gains à encaisser');
              } else if (live.isNotEmpty) {
                final d = live.first;
                final mine = d.scoreOf(me ?? ''), theirs = d.scoreOf(d.other(me ?? ''));
                sub = mine > theirs ? tr('Tu mènes {0}', [d.scoreLabel(mine)]) : mine == theirs ? tr('Égalité, accélère') : tr('Tu es mené');
              } else {
                sub = tr('Défie un ami');
              }
              return _PlayTile(
                icon: Icons.sports_mma_rounded,
                title: tr('Duels'),
                subtitle: sub,
                badge: invites + toClaim,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityScreen(initialTab: invites + toClaim + live.length > 0 ? 1 : 0))),
              );
            },
          ),
        ),
        if (duels && quiz) const SizedBox(width: 10),
        if (quiz) Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: me == null ? null : FirebaseFirestore.instance.collection('users').doc(me).snapshots(),
            builder: (context, snap) {
              final played = (snap.data?.data()?['quizClaims'] as Map?)?[DailyChallenge.todayKey()];
              return _PlayTile(
                icon: Icons.quiz_rounded,
                title: tr('Blind test'),
                subtitle: played == null ? tr('Jusqu’à +50 XP') : tr('Fait : +{0} XP', [played]),
                badge: played == null ? 1 : 0,
                dot: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen())),
              );
            },
          ),
        ),
      ],
    ),
            if (rc.feature('referral')) ...[
              if (duels || quiz) const SizedBox(height: 10),
              _PlayTile(
                icon: Icons.card_giftcard_rounded,
                title: tr('Invite tes potes'),
                subtitle: tr('+{0} XP pour toi et pour eux', [ReferralScreen.reward]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen())),
              ),
            ],
            if (rc.feature('plateLookup')) ...[
              if (duels || quiz || rc.feature('referral')) const SizedBox(height: 10),
              _PlayTile(
                icon: Icons.pin_rounded,
                title: tr('Assistant plaque'),
                subtitle: tr('Une plaque, mais quel modèle ? On t\'aide'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlateLookupScreen())),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlayTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badge;
  final bool dot;
  final VoidCallback onTap;
  const _PlayTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge = 0, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: badge > 0 ? accent.withValues(alpha: 0.6) : AppColors.line),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: accent, size: 21),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFFD447), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.card, width: 2)),
                      alignment: Alignment.center,
                      child: dot ? null : Text('$badge', style: AppText.mono(9.5, color: Colors.black)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(14.5, weight: FontWeight.w800)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
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
                Text(tr('DÉFI DU JOUR · {0}', [c.title.toUpperCase()]), style: AppText.label(10.5, color: AppColors.inkMuted)),
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
                    Text(tr('+{0} XP', [c.reward]), style: AppText.body(12.5, color: AppColors.inkSoft, weight: FontWeight.w700)),
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
                      if (ok) showAppSnack(context, tr('Défi réussi ! +{0} XP', [c.reward]), icon: Icons.emoji_events_rounded);
                    },
              child: Text(tr('Réclamer')),
            ),
        ],
      ),
    );
  }
}
