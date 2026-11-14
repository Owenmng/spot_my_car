import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/screens/plus_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/services/quest_service.dart';
import 'package:spot_my_car/services/wanted_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Carte « Quêtes de la semaine » avec barres de progression et bouton d'encaissement.
class WeeklyQuestsCard extends StatefulWidget {
  final List<Map<String, dynamic>> cars;
  final Map<String, dynamic> user;
  const WeeklyQuestsCard({super.key, required this.cars, required this.user});

  @override
  State<WeeklyQuestsCard> createState() => _WeeklyQuestsCardState();
}

class _WeeklyQuestsCardState extends State<WeeklyQuestsCard> {
  final _busy = <String>{};

  Future<void> _claim(Quest q) async {
    setState(() => _busy.add(q.id));
    final ok = await QuestService.claim(q).catchError((_) => false);
    if (!mounted) return;
    setState(() => _busy.remove(q.id));
    if (ok) {
      HapticFeedback.heavyImpact();
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      showAppSnack(context, tr('Quête terminée : +{0} XP', [q.reward]), icon: Icons.flag_rounded, color: AppColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final quests = QuestService.forWeek(widget.cars, widget.user);
    final left = Wanted.weekEnd().difference(DateTime.now());
    final doneCount = quests.where((q) => q.claimed).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(tr('QUÊTES DE LA SEMAINE'), style: AppText.label(11, color: accent).copyWith(letterSpacing: 2)),
              const Spacer(),
              Text(
                doneCount == quests.length ? tr('Tout est bouclé 🏁') : tr('{0}/{1} · reset dans {2} j', [doneCount, quests.length, left.inDays + 1]),
                style: AppText.body(11.5, color: AppColors.inkMuted, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final q in quests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.title,
                                style: AppText.body(14, weight: FontWeight.w700, color: q.claimed ? AppColors.inkMuted : AppColors.ink).copyWith(decoration: q.claimed ? TextDecoration.lineThrough : null),
                              ),
                            ),
                            Text('${q.progress.clamp(0, q.goal)}/${q.goal}', style: AppText.mono(12, color: AppColors.inkSoft)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: (q.progress / q.goal).clamp(0, 1).toDouble()),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              backgroundColor: AppColors.line,
                              color: q.done ? AppColors.success : accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    height: 34,
                    child: q.claimed
                        ? const Center(child: Icon(Icons.check_circle_rounded, color: AppColors.success))
                        : q.done
                            ? FilledButton(
                                style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppColors.success),
                                onPressed: _busy.contains(q.id) ? null : () => _claim(q),
                                child: Text('+${q.reward}', style: AppText.label(12.5, color: Colors.white)),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 700.ms)
                            : Center(child: Text('+${q.reward} XP', style: AppText.body(12.5, color: AppColors.inkMuted, weight: FontWeight.w800))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bannière d'offre Spot My Car+ pour les joueurs gratuits.
class PlusBanner extends StatelessWidget {
  const PlusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = PlusScreen.gold;
    return Pressable(
      onTap: () => PlusScreen.open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(colors: [Color(0xFF1C160A), Color(0xFF0E0D0B)]),
          border: Border.all(color: gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFE08A), gold, Color(0xFFE59A1A)]), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Passe à Spot My Car+'), style: AppText.body(15, color: Colors.white, weight: FontWeight.w800)),
                  Text(tr('XP doublée, thèmes exclusifs, zéro pub'), style: AppText.body(12.5, color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: gold),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 220.ms).shimmer(delay: 1200.ms, duration: 1500.ms, color: gold.withValues(alpha: 0.25));
  }
}

bool showPlusBanner() => PlusService.instance.enabled && !PlusService.instance.isPlus;
