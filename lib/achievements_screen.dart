import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final data = context.watch<DataManager>();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).snapshots(),
      builder: (context, snap) {
        final cars = (snap.data?.docs ?? []).map((d) => d.data()).toList();
        final all = AchievementService(allBrands: data.brands, spottedCars: cars).checkAchievements();
        final done = all.fold<int>(0, (s, a) => s + a.unlockedLevel);
        final total = all.fold<int>(0, (s, a) => s + a.levels.length);
        final xp = all.fold<int>(0, (s, a) => s + a.levels.take(a.unlockedLevel).fold<int>(0, (x, l) => x + l.xpReward));

        return DefaultTabController(
          length: AchievementService.categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Succès'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final c in AchievementService.categories) Tab(text: c)],
              ),
            ),
            body: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _Big(value: '$done / $total', label: 'paliers débloqués')),
                      Expanded(child: _Big(value: '$xp', label: 'XP gagnés en succès')),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final cat in AchievementService.categories)
                        ListView(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
                          children: [
                            for (final a in all.where((a) => a.category == cat)) _AchievementCard(a: a),
                          ].animate(interval: 40.ms).fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Big extends StatelessWidget {
  final String value;
  final String label;
  const _Big({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.display(26)),
          Text(label, style: AppText.body(12, color: AppColors.inkSoft)),
        ],
      );
}

class _AchievementCard extends StatelessWidget {
  final Achievement a;
  const _AchievementCard({required this.a});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final done = a.isFullyCompleted;
    final current = a.displayLevel;
    const gold = Color(0xFFFFC94D);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: done ? gold.withValues(alpha: 0.6) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (done ? gold : a.unlockedLevel > 0 ? accent : AppColors.inkMuted).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(a.icon, color: done ? gold : a.unlockedLevel > 0 ? accent : AppColors.inkSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(done ? a.levels.last.title : current.title, style: AppText.body(16, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(done ? 'Tous les paliers sont débloqués' : current.description, style: AppText.body(13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              if (!done) Text('+${current.xpReward} XP', style: AppText.mono(12, color: accent)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < a.levels.length; i++) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: i < a.unlockedLevel
                            ? Icon(Icons.check_circle_rounded, size: 22, color: done ? gold : accent)
                            : CircularProgressIndicator(
                                value: i == a.unlockedLevel ? a.progressToNext : 0,
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                                color: accent,
                                backgroundColor: AppColors.paperDeep,
                              ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        a.levels[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(10.5, color: i < a.unlockedLevel ? AppColors.ink : AppColors.inkMuted, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (i < a.levels.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (!done) ...[
            const SizedBox(height: 8),
            Text('${a.currentProgress.clamp(0, current.target)} / ${current.target}', style: AppText.mono(11.5, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}
