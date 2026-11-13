import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/wanted_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Carte « Avis de recherche » : la marque de la semaine et sa prime.
class WantedCard extends StatelessWidget {
  final bool claimed;
  const WantedCard({super.key, required this.claimed});

  static const _gold = Color(0xFFFFC94D);

  @override
  Widget build(BuildContext context) {
    final brand = Wanted.brand();
    if (brand == null) return const SizedBox.shrink();
    final name = '${brand['name']}';
    final left = Wanted.weekEnd().difference(DateTime.now());
    final leftLabel = left.inHours < 24
        ? tr('Plus que {0} h', [max(1, left.inHours)])
        : tr('Plus que {0} j', [left.inDays + (left.inHours % 24 > 0 ? 1 : 0)]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17130A), Color(0xFF0D0D10)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _gold.withValues(alpha: claimed ? 0.25 : 0.55)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Stripes()))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 14, color: _gold),
                      const SizedBox(width: 6),
                      Text(tr('AVIS DE RECHERCHE'), style: AppText.label(11, color: _gold).copyWith(letterSpacing: 2.2)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(99)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(leftLabel, style: AppText.body(11, color: Colors.white70, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      BrandLogo(url: brand['logoUrl'] as String?, name: name, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(name.toUpperCase(), style: AppText.display(24, color: Colors.white)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              claimed ? tr('Capturée ! Nouvelle cible lundi.') : tr('Spotte une {0} cette semaine', [name]),
                              maxLines: 2,
                              style: AppText.body(12.5, color: Colors.white70, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Stamp(claimed: claimed),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final bool claimed;
  const _Stamp({required this.claimed});

  @override
  Widget build(BuildContext context) {
    final color = claimed ? AppColors.success : WantedCard._gold;
    final stamp = Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
          color: color.withValues(alpha: 0.08),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(claimed ? '✓' : tr('PRIME'), style: AppText.label(claimed ? 16 : 9.5, color: color).copyWith(letterSpacing: 1.5)),
            if (!claimed) Text('+${Wanted.bounty}', style: AppText.display(20, color: color)),
            Text('XP', style: AppText.label(9.5, color: color)),
          ],
        ),
      ),
    );
    if (claimed) return stamp;
    return stamp
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1200.ms, curve: Curves.easeInOut);
  }
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = WantedCard._gold.withValues(alpha: 0.05);
    for (double x = -size.height; x < size.width; x += 22) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + 10, size.height)
        ..lineTo(x + 10 + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
