import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';

const _gold = Color(0xFFFFD447);

/// Médaille qui tombe, rayons dorés, palier du succès. Un seul par spot.
class AchievementOverlay extends StatelessWidget {
  final AchievementLevel achievement;
  final IconData icon;
  final int others;
  final VoidCallback onDismissed;

  const AchievementOverlay({super.key, required this.achievement, required this.icon, required this.onDismissed, this.others = 0});

  @override
  Widget build(BuildContext context) {
    final w = min(MediaQuery.sizeOf(context).width - 48, 360.0);
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        child: InkWell(
          onTap: onDismissed,
          child: SafeArea(
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('SUCCÈS DÉBLOQUÉ'), style: AppText.label(13, color: _gold)).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const _Rays().animate(onPlay: (c) => c.repeat()).rotate(duration: 14.seconds),
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(colors: [Color(0xFFFFE89A), _gold, Color(0xFFB8860B)], stops: [0, 0.55, 1]),
                            boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 4)],
                            border: Border.all(color: const Color(0xFFFFF3C4), width: 3),
                          ),
                          child: Icon(icon, size: 58, color: const Color(0xFF3A2A00)),
                        )
                            .animate()
                            .scale(begin: const Offset(2.2, 2.2), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeInCubic)
                            .fadeIn(duration: 200.ms)
                            .then()
                            .shake(hz: 3, rotation: 0.04, duration: 300.ms)
                            .shimmer(delay: 200.ms, duration: 1100.ms, color: Colors.white70),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: w,
                    child: Column(
                      children: [
                        Text(achievement.title.toUpperCase(), textAlign: TextAlign.center, style: AppText.display(32, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(achievement.description, textAlign: TextAlign.center, style: AppText.body(15, color: Colors.white70)),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 1; i <= max(3, achievement.level); i++)
                              Container(
                                width: 26,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: i <= achievement.level ? _gold : Colors.white12,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ).animate().fadeIn(delay: (600 + i * 120).ms).scaleX(begin: 0),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('PALIER ${achievement.level}', style: AppText.label(10.5, color: Colors.white38)),
                        const SizedBox(height: 18),
                        Text(tr('+{0} XP', [achievement.xpReward]), style: AppText.display(26, color: _gold))
                            .animate()
                            .fadeIn(delay: 800.ms)
                            .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
                        if (others > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            others == 1 ? tr('et 1 autre succès dans ton profil') : tr('et {0} autres succès dans ton profil', [others]),
                            style: AppText.body(13, color: Colors.white54),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(onPressed: onDismissed, child: Text(tr('Excellent'))),
                        ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3, end: 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _Rays extends StatelessWidget {
  const _Rays();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(child: CustomPaint(painter: _RaysPainter()));
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * cos(a - 0.09), c.dy + r * sin(a - 0.09))
        ..lineTo(c.dx + r * cos(a + 0.09), c.dy + r * sin(a + 0.09))
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> showAchievementUnlocked(BuildContext context, AchievementLevel achievement, IconData icon, {int others = 0}) {
  final completer = Completer<void>();
  AudioService.instance.playSfx(SoundEffect.achievement);
  HapticFeedback.mediumImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AchievementOverlay(
      achievement: achievement,
      icon: icon,
      others: others,
      onDismissed: () {
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  Overlay.of(context).insert(entry);
  return completer.future.then((_) => entry.remove());
}
