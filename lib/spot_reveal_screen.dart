import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/services/ads_service.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/services/wanted_service.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/spot_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
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
        pageBuilder: (_, _, _) => SpotRevealScreen(draft: draft, result: result),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  State<SpotRevealScreen> createState() => _SpotRevealScreenState();
}

class _SpotRevealScreenState extends State<SpotRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _revealed = false;
  bool _doubled = false;
  bool _adBusy = false;

  int get _bonus => min(widget.result.xpGained, 500);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AdsService.instance.preload();
  }

  /// Vidéo récompensée : l'XP de ce spot est doublée (une seule fois par spot).
  Future<void> _doubleXp() async {
    setState(() => _adBusy = true);
    final ok = await AdsService.instance.showRewarded();
    if (ok) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final carId = widget.result.carId;
      if (uid != null) {
        final ref = FirebaseFirestore.instance.collection('users').doc(uid);
        final done = await FirebaseFirestore.instance.runTransaction((tx) async {
          final d = (await tx.get(ref)).data() ?? {};
          if ((d['adDoubles'] as Map?)?[carId] == true) return false;
          tx.set(ref, {
            'totalXp': FieldValue.increment(_bonus),
            'xpByWeek': {weekKey(): FieldValue.increment(_bonus)},
            'adDoubles': {carId: true},
          }, SetOptions(merge: true));
          return true;
        }).catchError((_) => false);
        if (done && mounted) {
          HapticFeedback.heavyImpact();
          AudioService.instance.playSfx(SoundEffect.levelUp);
          setState(() => _doubled = true);
        }
      }
    }
    if (!ok && AdsService.instance.lastUnavailable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pas de vidéo disponible pour le moment, réessaie dans quelques minutes'))));
    }
    if (mounted) setState(() => _adBusy = false);
  }

  Rarity? get _rarity => widget.draft.isCatalogued ? widget.draft.rarity : null;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), _reveal);
  }

  void _reveal() {
    if (!mounted || _revealed) return;
    setState(() => _revealed = true);
    AudioService.instance.playSfx(SoundEffect.flip);
    _flip.forward();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = _rarity ?? Rarity.commune;
    final size = MediaQuery.sizeOf(context);
    final extra = AdsService.instance.available ? 64 : 0;
    final cardW = min(min(size.width - 72, 330.0), (size.height - 400 - extra) / 1.38);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _rarity == null ? tr('AJOUTÉE AU GARAGE') : tr('NOUVELLE CARTE'),
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
                                  .animate(target: _flip.value >= 1 ? 1 : 0)
                                  .shimmer(delay: 150.ms, duration: 1200.ms, color: rarity.color.withValues(alpha: 0.55), angle: 0.6)
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
                    builder: (_, v, _) => Text(tr('+{0} XP', [v]), style: AppText.display(22, color: Colors.white)),
                  ).animate().fadeIn(delay: 900.ms),
                if (widget.result.targetHit) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(tr('Cible atteinte ! Bonus inclus'), style: AppText.body(14, color: Colors.white, weight: FontWeight.w800)),
                    ],
                  ).animate().fadeIn(delay: 1000.ms).scale(begin: const Offset(0.8, 0.8)),
                ],
                if (widget.result.wantedHit) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gps_fixed_rounded, color: Color(0xFFFFC94D), size: 18),
                      const SizedBox(width: 6),
                      Text(tr('Avis de recherche : prime de {0} XP !', [Wanted.bounty]), style: AppText.body(14, color: const Color(0xFFFFC94D), weight: FontWeight.w800)),
                    ],
                  ).animate().fadeIn(delay: 1100.ms).scale(begin: const Offset(0.8, 0.8)),
                ],
                if (widget.result.newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in widget.result.newAchievements.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD447).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: const Color(0xFFFFD447).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFFD447)),
                                const SizedBox(width: 6),
                                Text(a.title, style: AppText.body(12.5, color: Colors.white, weight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        if (widget.result.newAchievements.length > 3)
                          Text('+${widget.result.newAchievements.length - 3}', style: AppText.mono(13, color: Colors.white60)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1100.ms),
                ],
                if (widget.result.photoFailed) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      tr('La photo n\'a pas pu être envoyée, le spot est enregistré sans.'),
                      textAlign: TextAlign.center,
                      style: AppText.body(13, color: Colors.white60),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                if (AdsService.instance.available && widget.result.xpGained > 0 && !_doubled) ...[
                  SizedBox(
                    width: cardW,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFC94D), side: const BorderSide(color: Color(0xFFFFC94D), width: 1.4)),
                      onPressed: _adBusy ? null : _doubleXp,
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: Text(tr('×2 XP avec une courte vidéo (+{0})', [_bonus])),
                    ),
                  ).animate().fadeIn(delay: 1100.ms),
                  const SizedBox(height: 10),
                ],
                if (_doubled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(tr('+{0} XP bonus encaissés !', [_bonus]), style: AppText.body(14, color: const Color(0xFFFFC94D), weight: FontWeight.w800)),
                  ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                SizedBox(
                  width: cardW,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('Continuer')),
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3, end: 0),
              ],
            ),
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
                        color: AppColors.panel,
                        child: Center(child: Text(draft.brandName.isEmpty ? '?' : draft.brandName[0], style: AppText.display(80, color: Colors.white24))),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brandHeader(draft.brandName, model).toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
                    const SizedBox(height: 3),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(cleanModelName(model), maxLines: 1, style: AppText.display(24))),
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
