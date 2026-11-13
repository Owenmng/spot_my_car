import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/screens/plus_screen.dart';
import 'package:spot_my_car/services/ads_service.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Coffre du jour : une récompense à la première ouverture de la journée,
/// qui grossit avec la série de jours consécutifs (cycle de 7 jours).
class DailyChest {
  DailyChest._();

  static const rewards = [20, 30, 40, 60, 80, 100, 200];

  static int baseFor(int streak) => rewards[(max(1, streak) - 1) % rewards.length];

  /// Les membres Spot My Car+ reçoivent le double.
  static int rewardFor(int streak) => baseFor(streak) * (PlusService.instance.isPlus ? 2 : 1);

  /// Série que le joueur aurait en ouvrant aujourd'hui, ou null si déjà ouvert.
  static int? pendingStreak(Map<String, dynamic> userData, [DateTime? now]) {
    final d = now ?? DateTime.now();
    final chest = userData['chest'] as Map?;
    final last = chest?['last'] as String?;
    if (last == DailyChallenge.todayKey(d)) return null;
    final yesterday = DailyChallenge.todayKey(d.subtract(const Duration(days: 1)));
    return last == yesterday ? ((chest?['streak'] as num?)?.toInt() ?? 0) + 1 : 1;
  }

  static Future<void> maybeShow(BuildContext context) async {
    if (!RemoteConfig.instance.feature('dailyChest')) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Map<String, dynamic> data;
    try {
      data = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data() ?? {};
    } catch (_) {
      return;
    }
    final streak = pendingStreak(data);
    if (streak == null || !context.mounted) return;
    await show(context, streak: streak);
  }

  static Future<void> show(BuildContext context, {required int streak, bool demo = false}) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => DailyChestScreen(streak: streak, demo: demo),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// Encaisse la récompense (une seule fois par jour, vérifié dans la transaction).
  static Future<bool> claim(int streak) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = DailyChallenge.todayKey();
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final s = pendingStreak(data);
      if (s == null) return false;
      final reward = rewardFor(s);
      tx.set(ref, {
        'totalXp': FieldValue.increment(reward),
        'xpByWeek': {weekKey(): FieldValue.increment(reward)},
        'chest': {'last': today, 'streak': s, 'best': max(s, (data['chest']?['best'] as num?)?.toInt() ?? 0)},
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Après une vidéo récompensée : la récompense du jour est doublée (une fois).
  static Future<bool> doubleUp(int streak) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = DailyChallenge.todayKey();
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final chest = (await tx.get(ref)).data()?['chest'] as Map?;
      if (chest?['last'] != today || chest?['doubled'] == today) return false;
      final bonus = baseFor(streak);
      tx.set(ref, {
        'totalXp': FieldValue.increment(bonus),
        'xpByWeek': {weekKey(): FieldValue.increment(bonus)},
        'chest': {'doubled': today},
      }, SetOptions(merge: true));
      return true;
    });
  }
}

class DailyChestScreen extends StatefulWidget {
  final int streak;
  final bool demo;
  const DailyChestScreen({super.key, required this.streak, this.demo = false});

  @override
  State<DailyChestScreen> createState() => _DailyChestScreenState();
}

class _DailyChestScreenState extends State<DailyChestScreen> with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFC94D);
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _opened = false;
  bool _busy = false;
  bool _doubled = false;
  late final int _baseReward = DailyChest.rewardFor(widget.streak);

  int get _reward => _baseReward + (_doubled ? DailyChest.baseFor(widget.streak) : 0);

  @override
  void initState() {
    super.initState();
    if (!widget.demo) AdsService.instance.preload();
  }

  Future<void> _watchToDouble() async {
    setState(() => _busy = true);
    final ok = await AdsService.instance.showRewarded();
    if (ok && await DailyChest.doubleUp(widget.streak).catchError((_) => false)) {
      HapticFeedback.heavyImpact();
      AudioService.instance.playSfx(SoundEffect.levelUp);
      if (mounted) setState(() => _doubled = true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _shake.dispose();
    _open.dispose();
    super.dispose();
  }

  Future<void> _tapChest() async {
    if (_opened || _busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    AudioService.instance.playSfx(SoundEffect.flip);
    final claim = widget.demo ? Future.value(true) : DailyChest.claim(widget.streak).catchError((_) => false);
    await _shake.forward(from: 0);
    HapticFeedback.heavyImpact();
    AudioService.instance.playSfx(SoundEffect.succesPrincipal);
    setState(() => _opened = true);
    await _open.forward(from: 0);
    await claim;
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cycleDay = (widget.streak - 1) % 7; // 0..6
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.86),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text(tr('COFFRE DU JOUR'), style: AppText.label(12, color: _gold).copyWith(letterSpacing: 3)).animate().fadeIn(),
              const SizedBox(height: 6),
              Text(
                widget.streak > 1 ? tr('{0} jours d\'affilée 🔥', [widget.streak]) : tr('Reviens chaque jour, il grossit !'),
                textAlign: TextAlign.center,
                style: AppText.display(26, color: Colors.white),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),
              const SizedBox(height: 22),
              // Les 7 jours du cycle
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _DayPip(
                          day: i + 1,
                          xp: DailyChest.rewards[i],
                          state: i < cycleDay ? 1 : (i == cycleDay ? (_opened ? 1 : 2) : 0),
                          big: i == 6,
                          accent: accent,
                        ).animate().fadeIn(delay: (150 + i * 50).ms).slideY(begin: 0.4),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _tapChest,
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_shake, _open]),
                    builder: (context, _) {
                      final t = _shake.value;
                      final wobble = sin(t * pi * 10) * (1 - t) * 0.09;
                      final o = Curves.easeOutBack.transform(_open.value.clamp(0.0, 1.0));
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Halo
                          Opacity(
                            opacity: _opened ? _open.value : 0.35,
                            child: Transform.scale(
                              scale: 0.6 + (_opened ? _open.value * 0.8 : 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [_gold.withValues(alpha: 0.55), accent.withValues(alpha: 0.18), Colors.transparent]),
                                ),
                              ),
                            ),
                          ),
                          if (_opened) Positioned.fill(child: CustomPaint(painter: _Rays(_open.value, _gold))),
                          Transform.rotate(
                            angle: wobble,
                            child: SizedBox(
                              width: 170,
                              height: 150,
                              child: CustomPaint(painter: _ChestPainter(open: o, accent: accent, gold: _gold)),
                            ),
                          ),
                          if (_opened)
                            Positioned(
                              top: 6,
                              child: Opacity(
                                opacity: _open.value.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - _open.value)),
                                  child: TweenAnimationBuilder<int>(
                                    tween: IntTween(begin: _doubled ? _baseReward : 0, end: _reward),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, _) => Text('+$v XP', style: AppText.display(40, color: Colors.white).copyWith(shadows: [Shadow(color: _gold.withValues(alpha: 0.8), blurRadius: 24)])),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1100.ms, curve: Curves.easeInOut),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _opened
                    ? Column(
                        key: const ValueKey('open'),
                        children: [
                          Text(
                            cycleDay == 6 ? tr('Jackpot de la semaine ! Le cycle recommence demain.') : tr('Demain : +{0} XP si tu reviens', [DailyChest.rewards[(cycleDay + 1) % 7]]),
                            textAlign: TextAlign.center,
                            style: AppText.body(14, color: Colors.white70, weight: FontWeight.w600),
                          ),
                          if (PlusService.instance.isPlus) ...[
                            const SizedBox(height: 8),
                            Text(tr('Bonus Spot My Car+ : récompense doublée'), style: AppText.body(13, color: _gold, weight: FontWeight.w800)),
                          ] else if (!widget.demo && AdsService.instance.available && !_doubled) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: _gold, side: const BorderSide(color: _gold, width: 1.4)),
                                onPressed: _busy ? null : _watchToDouble,
                                icon: const Icon(Icons.play_circle_fill_rounded),
                                label: Text(tr('Doubler avec une courte vidéo (+{0} XP)', [DailyChest.baseFor(widget.streak)])),
                              ),
                            ),
                          ],
                          if (!PlusService.instance.isPlus && PlusService.instance.enabled && !widget.demo)
                            TextButton.icon(
                              onPressed: () => PlusScreen.open(context),
                              icon: const Icon(Icons.workspace_premium_rounded, color: _gold, size: 18),
                              label: Text(tr('Avec Spot My Car+, ce coffre est doublé chaque jour'), style: AppText.body(12.5, color: _gold, weight: FontWeight.w700)),
                            ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _busy ? null : () => Navigator.pop(context),
                              child: Text(tr('ENCAISSER'), style: AppText.label(15, color: Colors.white).copyWith(letterSpacing: 2)),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        tr('Touche le coffre pour l\'ouvrir'),
                        key: const ValueKey('closed'),
                        style: AppText.body(15, color: Colors.white70, weight: FontWeight.w700),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1, duration: 900.ms),
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPip extends StatelessWidget {
  final int day;
  final int xp;
  final int state; // 0 à venir, 1 fait, 2 aujourd'hui
  final bool big;
  final Color accent;
  const _DayPip({required this.day, required this.xp, required this.state, required this.big, required this.accent});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC94D);
    final today = state == 2;
    final done = state == 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: today ? gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: done ? 0.10 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: today ? gold : (big ? gold.withValues(alpha: 0.4) : Colors.white12), width: today ? 1.6 : 1),
      ),
      child: Column(
        children: [
          Text(tr('J{0}', [day]), style: AppText.label(9.5, color: today ? gold : Colors.white54)),
          const SizedBox(height: 4),
          Icon(
            done ? Icons.check_circle_rounded : (big ? Icons.workspace_premium_rounded : Icons.inventory_2_rounded),
            size: 18,
            color: done ? AppColors.success : (today || big ? gold : Colors.white38),
          ),
          const SizedBox(height: 4),
          FittedBox(child: Text('$xp', style: AppText.mono(10.5, color: today ? Colors.white : Colors.white60))),
        ],
      ),
    );
  }
}

/// Coffre dessiné à la main : caisse sombre cerclée d'or, couvercle qui bascule.
class _ChestPainter extends CustomPainter {
  final double open; // 0 fermé → 1 ouvert
  final Color accent;
  final Color gold;
  _ChestPainter({required this.open, required this.accent, required this.gold});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bodyTop = h * 0.42;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, bodyTop, w, h - bodyTop), const Radius.circular(14));
    final bodyPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(const Color(0xFF26262F), accent, 0.35)!, const Color(0xFF111116)])
          .createShader(body.outerRect);

    // Lueur intérieure quand c'est ouvert
    if (open > 0) {
      final glow = Paint()
        ..shader = RadialGradient(colors: [gold.withValues(alpha: 0.9 * open), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w / 2, bodyTop), radius: w * 0.6));
      canvas.drawCircle(Offset(w / 2, bodyTop), w * 0.6, glow);
    }

    canvas.drawRRect(body, bodyPaint);
    final band = Paint()..color = gold;
    canvas.drawRect(Rect.fromLTWH(w * 0.12, bodyTop, w * 0.07, h - bodyTop), band);
    canvas.drawRect(Rect.fromLTWH(w * 0.81, bodyTop, w * 0.07, h - bodyTop), band);
    canvas.drawRRect(body, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = gold);

    // Serrure
    final lock = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, bodyTop + 16), width: 26, height: 30), const Radius.circular(6));
    canvas.drawRRect(lock, Paint()..color = gold);
    canvas.drawCircle(Offset(w / 2, bodyTop + 13), 4, Paint()..color = const Color(0xFF111116));
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, bodyTop + 20), width: 3, height: 9), Paint()..color = const Color(0xFF111116));

    // Couvercle : pivote autour de la charnière arrière
    canvas.save();
    canvas.translate(0, bodyTop);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.004)
      ..rotateX(-open * 1.2);
    canvas.transform(m.storage);
    final lidH = h * 0.36;
    final lid = RRect.fromRectAndCorners(Rect.fromLTWH(-2, -lidH, w + 4, lidH), topLeft: const Radius.circular(40), topRight: const Radius.circular(40), bottomLeft: const Radius.circular(6), bottomRight: const Radius.circular(6));
    canvas.drawRRect(lid, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(const Color(0xFF2E2E38), accent, 0.45)!, Color.lerp(const Color(0xFF1A1A20), accent, 0.2)!])
          .createShader(lid.outerRect));
    canvas.drawRect(Rect.fromLTWH(w * 0.12, -lidH + 6, w * 0.07, lidH - 6), band);
    canvas.drawRect(Rect.fromLTWH(w * 0.81, -lidH + 6, w * 0.07, lidH - 6), band);
    canvas.drawRRect(lid, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChestPainter old) => old.open != open || old.accent != accent;
}

class _Rays extends CustomPainter {
  final double t;
  final Color color;
  _Rays(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final p = Paint()..color = color.withValues(alpha: 0.18 * t);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + t * 0.6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - 0.09) * size.width * 0.7 * t, c.dy + sin(a - 0.09) * size.width * 0.7 * t)
        ..lineTo(c.dx + cos(a + 0.09) * size.width * 0.7 * t, c.dy + sin(a + 0.09) * size.width * 0.7 * t)
        ..close();
      canvas.drawPath(path, p);
    }
    // Étincelles
    final rnd = Random(7);
    final sp = Paint()..color = color.withValues(alpha: (1 - t * 0.6));
    for (var i = 0; i < 18; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final r = (40 + rnd.nextDouble() * 90) * t;
      canvas.drawCircle(c + Offset(cos(a) * r, sin(a) * r - 20 * t), 2 + rnd.nextDouble() * 2.5, sp);
    }
  }

  @override
  bool shouldRepaint(covariant _Rays old) => old.t != t;
}
