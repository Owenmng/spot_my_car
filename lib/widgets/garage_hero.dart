import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';

/// Carte héros de l'accueil : la plus belle voiture du garage en vitrine,
/// le niveau dans un compte-tours, l'XP qui reste et les chiffres clés.
class GarageHero extends StatelessWidget {
  final int xp;
  final List<Map<String, dynamic>> cars;
  final int streak;
  final Rarity Function(Map<String, dynamic>) rarityOf;
  final VoidCallback? onShare;

  const GarageHero({super.key, required this.xp, required this.cars, required this.streak, required this.rarityOf, this.onShare});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final level = levelForXp(xp);
    final next = nextLevel(level);
    final progress = levelProgress(xp).clamp(0.0, 1.0);
    final brands = cars.map((c) => c['brandName']).whereType<String>().toSet().length;
    final rare = cars.where((c) => rarityOf(c).index >= Rarity.rare.index).length;

    // Vitrine : la voiture la plus rare (puis la plus récente).
    Map<String, dynamic>? star;
    Rarity starRarity = Rarity.commune;
    for (final c in cars) {
      final r = rarityOf(c);
      if (star == null || r.index > starRarity.index) {
        star = c;
        starRarity = r;
      }
    }
    final starImg = star?['modelImageUrl'] as String?;
    final starName = star == null ? null : '${star['brandName'] ?? ''} ${star['modelName'] ?? ''}'.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0B0B10), Color.lerp(const Color(0xFF0B0B10), accent, 0.30)!],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Stack(
          children: [
            // La voiture vedette, en fondu sur la droite
            if (starImg != null)
              Positioned(
                right: -30,
                top: 0,
                bottom: 70,
                width: 250,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.55],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Opacity(
                    opacity: 0.55,
                    child: CarImage(urls: [starImg], fit: BoxFit.cover, borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
            // Lignes de piste
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Speedlines(accent)))),
            if (onShare != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Partager mon garage'),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _LevelGauge(level: level.level, progress: progress, accent: accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('NIVEAU {0}', [level.level]), style: AppText.label(11, color: accent).copyWith(letterSpacing: 2.5)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(level.title.toUpperCase(), style: AppText.display(30, color: Colors.white)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              next == null ? tr('Niveau maximum atteint') : tr('Encore {0} XP avant {1}', [next.xpRequired - xp, next.title]),
                              style: AppText.body(12.5, color: Colors.white70, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (onShare != null) const SizedBox(width: 30),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _XpBar(progress: progress, accent: accent, xp: xp, target: next?.xpRequired),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.white10)),
                    child: Row(
                      children: [
                        _Kpi(icon: Icons.directions_car_filled_rounded, value: cars.length, label: tr('spots')),
                        _divider(),
                        _Kpi(icon: Icons.workspace_premium_rounded, value: brands, label: tr('marques')),
                        _divider(),
                        _Kpi(icon: Icons.diamond_rounded, value: rare, label: tr('rares et +'), color: const Color(0xFFB47CFF)),
                        _divider(),
                        _Kpi(icon: Icons.local_fire_department_rounded, value: streak, label: tr('jours de série'), color: const Color(0xFFFF8A3D), glow: streak > 0),
                      ],
                    ),
                  ),
                  if (starName != null && starName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: starRarity.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: tr('Ta pépite : '), style: AppText.body(12.5, color: Colors.white60)),
                              TextSpan(text: starName, style: AppText.body(12.5, color: Colors.white, weight: FontWeight.w800)),
                              TextSpan(text: ' · ${starRarity.label}', style: AppText.body(12.5, color: starRarity.color, weight: FontWeight.w700)),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white12);
}

class _LevelGauge extends StatelessWidget {
  final int level;
  final double progress;
  final Color accent;
  const _LevelGauge({required this.level, required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 88,
        height: 88,
        child: CustomPaint(
          painter: _GaugePainter(v, accent),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$level', style: AppText.display(34, color: Colors.white)),
                Text('LVL', style: AppText.label(9, color: Colors.white54).copyWith(letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final Color accent;
  _GaugePainter(this.v, this.accent);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 6;
    const start = pi * 0.75, sweep = pi * 1.5;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, start, sweep, false, Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
    // graduations façon compte-tours
    final tick = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 10; i++) {
      final a = start + sweep * i / 10;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * (r - 10), c + Offset(cos(a), sin(a)) * (r - 15), tick);
    }
    if (v > 0) {
      canvas.drawArc(rect, start, sweep * v, false, Paint()
        ..shader = SweepGradient(startAngle: start, endAngle: start + sweep, colors: [accent.withValues(alpha: 0.6), accent, const Color(0xFFFFC94D)]).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
      final a = start + sweep * v;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, 5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.v != v || old.accent != accent;
}

class _XpBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final int xp;
  final int? target;
  const _XpBar({required this.progress, required this.accent, required this.xp, this.target});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$xp XP', style: AppText.mono(12.5, color: Colors.white)),
            const Spacer(),
            if (target != null) Text('$target XP', style: AppText.mono(12.5, color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Container(height: 10, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(99))),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Container(
                  height: 10,
                  width: max(10.0, box.maxWidth * v),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, const Color(0xFFFF8A3D), const Color(0xFFFFC94D)]),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 10)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color? color;
  final bool glow;
  const _Kpi({required this.icon, required this.value, required this.label, this.color, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: c, shadows: glow ? [Shadow(color: c, blurRadius: 12)] : null),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('${v.round()}', style: AppText.display(22, color: Colors.white)),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(10.5, color: Colors.white60, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Speedlines extends CustomPainter {
  final Color accent;
  _Speedlines(this.accent);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final y = s.height * (0.15 + i * 0.07);
      canvas.drawLine(Offset(s.width * (0.55 + i * 0.04), y), Offset(s.width, y - 18), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Speedlines old) => false;
}
