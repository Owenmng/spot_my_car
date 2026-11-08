import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Passage de rapport : le compte-tours grimpe jusqu'à la zone rouge, les
/// shift-lights clignotent, puis le rapport (= niveau) passe au suivant.
class LevelUpOverlay extends StatefulWidget {
  final Level oldLevel;
  final Level newLevel;
  final int oldXp;
  final int newXp;
  final VoidCallback onDismissed;

  const LevelUpOverlay({super.key, required this.oldLevel, required this.newLevel, required this.oldXp, required this.newXp, required this.onDismissed});

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> with TickerProviderStateMixin {
  late final AnimationController _rev = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  bool _shifted = false;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playSfx(SoundEffect.levelUp);
    Future.delayed(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      await _rev.animateTo(1, curve: Curves.easeInQuad);
      if (!mounted) return;
      for (var i = 0; i < 3; i++) {
        await _flash.forward(from: 0);
        await _flash.reverse();
        if (!mounted) return;
      }
      HapticFeedback.heavyImpact();
      setState(() => _shifted = true);
      _rev.animateTo(0.35, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _rev.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final next = nextLevel(widget.newLevel);
    final w = min(MediaQuery.sizeOf(context).width - 48, 360.0);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_shifted ? tr('RAPPORT SUPÉRIEUR') : tr('MONTÉE EN RÉGIME…'), style: AppText.label(13, color: _shifted ? accent : Colors.white54)),
                const SizedBox(height: 26),
                SizedBox(
                  width: w,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_rev, _flash]),
                    builder: (_, _) => _ShiftLights(value: _rev.value, flash: _flash.value),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 210,
                  height: 210,
                  child: AnimatedBuilder(
                    animation: _rev,
                    builder: (_, _) => CustomPaint(
                      painter: _TachoPainter(value: _rev.value, accent: accent),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          transitionBuilder: (child, a) => ScaleTransition(
                            scale: Tween(begin: 1.8, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                            child: FadeTransition(opacity: a, child: child),
                          ),
                          child: Column(
                            key: ValueKey(_shifted),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('NIVEAU', style: AppText.label(11, color: Colors.white38)),
                              Text(
                                '${_shifted ? widget.newLevel.level : widget.oldLevel.level}',
                                style: AppText.mono(76, color: _shifted ? Colors.white : Colors.white60).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedOpacity(
                  opacity: _shifted ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: SizedBox(
                    width: w,
                    child: Column(
                      children: [
                        Text(widget.newLevel.title.toUpperCase(), textAlign: TextAlign.center, style: AppText.display(34, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(tr('{0} XP au compteur', [widget.newXp]), style: AppText.mono(14, color: Colors.white54)),
                        if (next != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded, size: 16, color: Colors.white54),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tr('Prochain rapport : {0} à {1} XP', [next.title, next.xpRequired]),
                                    style: AppText.body(13, color: Colors.white70, weight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(onPressed: _shifted ? widget.onDismissed : null, child: Text(tr('Passer la vitesse'))),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _ShiftLights extends StatelessWidget {
  final double value;
  final double flash;
  const _ShiftLights({required this.value, required this.flash});

  @override
  Widget build(BuildContext context) {
    const count = 15;
    final lit = (value * count).round();
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Container(
              height: 14,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: flash > 0.5
                    ? const Color(0xFF4DA3FF)
                    : i < lit
                        ? (i < 7 ? const Color(0xFF3DDC84) : i < 11 ? const Color(0xFFFFC53D) : const Color(0xFFFF4D4F))
                        : Colors.white10,
                boxShadow: flash > 0.5
                    ? [const BoxShadow(color: Color(0xAA4DA3FF), blurRadius: 12)]
                    : i < lit
                        ? [BoxShadow(color: (i < 7 ? const Color(0xFF3DDC84) : i < 11 ? const Color(0xFFFFC53D) : const Color(0xFFFF4D4F)).withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _TachoPainter extends CustomPainter {
  final double value;
  final Color accent;
  _TachoPainter({required this.value, required this.accent});

  static const _start = pi * 0.75;
  static const _sweep = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(rect, _start, _sweep, false, Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round);
    // zone rouge
    canvas.drawArc(rect, _start + _sweep * 0.8, _sweep * 0.2, false, Paint()
      ..color = const Color(0x55FF4D4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10);
    canvas.drawArc(rect, _start, _sweep * value, false, Paint()
      ..shader = SweepGradient(startAngle: _start, endAngle: _start + _sweep, colors: [accent.withValues(alpha: 0.4), accent, const Color(0xFFFF4D4F)], transform: const GradientRotation(0)).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round);

    // graduations
    final tick = Paint()
      ..color = Colors.white38
      ..strokeWidth = 2;
    for (var i = 0; i <= 8; i++) {
      final a = _start + _sweep * i / 8;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * (r - 18), c + Offset(cos(a), sin(a)) * (r - 26), tick);
    }

    // aiguille
    final a = _start + _sweep * value;
    canvas.drawLine(c + Offset(cos(a), sin(a)) * (r - 64), c + Offset(cos(a), sin(a)) * (r - 14), Paint()
      ..color = const Color(0xFFFF4D4F)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _TachoPainter old) => old.value != value || old.accent != accent;
}

Future<void> showLevelUp(BuildContext context, {required Level oldLevel, required Level newLevel, required int oldXp, required int newXp}) {
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => LevelUpOverlay(
      oldLevel: oldLevel,
      newLevel: newLevel,
      oldXp: oldXp,
      newXp: newXp,
      onDismissed: () {
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  Overlay.of(context).insert(entry);
  return completer.future.then((_) => entry.remove());
}
