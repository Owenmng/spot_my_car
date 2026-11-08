import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/achievements_screen.dart';
import 'package:spot_my_car/community_screen.dart';
import 'package:spot_my_car/garage_screen.dart' show spotStreak;
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/settings_screen.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final data = context.watch<DataManager>();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnap) {
          final u = userSnap.data?.data() ?? {};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).snapshots(),
            builder: (context, carsSnap) {
              final cars = (carsSnap.data?.docs ?? []).map((d) => d.data()).toList();
              final xp = (u['totalXp'] as num?)?.toInt() ?? 0;
              final level = levelForXp(xp);
              final next = nextLevel(level);
              final pseudo = (u['pseudo'] as String?)?.trim();
              final name = (pseudo == null || pseudo.isEmpty) ? (user.displayName ?? tr('Spotter')) : pseudo;
              final achievements = AchievementService(allBrands: data.brands, spottedCars: cars).checkAchievements();
              final unlockedLevels = achievements.fold<int>(0, (s, a) => s + a.unlockedLevel);
              final totalLevels = achievements.fold<int>(0, (s, a) => s + a.levels.length);
              final close = achievements.where((a) => !a.isFullyCompleted).toList()
                ..sort((a, b) => b.progressToNext.compareTo(a.progressToNext));

              final rarityCounts = List<int>.filled(Rarity.values.length, 0);
              for (final c in cars) {
                rarityCounts[rarityOfSpot(c).index]++;
              }
              final brandCounts = <String, int>{};
              for (final c in cars) {
                final b = c['brandName'] as String?;
                if (b != null) brandCounts[b] = (brandCounts[b] ?? 0) + 1;
              }
              final topBrand = brandCounts.entries.isEmpty ? null : (brandCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
              final since = user.metadata.creationTime;

              return ListView(
                padding: EdgeInsets.fromLTRB(16, top + 12, 16, 32),
                children: [
                  Row(
                    children: [
                      Text(tr('Profil'), style: AppText.display(32)),
                      const Spacer(),
                      _IconPill(
                        icon: Icons.tune_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Identity(name: name, photoUrl: u['photoUrl'] as String?, friendId: u['friendId'] as String?, levelTitle: level.title, since: since),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('NIV. ${level.level}', style: AppText.label(12, color: Theme.of(context).colorScheme.primary)),
                            const Spacer(),
                            Text(next == null ? '$xp XP' : tr('{0} / {1} XP', [xp, next.xpRequired]), style: AppText.mono(13, color: AppColors.inkSoft)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(level.title, style: AppText.display(26)),
                        const SizedBox(height: 14),
                        RevLights(value: levelProgress(xp)),
                        if (next != null) ...[
                          const SizedBox(height: 10),
                          Text(tr('Encore {0} XP avant « {1} »', [next.xpRequired - xp, next.title]), style: AppText.body(13, color: AppColors.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('toUserId', isEqualTo: user.uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, s) {
                      final pending = s.data?.docs.length ?? 0;
                      return _NavTile(
                        icon: Icons.leaderboard_rounded,
                        title: tr('Paddock'),
                        subtitle: pending > 0 ? tr('{0} demande{1} d’ami en attente', [pending, pending > 1 ? 's' : '']) : tr('Amis, duels, blind test et classement'),
                        badge: pending,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      _Stat(value: '${cars.length}', label: tr('Spots')),
                      _Stat(value: '${cars.map((c) => c['modelId']).whereType<String>().toSet().length}', label: tr('Modèles')),
                      _Stat(value: '${brandCounts.length}', label: tr('Marques')),
                      _Stat(value: '${spotStreak(cars)} j', label: tr('Série en cours')),
                      _Stat(value: '${rarityCounts[3] + rarityCounts[4]}', label: tr('Exotiques +')),
                      _Stat(value: topBrand?.key ?? '—', label: tr('Marque fétiche'), small: true),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(title: tr('Répartition par rareté')),
                  const SizedBox(height: 10),
                  _RarityBars(counts: rarityCounts),
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: tr('Succès'),
                    trailing: '$unlockedLevels / $totalLevels',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                  ),
                  const SizedBox(height: 10),
                  for (final a in close.take(3)) _AchievementRow(a: a),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                    child: Text(tr('Voir tous les succès')),
                  ),
                ].animate(interval: 30.ms).fadeIn(duration: 260.ms),
              );
            },
          );
        },
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconPill({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
        child: const Icon(Icons.tune_rounded, size: 20),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? friendId;
  final String levelTitle;
  final DateTime? since;

  const _Identity({required this.name, required this.photoUrl, required this.friendId, required this.levelTitle, required this.since});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final hasPhoto = photoUrl != null && photoUrl!.startsWith('http');

    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [accent, accent.withValues(alpha: 0.2), accent])),
          child: CircleAvatar(
            backgroundColor: AppColors.panelHi,
            backgroundImage: hasPhoto ? NetworkImage(photoUrl!, headers: kImageHeaders) : null,
            child: hasPhoto ? null : Text(initials.isEmpty ? '?' : initials, style: AppText.display(24)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(26)),
              if (since != null)
                Text(tr('Spotter depuis {0}', [DateFormat('MMMM yyyy', I18n.instance.dateLocale).format(since!)]), style: AppText.body(13, color: AppColors.inkSoft)),
              if (friendId != null) ...[
                const SizedBox(height: 8),
                Pressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: friendId!));
                    showAppSnack(context, tr('Code ami copié'), icon: Icons.copy_rounded);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.line)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('CODE AMI  '), style: AppText.label(10.5, color: AppColors.inkMuted)),
                        Text(friendId!, style: AppText.mono(12.5)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool small;
  const _Stat({required this.value, required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(9.5, color: AppColors.inkMuted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.display(small ? 18 : 26)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppText.label(12, color: AppColors.inkSoft)),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: AppText.mono(12.5, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _RarityBars extends StatelessWidget {
  final List<int> counts;
  const _RarityBars({required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxC = counts.fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in Rarity.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${counts[r.index]}', style: AppText.mono(12, color: r.color)),
                    const SizedBox(height: 4),
                    Flexible(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: counts[r.index] / maxC),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => FractionallySizedBox(
                          heightFactor: v.clamp(0.04, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [r.color.withValues(alpha: 0.35), r.color]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(10, color: AppColors.inkSoft, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final Achievement a;
  const _AchievementRow({required this.a});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final lvl = a.displayLevel;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: a.progressToNext, strokeWidth: 3, color: accent, backgroundColor: AppColors.paperDeep, strokeCap: StrokeCap.round),
                Icon(a.icon, size: 19, color: AppColors.ink),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lvl.title, style: AppText.body(15, weight: FontWeight.w800)),
                Text(lvl.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(12.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${a.currentProgress.clamp(0, lvl.target)}/${lvl.target}', style: AppText.mono(12, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(15.5, weight: FontWeight.w800)),
                  Text(subtitle, style: AppText.body(13, color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)),
                child: Text('$badge', style: AppText.body(12, color: Theme.of(context).colorScheme.onPrimary, weight: FontWeight.w800)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
