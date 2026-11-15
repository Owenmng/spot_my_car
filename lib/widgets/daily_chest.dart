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

/// Contact du jour : à la première ouverture de la journée, le joueur démarre le moteur
/// et gagne de l'XP. La récompense grossit avec la série de jours consécutifs (cycle de 7).
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

/// Démarrage moteur : on maintient START/STOP, l'aiguille grimpe jusqu'à la zone rouge.
class _DailyChestScreenState extends State<DailyChestScreen> with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFC94D);
  static const _red = Color(0xFFE5202E);
  // Aiguille : 0 → 1 pendant l'appui, retombe si on lâche trop tôt.
  late final AnimationController _rev = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  // Après le démarrage : petite oscillation du ralenti.
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;
  bool _busy = false;
  bool _doubled = false;
  int _lastTick = 0;
  late final int _baseReward = DailyChest.rewardFor(widget.streak);

  int get _reward => _baseReward + (_doubled ? DailyChest.baseFor(widget.streak) : 0);
  int get _cycleDay => (widget.streak - 1) % 7; // 0..6

  @override
  void initState() {
    super.initState();
    if (!widget.demo) AdsService.instance.preload();
    _rev.addListener(_onRev);
  }

  @override
  void dispose() {
    _rev.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _onRev() {
    final tick = (_rev.value * 8).floor();
    if (tick != _lastTick && !_started) {
      _lastTick = tick;
      if (tick > 0) HapticFeedback.selectionClick();
    }
    if (_rev.value >= 1 && !_started) _ignite();
  }

  void _press() {
    if (_started) return;
    HapticFeedback.lightImpact();
    AudioService.instance.playSfx(SoundEffect.moteur);
    _rev.animateTo(1, curve: Curves.easeIn);
  }

  void _release() {
    if (_started || _rev.value >= 1) return;
    _rev.animateBack(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  Future<void> _ignite() async {
    setState(() {
      _started = true;
      _busy = true;
    });
    HapticFeedback.heavyImpact();
    final claim = widget.demo ? Future.value(true) : DailyChest.claim(widget.streak).catchError((_) => false);
    // Coup de gaz puis retour au ralenti
    await _rev.animateTo(0.32, duration: const Duration(milliseconds: 700), curve: Curves.elasticOut);
    _idle.repeat(reverse: true);
    AudioService.instance.playSfx(SoundEffect.succesPrincipal);
    await claim;
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _watchToDouble() async {
    setState(() => _busy = true);
    final ok = await AdsService.instance.showRewarded();
    if (ok && await DailyChest.doubleUp(widget.streak).catchError((_) => false)) {
      HapticFeedback.heavyImpact();
      AudioService.instance.playSfx(SoundEffect.levelUp);
      if (mounted) setState(() => _doubled = true);
    }
    if (!ok && AdsService.instance.lastUnavailable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pas de vidéo disponible pour le moment, réessaie dans quelques minutes'))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final gauge = min(min(size.width - 90, 270.0), size.height * 0.34);
    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CarbonPainter()))),
          // Lueur rouge sous le compteur
          Positioned(
            left: -80,
            right: -80,
            bottom: -size.height * 0.15,
            height: size.height * 0.55,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [_red.withValues(alpha: _started ? 0.30 : 0.16), Colors.transparent]),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: _busy && _started ? null : () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ),
                  Text(tr('CONTACT DU JOUR'), style: AppText.label(12, color: _red).copyWith(letterSpacing: 3.5)).animate().fadeIn(),
                  const SizedBox(height: 6),
                  Text(
                    widget.streak > 1 ? tr('{0} jours d\'affilée', [widget.streak]) : tr('Démarre ta série'),
                    textAlign: TextAlign.center,
                    style: AppText.display(30, color: Colors.white),
                  ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.25),
                  const SizedBox(height: 18),
                  _ShiftLights(cycleDay: _cycleDay, lit: _started, flash: _started).animate().fadeIn(delay: 160.ms),
                  const Spacer(),
                  SizedBox(
                    width: gauge,
                    height: gauge,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rev, _idle]),
                      builder: (context, _) {
                        final v = (_rev.value + (_started ? (_idle.value - 0.5) * 0.025 : 0)).clamp(0.0, 1.05);
                        return CustomPaint(
                          painter: _RevGaugePainter(value: v, started: _started),
                          child: Align(
                            alignment: const Alignment(0, 0.47),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _started
                                  ? TweenAnimationBuilder<int>(
                                      key: ValueKey(_reward),
                                      tween: IntTween(begin: _doubled ? _baseReward : 0, end: _reward),
                                      duration: const Duration(milliseconds: 900),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, n, _) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('+$n', style: AppText.display(46, color: Colors.white).copyWith(height: 1, shadows: [Shadow(color: _red.withValues(alpha: 0.8), blurRadius: 24)])),
                                          Text('XP', style: AppText.label(13, color: Colors.white60).copyWith(letterSpacing: 3)),
                                        ],
                                      ),
                                    )
                                  : Text('× 1000 tr/min', key: const ValueKey('rpm'), style: AppText.mono(11, color: Colors.white38)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c)),
                    child: _started ? _after(context) : _startButton(),
                  ),
                  const Spacer(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    return Column(
      key: const ValueKey('start'),
      children: [
        GestureDetector(
          onTapDown: (_) => _press(),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          child: AnimatedBuilder(
            animation: _rev,
            builder: (context, _) => _StartStopButton(pressure: _rev.value),
          ),
        ),
        const SizedBox(height: 14),
        Text(tr('Maintiens START pour démarrer'), style: AppText.body(14.5, color: Colors.white70, weight: FontWeight.w700))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.45, end: 1, duration: 900.ms),
      ],
    );
  }

  Widget _after(BuildContext context) {
    final next = DailyChest.rewards[(_cycleDay + 1) % 7] * (PlusService.instance.isPlus ? 2 : 1);
    return Column(
      key: const ValueKey('after'),
      children: [
        Text(
          _cycleDay == 6 ? tr('Plein régime ! Une nouvelle série commence demain.') : tr('Reviens demain : +{0} XP au prochain démarrage', [next]),
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
            label: Text(tr('Avec Spot My Car+, chaque démarrage rapporte le double'), style: AppText.body(12.5, color: _gold, weight: FontWeight.w700)),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(tr('EN ROUTE'), style: AppText.label(15, color: Colors.white).copyWith(letterSpacing: 2.5)),
          ),
        ),
      ],
    );
  }
}

/// Barre de shift-lights : une LED par jour du cycle, du vert au rouge.
class _ShiftLights extends StatelessWidget {
  final int cycleDay;
  final bool lit;
  final bool flash;
  const _ShiftLights({required this.cycleDay, required this.lit, required this.flash});

  static const _colors = [Color(0xFF2BD96B), Color(0xFF2BD96B), Color(0xFF9BE22E), Color(0xFFFFC94D), Color(0xFFFF8A1A), Color(0xFFE5202E), Color(0xFF4DA3FF)];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(
                children: [
                  _Led(color: _colors[i], on: i < cycleDay || (i == cycleDay && lit), today: i == cycleDay && !lit, delay: i * 70, flash: flash && i <= cycleDay),
                  const SizedBox(height: 7),
                  Text(i == 6 ? tr('MAX') : tr('J{0}', [i + 1]), style: AppText.label(9.5, color: i == cycleDay ? Colors.white : Colors.white38)),
                  const SizedBox(height: 2),
                  FittedBox(child: Text('+${DailyChest.rewards[i]}', style: AppText.mono(10, color: i == cycleDay ? _colors[i] : Colors.white30))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Led extends StatelessWidget {
  final Color color;
  final bool on;
  final bool today;
  final bool flash;
  final int delay;
  const _Led({required this.color, required this.on, required this.today, required this.flash, required this.delay});

  @override
  Widget build(BuildContext context) {
    Widget led = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: on || today ? [Color.lerp(color, Colors.white, 0.45)!, color] : [const Color(0xFF26262C), const Color(0xFF16161A)],
        ),
        border: Border.all(color: on ? color.withValues(alpha: 0.9) : Colors.white12, width: 1.2),
        boxShadow: on || today ? [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 14, spreadRadius: 1)] : null,
      ),
    );
    if (today) {
      led = led.animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.25, end: 1, duration: 520.ms);
    } else if (flash) {
      led = led.animate(delay: delay.ms).scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 380.ms, curve: Curves.elasticOut);
    }
    return led;
  }
}

/// Bouton ENGINE START/STOP : bague métal, cœur rouge qui s'allume avec la pression.
class _StartStopButton extends StatelessWidget {
  final double pressure;
  const _StartStopButton({required this.pressure});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE5202E);
    return Transform.scale(
      scale: 1 - pressure * 0.05,
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(colors: [Color(0xFF8A8A92), Color(0xFF2A2A30), Color(0xFFD7D7DE), Color(0xFF3A3A42), Color(0xFF8A8A92)]),
          boxShadow: [
            BoxShadow(color: red.withValues(alpha: 0.25 + pressure * 0.5), blurRadius: 30 + pressure * 30, spreadRadius: pressure * 6),
            const BoxShadow(color: Colors.black, blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [Color.lerp(const Color(0xFF2B2B32), red, 0.25 + pressure * 0.6)!, const Color(0xFF0B0B0E)],
            ),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ENGINE', style: AppText.label(10, color: Colors.white70).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: 2),
              Text('START', style: AppText.display(24, color: Color.lerp(Colors.white, red, pressure)!).copyWith(height: 1)),
              Container(margin: const EdgeInsets.symmetric(vertical: 3), width: 44, height: 1.4, color: Colors.white24),
              Text('STOP', style: AppText.label(11, color: Colors.white54).copyWith(letterSpacing: 2.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compte-tours 0 → 8 (×1000 tr/min) avec zone rouge.
class _RevGaugePainter extends CustomPainter {
  final double value;
  final bool started;
  _RevGaugePainter({required this.value, required this.started});

  static const _start = pi * 0.8;
  static const _sweep = pi * 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.width / 2);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Fond du cadran
    canvas.drawCircle(c, r + 6, Paint()..color = const Color(0xFF0C0C10));
    canvas.drawCircle(c, r + 6, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white10);

    // Piste et zone rouge
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawArc(rect.deflate(14), _start, _sweep, false, track);
    canvas.drawArc(rect.deflate(14), _start + _sweep * 0.78, _sweep * 0.22, false, track..color = const Color(0x66E5202E));
    // Remplissage selon le régime
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [Color(0xFF2BD96B), Color(0xFFFFC94D), Color(0xFFFF8A1A), Color(0xFFE5202E)],
        tileMode: TileMode.clamp,
      ).createShader(rect);
    canvas.drawArc(rect.deflate(14), _start, _sweep * value.clamp(0.0, 1.0), false, fill);

    // Graduations et chiffres
    for (var i = 0; i <= 40; i++) {
      final a = _start + _sweep * i / 40;
      final major = i % 5 == 0;
      final p1 = c + Offset(cos(a), sin(a)) * (r - 28);
      final p2 = c + Offset(cos(a), sin(a)) * (r - (major ? 44 : 36));
      canvas.drawLine(p1, p2, Paint()
        ..strokeWidth = major ? 2.4 : 1.2
        ..color = i >= 32 ? const Color(0xFFE5202E) : Colors.white.withValues(alpha: major ? 0.8 : 0.3));
      if (major) {
        final tp = TextPainter(
          text: TextSpan(text: '${i ~/ 5}', style: TextStyle(color: i >= 32 ? const Color(0xFFE5202E) : Colors.white70, fontSize: 15, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        final lp = c + Offset(cos(a), sin(a)) * (r - 60) - Offset(tp.width / 2, tp.height / 2);
        tp.paint(canvas, lp);
      }
    }

    // Aiguille
    final a = _start + _sweep * value.clamp(0.0, 1.03);
    final tip = c + Offset(cos(a), sin(a)) * (r - 30);
    final back = c - Offset(cos(a), sin(a)) * 18;
    canvas.drawLine(back, tip, Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5202E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(back, tip, Paint()
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF3B47));
    canvas.drawCircle(c, 12, Paint()..color = const Color(0xFF1C1C22));
    canvas.drawCircle(c, 12, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white24);
  }

  @override
  bool shouldRepaint(covariant _RevGaugePainter old) => old.value != value || old.started != started;
}

/// Trame fibre de carbone discrète.
class _CarbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final a = Paint()..color = Colors.white.withValues(alpha: 0.022);
    const s = 8.0;
    for (double y = 0; y < size.height; y += s) {
      for (double x = ((y ~/ s) % 2) * s; x < size.width; x += s * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, s, s / 2), a);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
