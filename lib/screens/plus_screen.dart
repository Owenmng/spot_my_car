import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/shared/app_constants.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page de l'abonnement Spot My Car+.
class PlusScreen extends StatefulWidget {
  final bool demo;
  const PlusScreen({super.key, this.demo = false});

  static const gold = Color(0xFFFFC94D);

  static Future<void> open(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlusScreen()));

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  String _selected = PlusService.yearlyId;
  bool _gifting = false;
  final plus = PlusService.instance;

  @override
  void initState() {
    super.initState();
    if (!widget.demo) plus.loadProducts();
    plus.addListener(_changed);
  }

  @override
  void dispose() {
    plus.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String _price(String id, String fallback) => plus.products[id]?.price ?? fallback;

  @override
  Widget build(BuildContext context) {
    const gold = PlusScreen.gold;
    final member = plus.isPlus;
    final perks = [
      (Icons.key_rounded, tr('Contact du jour doublé'), tr('Deux fois plus d\'XP à chaque démarrage, sans pub')),
      (Icons.gps_fixed_rounded, tr('Primes doublées'), tr('+300 XP sur chaque avis de recherche')),
      (Icons.palette_rounded, tr('Thèmes exclusifs'), tr('Nuit dorée, Abysse et 5 couleurs réservées')),
      (Icons.workspace_premium_rounded, tr('Badge PLUS doré'), tr('Bien visible à côté de ton pseudo')),
      (Icons.block_rounded, tr('Zéro pub'), tr('Aucune vidéo, jamais')),
      (Icons.favorite_rounded, tr('Soutiens un dev indépendant'), tr('Tu finances les prochaines fonctionnalités')),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GoldGlow()))),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppLogo(size: 44),
                            const SizedBox(width: 10),
                            Text('SPOT MY CAR', style: AppText.display(24, color: Colors.white).copyWith(letterSpacing: 1.5)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFE08A), gold, Color(0xFFE59A1A)]), borderRadius: BorderRadius.circular(8)),
                              child: Text('+', style: AppText.display(24, color: Colors.black)),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                      const SizedBox(height: 14),
                      Text(
                        member ? tr('Tu es membre Spot My Car+') : tr('Passe la vitesse supérieure'),
                        textAlign: TextAlign.center,
                        style: AppText.display(30, color: Colors.white),
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 6),
                      Text(
                        member && plus.until != null
                            ? tr('Actif jusqu\'au {0}', [MaterialLocalizations.of(context).formatMediumDate(plus.until!)])
                            : tr('Plus d\'XP, plus de style, zéro pub.'),
                        textAlign: TextAlign.center,
                        style: AppText.body(14.5, color: Colors.white70, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 22),
                      for (final (i, p) in perks.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: gold.withValues(alpha: 0.35))),
                                child: Icon(p.$1, color: gold, size: 21),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.$2, style: AppText.body(15, color: Colors.white, weight: FontWeight.w800)),
                                    Text(p.$3, style: AppText.body(12.5, color: Colors.white60)),
                                  ],
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: (160 + i * 60).ms).slideX(begin: 0.06),
                        ),
                      if (!member) ...[
                        const SizedBox(height: 14),
                        _Plan(
                          selected: _selected == PlusService.yearlyId,
                          title: tr('Annuel'),
                          price: _price(PlusService.yearlyId, '19,99 €'),
                          per: tr('par an'),
                          badge: tr('2 MOIS OFFERTS'),
                          note: tr('Soit environ 1,67 € par mois'),
                          onTap: () => setState(() => _selected = PlusService.yearlyId),
                        ),
                        const SizedBox(height: 10),
                        _Plan(
                          selected: _selected == PlusService.monthlyId,
                          title: tr('Mensuel'),
                          price: _price(PlusService.monthlyId, '2,99 €'),
                          per: tr('par mois'),
                          onTap: () => setState(() => _selected = PlusService.monthlyId),
                        ),
                      ],
                      if (plus.lastError != null && plus.lastError != 'unavailable') ...[
                        const SizedBox(height: 10),
                        Text(tr('L\'achat n\'a pas abouti. Réessaie dans un instant.'), textAlign: TextAlign.center, style: AppText.body(12.5, color: AppColors.danger)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(colors: [Color(0xFFFFE08A), gold, Color(0xFFE59A1A)]),
                            boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 6))],
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            onPressed: plus.busy || _gifting
                                ? null
                                : member
                                    ? () => launchUrl(Uri.parse('https://play.google.com/store/account/subscriptions?package=${AppConstants.packageName}'), mode: LaunchMode.externalApplication)
                                    : _buy,
                            child: plus.busy || _gifting
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                                : Text(member ? tr('GÉRER MON ABONNEMENT') : tr('DEVENIR MEMBRE'), style: AppText.label(15, color: Colors.black).copyWith(letterSpacing: 1.8)),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(delay: 1500.ms, duration: 1400.ms, color: Colors.white54),
                      const SizedBox(height: 6),
                      if (!member)
                        TextButton(
                          onPressed: plus.busy ? null : plus.restore,
                          child: Text(tr('Restaurer mes achats'), style: AppText.body(13, color: Colors.white60, weight: FontWeight.w700)),
                        ),
                      Text(
                        tr('Renouvellement automatique, résiliable à tout moment dans Google Play. Paiement débité sur ton compte Google.'),
                        textAlign: TextAlign.center,
                        style: AppText.body(10.5, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy() async {
    HapticFeedback.mediumImpact();
    if (widget.demo) return;
    // Le patron ne paie pas : on lui offre le Pro directement.
    if (RemoteConfig.instance.isAdmin) return _bossGift();
    if (kIsWeb) return;
    if (plus.products.isEmpty) await plus.loadProducts();
    if (!mounted) return;
    if (!plus.products.containsKey(_selected)) {
      showAppSnack(context, tr('L\'abonnement n\'est pas encore disponible. Reviens très vite !'), icon: Icons.hourglass_top_rounded);
      return;
    }
    await plus.buy(_selected);
  }

  Future<void> _bossGift() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _gifting = true);
    try {
      await BackendService.instance.call('admin.plus.set', {'uid': uid, 'days': -1});
    } catch (_) {
      if (mounted) {
        setState(() => _gifting = false);
        showAppSnack(context, tr('Une erreur est survenue. Réessaie dans un instant.'), icon: Icons.error_outline_rounded);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _gifting = false);
    HapticFeedback.heavyImpact();
    AudioService.instance.playSfx(SoundEffect.levelUp);
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111116),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: PlusScreen.gold, width: 1.5)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 54)).animate().scale(begin: const Offset(0.3, 0.3), curve: Curves.elasticOut, duration: 900.ms),
              const SizedBox(height: 10),
              Text(tr('Gratuit pour toi, patron'), textAlign: TextAlign.center, style: AppText.display(26, color: Colors.white)),
              const SizedBox(height: 8),
              Text(tr('Spot My Car+ est activé à vie sur ton compte. Profite de toutes les fonctionnalités Pro.'),
                  textAlign: TextAlign.center, style: AppText.body(14, color: Colors.white70, weight: FontWeight.w600)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: PlusScreen.gold, foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('DÉCOUVRIR'), style: AppText.label(14, color: Colors.black).copyWith(letterSpacing: 1.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  final bool selected;
  final String title;
  final String price;
  final String per;
  final String? badge;
  final String? note;
  final VoidCallback onTap;
  const _Plan({required this.selected, required this.title, required this.price, required this.per, required this.onTap, this.badge, this.note});

  @override
  Widget build(BuildContext context) {
    const gold = PlusScreen.gold;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? gold.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? gold : Colors.white12, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? gold : Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppText.body(16, color: Colors.white, weight: FontWeight.w800)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
                          child: Text(badge!, style: AppText.label(9, color: Colors.black)),
                        ),
                      ],
                    ],
                  ),
                  if (note != null) Text(note!, style: AppText.body(12, color: Colors.white60)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: AppText.display(20, color: Colors.white)),
                Text(per, style: AppText.body(11, color: Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldGlow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.08);
    canvas.drawCircle(
      c,
      size.width * 0.9,
      Paint()..shader = RadialGradient(colors: [PlusScreen.gold.withValues(alpha: 0.22), Colors.transparent]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.9)),
    );
    final p = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.15 + i * 0.09);
      canvas.drawLine(Offset(0, y + sin(i) * 20), Offset(size.width, y - 40), p..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
