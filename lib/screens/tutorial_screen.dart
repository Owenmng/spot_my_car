import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Tutoriel de première arrivée (passable). Revoyable depuis les réglages.
class TutorialScreen extends StatefulWidget {
  final String? pseudo;

  /// Page de départ (captures de contrôle uniquement).
  final int debugPage;
  const TutorialScreen({super.key, this.pseudo, this.debugPage = 0});

  static String _key() => 'tutorial_done_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}';

  static Future<bool> isDone() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key()) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markDone() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key(), true);
    } catch (_) {}
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final _pc = PageController(initialPage: widget.debugPage);
  late int _page = widget.debugPage;
  static const _count = 6;

  void _next() {
    HapticFeedback.selectionClick();
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    if (_page == _count - 1) {
      _finish(false);
      return;
    }
    _pc.nextPage(duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
  }

  Future<void> _finish(bool skipped) async {
    await TutorialScreen.markDone();
    BackendService.instance.event(skipped ? 'tutorial.skip' : 'tutorial.done', 'page $_page');
    if (!skipped) AudioService.instance.playSfx(SoundEffect.succesPrincipal);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final pad = MediaQuery.paddingOf(context);
    final last = _page == _count - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          _pc.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
        } else {
          _finish(true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07070A),
        body: Stack(
          children: [
            Positioned.fill(child: _Backdrop(page: _pc, accent: accent)),
            PageView(
              controller: _pc,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _page = i);
              },
              children: [
                _Page(active: _page == 0, art: (t) => _WelcomeArt(t: t, accent: accent), kicker: tr('BIENVENUE'),
                    title: widget.pseudo?.isNotEmpty == true ? tr('Salut {0}, ton garage t\'attend', [widget.pseudo!]) : tr('Ton garage t\'attend'),
                    body: tr('En 30 secondes, découvre comment devenir une légende du carspotting.')),
                _Page(active: _page == 1, art: (t) => _SpotArt(t: t, accent: accent), kicker: tr('1 · SPOTTE'),
                    title: tr('Une photo, l\'IA s\'occupe du reste'),
                    body: tr('Croise une belle voiture, prends-la en photo : marque et modèle sont reconnus en une seconde. Pas de photo ? Ajoute-la à la main.')),
                _Page(active: _page == 2, art: (t) => _CardsArt(t: t), kicker: tr('2 · COLLECTIONNE'),
                    title: tr('Chaque spot devient une carte'),
                    body: tr('De Commune à Mythique : plus la voiture est rare, plus elle rapporte d\'XP. Plus de 6 000 modèles à débloquer.')),
                _Page(active: _page == 3, art: (t) => _LevelArt(t: t, accent: accent), kicker: tr('3 · PROGRESSE'),
                    title: tr('De Rookie à Mythe vivant'),
                    body: tr('Gagne de l\'XP, relève le défi du jour, garde ta série et débloque des dizaines de succès.')),
                _Page(active: _page == 4, art: (t) => _DuelArt(t: t, accent: accent), kicker: tr('4 · DÉFIE'),
                    title: tr('Tes amis, tes rivaux'),
                    body: tr('Ajoute tes amis avec leur ID, lance des duels et des blind tests. Qui reconnaîtra le plus de voitures ?')),
                _Page(active: _page == 5, art: (t) => _ReadyArt(t: t, accent: accent), kicker: tr('C\'EST PARTI'),
                    title: tr('Prêt à spotter ?'),
                    body: tr('Le bouton photo au centre de la barre du bas, c\'est ton meilleur ami. Bonne chasse !')),
              ],
            ),
            // Barre du haut
            Positioned(
              top: pad.top + 8,
              left: 16,
              right: 8,
              child: Row(
                children: [
                  const AppLogo(size: 34, glow: false),
                  const SizedBox(width: 10),
                  Text('SPOT MY CAR', style: AppText.display(17, color: Colors.white)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: last ? null : () => _finish(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: Text(tr('Passer')),
                    ),
                  ),
                ],
              ),
            ),
            // Bas : points + bouton
            Positioned(
              left: 24,
              right: 24,
              bottom: pad.bottom + 22,
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? accent : Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: last ? 190 : 140,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: last ? accent : Colors.white,
                        foregroundColor: last ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(last ? tr('Démarrer') : tr('Suivant'), style: AppText.body(16, weight: FontWeight.w800, color: last ? Colors.white : Colors.black)),
                          const SizedBox(width: 8),
                          Icon(last ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
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

/// Fond : halo de la couleur de l'appli qui glisse avec les pages + lignes de route.
class _Backdrop extends StatelessWidget {
  final PageController page;
  final Color accent;
  const _Backdrop({required this.page, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: page,
      builder: (context, _) {
        final p = page.hasClients && page.position.haveDimensions ? page.page ?? 0 : 0.0;
        return CustomPaint(painter: _BackdropPainter(p, accent));
      },
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double p;
  final Color accent;
  _BackdropPainter(this.p, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (0.5 + 0.35 * sin(p * 1.3));
    final cy = size.height * (0.32 + 0.05 * cos(p));
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.95,
      Paint()
        ..shader = RadialGradient(colors: [accent.withValues(alpha: 0.30), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.95)),
    );
    // Lignes de grille en perspective, en bas
    final vanish = Offset(size.width / 2, size.height * 0.52);
    final line = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..strokeWidth = 1.2;
    for (var i = -8; i <= 8; i++) {
      canvas.drawLine(vanish, Offset(size.width / 2 + i * size.width * 0.22, size.height), line);
    }
    final shift = (p * 0.35) % 1.0;
    for (var k = 0; k < 9; k++) {
      final f = ((k + shift) / 9);
      final y = vanish.dy + (size.height - vanish.dy) * f * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line..color = accent.withValues(alpha: 0.05 + 0.08 * f));
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.p != p || old.accent != accent;
}

/// Une page : illustration animée + textes. L'animation repart à chaque arrivée sur la page.
class _Page extends StatefulWidget {
  final bool active;
  final Widget Function(Animation<double> t) art;
  final String kicker;
  final String title;
  final String body;
  const _Page({required this.active, required this.art, required this.kicker, required this.title, required this.body});

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _Page old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve c = Curves.easeOutCubic]) => CurvedAnimation(parent: _c, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final h = MediaQuery.sizeOf(context).height;
    final text = _iv(0.15, 0.55);
    return Padding(
      padding: EdgeInsets.fromLTRB(26, pad.top + 64, 26, pad.bottom + 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: SizedBox(height: min(h * 0.46, 380), width: double.infinity, child: widget.art(_c)))),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: text,
            builder: (context, child) => Opacity(opacity: text.value, child: Transform.translate(offset: Offset(0, 24 * (1 - text.value)), child: child)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.kicker, style: AppText.label(12, color: Theme.of(context).colorScheme.primary).copyWith(letterSpacing: 3)),
                const SizedBox(height: 10),
                Text(widget.title, style: AppText.display(34, color: Colors.white)),
                const SizedBox(height: 12),
                Text(widget.body, style: AppText.body(15.5, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _out(double x) => 1 - pow(1 - x, 3).toDouble();
double _back(double x) {
  const c = 1.7;
  return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2);
}

String? _img(String id) {
  final m = DataManager.instance.modelById(id);
  return m?['imageUrl'] as String?;
}

class _WelcomeArt extends StatelessWidget {
  final Animation<double> t;
  final Color accent;
  const _WelcomeArt({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        final s = _back(_seg(v, 0, 0.35));
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: (0.35 - i * 0.1) * _seg(v, 0.1 + i * 0.08, 0.5),
                child: Container(
                  width: 170.0 + i * 70 + 20 * sin(v * pi * 2 + i),
                  height: 170.0 + i * 70 + 20 * sin(v * pi * 2 + i),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.5)),
                ),
              ),
            Transform.scale(
              scale: s,
              child: Container(
                decoration: BoxDecoration(boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 60, spreadRadius: 4)], borderRadius: BorderRadius.circular(40)),
                child: const AppLogo(size: 150, glow: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotArt extends StatefulWidget {
  final Animation<double> t;
  final Color accent;
  const _SpotArt({required this.t, required this.accent});
  @override
  State<_SpotArt> createState() => _SpotArtState();
}

class _SpotArtState extends State<_SpotArt> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.t, _loop]),
      builder: (context, _) {
        final v = widget.t.value;
        final lock = _out(_seg(v, 0.1, 0.45));
        final found = _seg(v, 0.5, 0.7);
        return Center(
          child: AspectRatio(
            aspectRatio: 0.78,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.35), blurRadius: 40)],
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                final target = Rect.fromLTWH(w * 0.08, h * 0.30, w * 0.84, h * 0.40);
                final start = Rect.fromLTWH(10, 10, w - 20, h - 20);
                final r = Rect.lerp(start, target, lock)!;
                final scanY = r.top + r.height * ((sin(_loop.value * pi * 2) + 1) / 2);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.15), BlendMode.darken),
                        child: CarImage(urls: [_img('porsche_911_turbo_s'), _img('ferrari_f40')], brandName: 'Porsche', modelName: '911', fit: BoxFit.cover, borderRadius: BorderRadius.zero),
                      ),
                    ),
                    Positioned.fromRect(rect: r, child: CustomPaint(painter: _Brackets(found > 0 ? Color.lerp(Colors.white, AppColors.success, found)! : Colors.white))),
                    if (lock > 0.99 && found < 1)
                      Positioned(left: r.left + 8, right: w - r.right + 8, top: scanY, child: Container(height: 3, decoration: BoxDecoration(color: widget.accent, boxShadow: [BoxShadow(color: widget.accent, blurRadius: 12)]))),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Opacity(
                        opacity: found,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - _out(found))),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(color: const Color(0xEE111116), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded, color: AppColors.success, size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Porsche 911 Turbo S', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, weight: FontWeight.w800, color: Colors.white)),
                                      Text(tr('Reconnue à {0} %', [98]), style: AppText.body(12, color: Colors.white60)),
                                    ],
                                  ),
                                ),
                                RarityBadge(rarity: Rarity.epique, compact: true, onDark: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                          child: Text(found > 0 ? tr('IDENTIFIÉE') : tr('ANALYSE IA…'), style: AppText.label(11, color: found > 0 ? AppColors.success : Colors.white)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _Brackets extends CustomPainter {
  final Color color;
  _Brackets(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    for (final c in [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)]) {
      final dx = c.dx == 0 ? 1.0 : -1.0, dy = c.dy == 0 ? 1.0 : -1.0;
      canvas.drawPath(Path()
        ..moveTo(c.dx, c.dy + dy * l)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + dx * l, c.dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Brackets old) => old.color != color;
}

class _MiniCard extends StatelessWidget {
  final Rarity rarity;
  final String id;
  final String name;
  const _MiniCard({required this.rarity, required this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 214,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: rarity.frame, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: rarity.color.withValues(alpha: 0.45), blurRadius: 24)],
      ),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF111116), borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RarityBadge(rarity: rarity, compact: true, onDark: true),
            const Spacer(),
            SizedBox(height: 82, width: double.infinity, child: CarImage(urls: [_img(id)], brandName: name, fit: BoxFit.cover, borderRadius: BorderRadius.circular(10))),
            const Spacer(),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(17, color: Colors.white)),
            const SizedBox(height: 4),
            Text('+${rarity.xp} XP', style: AppText.mono(11, color: rarity.color)),
          ],
        ),
      ),
    );
  }
}

class _CardsArt extends StatelessWidget {
  final Animation<double> t;
  const _CardsArt({required this.t});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (Rarity.peuCommune, 'peugeot_208_gti', 'Peugeot 208 GTi', -1.0),
      (Rarity.legendaire, 'ferrari_f40', 'Ferrari F40', 0.0),
      (Rarity.rare, 'bmw_m3', 'BMW M3', 1.0),
    ];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final (i, c) in [cards[0], cards[2], cards[1]].indexed)
              Builder(builder: (context) {
                final k = _back(_seg(v, 0.05 + i * 0.1, 0.45 + i * 0.1));
                final side = c.$4;
                final float = sin(v * pi * 2 + i) * 4;
                return Transform.translate(
                  offset: Offset(side * 95 * k, (side == 0 ? -10 : 18) * k + float + 200 * (1 - k)),
                  child: Transform.rotate(
                    angle: side * 0.16 * k,
                    child: Transform.scale(scale: side == 0 ? 1.08 : 0.94, child: Opacity(opacity: k.clamp(0.0, 1.0), child: _MiniCard(rarity: c.$1, id: c.$2, name: c.$3))),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _LevelArt extends StatelessWidget {
  final Animation<double> t;
  final Color accent;
  const _LevelArt({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    const names = ['Rookie', 'Spotter', 'Curieux', 'Amateur éclairé', 'Passionné', 'Connaisseur'];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        final p = _seg(v, 0.05, 0.75);
        final lv = (p * (names.length - 1)).floor();
        final frac = p >= 1 ? 1.0 : p * (names.length - 1) - lv;
        final medals = [Icons.photo_camera_rounded, Icons.local_fire_department_rounded, Icons.emoji_events_rounded];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: 1, strokeWidth: 14, color: Colors.white10)),
                  SizedBox.expand(child: CircularProgressIndicator(value: frac, strokeWidth: 14, strokeCap: StrokeCap.round, color: accent)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('NIVEAU'), style: AppText.label(11, color: Colors.white54).copyWith(letterSpacing: 3)),
                    Text('${lv + 1}', style: AppText.display(64, color: Colors.white)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(tr(names[lv]), style: AppText.display(26, color: p >= 1 ? const Color(0xFFFFC94D) : Colors.white)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(builder: (context) {
                    final q = _back(_seg(v, 0.55 + i * 0.1, 0.8 + i * 0.1));
                    return Transform.scale(
                      scale: q.clamp(0.0, 1.3),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [Color(0xFFFFF0B8), Color(0xFFF5B301), Color(0xFF8A5A00)], center: Alignment(-0.3, -0.4)),
                          boxShadow: [BoxShadow(color: const Color(0xFFF5B301).withValues(alpha: 0.5), blurRadius: 18)],
                        ),
                        child: Icon(medals[i], color: const Color(0xFF5A3A00), size: 28),
                      ),
                    );
                  }),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DuelArt extends StatelessWidget {
  final Animation<double> t;
  final Color accent;
  const _DuelArt({required this.t, required this.accent});

  Widget _player(String name, String initial, Color c, int score) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 24)]),
            child: Text(initial, style: AppText.display(34, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(name, style: AppText.body(14, weight: FontWeight.w800, color: Colors.white)),
          Text('$score pts', style: AppText.mono(13, color: c)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        final inL = _out(_seg(v, 0.05, 0.35)), inR = _out(_seg(v, 0.12, 0.42));
        final vs = _back(_seg(v, 0.35, 0.55));
        final reveal = _seg(v, 0.65, 0.8);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Transform.translate(offset: Offset(-120 * (1 - inL), 0), child: Opacity(opacity: inL, child: _player(tr('Toi'), 'T', accent, reveal > 0 ? 140 : 120))),
                Transform.scale(scale: vs.clamp(0.0, 1.4), child: Text('VS', style: AppText.display(40, color: Colors.white))),
                Transform.translate(offset: Offset(120 * (1 - inR), 0), child: Opacity(opacity: inR, child: _player('Max', 'M', const Color(0xFF2F6BFF), 95))),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: const Color(0xFF15151B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix([
                      reveal, 0, 0, 0, 0,
                      0, reveal, 0, 0, 0,
                      0, 0, reveal, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: CarImage(urls: [_img('nissan_gt-r'), _img('audi_r8')], brandName: 'Nissan', fit: BoxFit.cover, borderRadius: BorderRadius.zero),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: reveal > 0 ? AppColors.success : Colors.black87, borderRadius: BorderRadius.circular(99)),
                      child: Text(reveal > 0 ? 'Nissan GT-R · +20' : tr('Quelle voiture ?'), style: AppText.body(12.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReadyArt extends StatelessWidget {
  final Animation<double> t;
  final Color accent;
  const _ReadyArt({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tips = [
      (Icons.lock_outline_rounded, tr('Tes photos et les plaques restent privées')),
      (Icons.wb_sunny_outlined, tr('Un défi du jour t\'attend chaque matin')),
      (Icons.pin_rounded, tr('Plaque sans modèle ? Utilise l\'assistant plaque')),
      (Icons.settings_suggest_outlined, tr('Musique, thème, langue : tout se règle dans ton profil')),
    ];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: _back(_seg(v, 0, 0.3)).clamp(0.0, 1.3),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 40)]),
                child: Icon(Icons.photo_camera_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 46),
              ),
            ),
            const SizedBox(height: 24),
            for (final (i, tip) in tips.indexed)
              Opacity(
                opacity: _seg(v, 0.2 + i * 0.1, 0.4 + i * 0.1),
                child: Transform.translate(
                  offset: Offset(30 * (1 - _out(_seg(v, 0.2 + i * 0.1, 0.4 + i * 0.1))), 0),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                    child: Row(children: [
                      Icon(tip.$1, color: accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tip.$2, style: AppText.body(13.5, color: Colors.white, weight: FontWeight.w600))),
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
