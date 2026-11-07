import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/spot_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Moment « ouverture de pochette » après chaque spot : la carte se retourne,
/// la rareté se dévoile, les XP défilent.
class SpotRevealScreen extends StatefulWidget {
  final SpotDraft draft;
  final SpotSaveResult result;

  const SpotRevealScreen({super.key, required this.draft, required this.result});

  static Route<void> route({required SpotDraft draft, required SpotSaveResult result}) => PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => SpotRevealScreen(draft: draft, result: result),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  State<SpotRevealScreen> createState() => _SpotRevealScreenState();
}

class _SpotRevealScreenState extends State<SpotRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 1600));
  bool _revealed = false;

  Rarity? get _rarity => widget.draft.isCatalogued ? widget.draft.rarity : null;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), _reveal);
  }

  void _reveal() {
    if (!mounted || _revealed) return;
    setState(() => _revealed = true);
    _flip.forward();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if ((_rarity?.index ?? 0) >= Rarity.rare.index) _confetti.play();
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = _rarity ?? Rarity.commune;
    final size = MediaQuery.sizeOf(context);
    final cardW = min(size.width - 72, 330.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 28,
                gravity: 0.25,
                colors: [...rarity.frame, Colors.white],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _rarity == null ? 'AJOUTÉE AU GARAGE' : 'NOUVELLE CARTE',
                  style: AppText.label(13, color: Colors.white60),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _reveal,
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, _) {
                      final t = Curves.easeInOutBack.transform(_flip.value.clamp(0.0, 1.0));
                      final angle = pi * (1 - t);
                      final showFront = angle < pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle),
                        child: SizedBox(
                          width: cardW,
                          height: cardW * 1.38,
                          child: showFront
                              ? _Front(draft: widget.draft, rarity: _rarity)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: _Back(rarity: rarity),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                if (_rarity != null)
                  Text(rarity.label.toUpperCase(), style: AppText.display(28, color: rarity.color))
                      .animate(target: _revealed ? 1 : 0)
                      .fadeIn(delay: 600.ms)
                      .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
                const SizedBox(height: 8),
                if (widget.result.xpGained > 0)
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _revealed ? widget.result.xpGained : 0),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text('+$v XP', style: AppText.display(22, color: Colors.white)),
                  ).animate().fadeIn(delay: 900.ms),
                if (widget.result.photoFailed) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "La photo n'a pas pu être envoyée, le spot est enregistré sans.",
                      textAlign: TextAlign.center,
                      style: AppText.body(13, color: Colors.white60),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: cardW,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Continuer'),
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3, end: 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  final Rarity rarity;
  const _Back({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(colors: [Color(0xFF23232B), Color(0xFF0E0E12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_filled_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 8),
            Text('SPOTMYCAR', style: AppText.label(14, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  final SpotDraft draft;
  final Rarity? rarity;

  const _Front({required this.draft, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final r = rarity ?? Rarity.commune;
    final model = draft.modelName;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(colors: r.frame, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl - 4),
        child: ColoredBox(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: draft.photo != null
                    ? Image.memory(draft.photo!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: AppColors.ink,
                        child: Center(child: Text(draft.brandName.isEmpty ? '?' : draft.brandName[0], style: AppText.display(80, color: Colors.white24))),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.brandName.toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
                    const SizedBox(height: 3),
                    Text(model, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(24)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: PlateBadge(plate: draft.plate, countryCode: draft.countryCode, scale: 0.8),
                          ),
                        ),
                        const Spacer(),
                        if (rarity != null) RarityBadge(rarity: rarity!, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
