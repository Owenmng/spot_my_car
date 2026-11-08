import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class _Question {
  final Map<String, dynamic> model;
  final Map<String, dynamic> brand;
  final List<String> choices;
  final String answer;
  final bool aboutBrand;
  _Question({required this.model, required this.brand, required this.choices, required this.answer, required this.aboutBrand});
}

/// « Blind test » : 10 photos du catalogue, 10 secondes chacune.
/// D'abord la marque, puis le modèle exact. XP gagnés une fois par jour.
class QuizScreen extends StatefulWidget {
  /// En duel : les deux amis reçoivent exactement les mêmes questions.
  final Duel? duel;
  const QuizScreen({super.key, this.duel});

  static const rounds = 10;
  static const secondsPerQuestion = 10;
  static const xpPerAnswer = 5;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late Random _rng = widget.duel != null ? Random(widget.duel!.quizSeed) : Random();
  late final AnimationController _timer = AnimationController(vsync: this, duration: const Duration(seconds: QuizScreen.secondsPerQuestion))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _answer(null);
    });

  List<_Question> _questions = [];
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  String? _picked;
  bool _finished = false;
  int? _xpEarned;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // Quitter un duel en cours de partie compte comme terminé (pas de seconde chance).
    if (widget.duel != null && !_finished && _questions.isNotEmpty && (_index > 0 || _picked != null)) {
      DuelService.instance.submitQuiz(widget.duel!, _score).catchError((_) {});
    }
    _timer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.duel != null) _rng = Random(widget.duel!.quizSeed);
    await DataManager.instance.loadAllData();
    final prefs = await SharedPreferences.getInstance();
    _best = prefs.getInt('quiz_best') ?? 0;
    final data = DataManager.instance;
    final brands = data.brands
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .where((b) => data.visibleModels(b['id'] as String).length >= 10)
        .toList()
      ..shuffle(_rng);
    if (brands.length < 4) return;

    final qs = <_Question>[];
    for (var i = 0; i < QuizScreen.rounds; i++) {
      final brand = brands[i % brands.length];
      final models = data.visibleModels(brand['id'] as String)..shuffle(_rng);
      final model = models.first;
      final aboutBrand = i < 4;
      if (aboutBrand) {
        final others = (brands.where((b) => b['id'] != brand['id']).toList()..shuffle(_rng)).take(3).map((b) => b['name'] as String);
        qs.add(_Question(model: model, brand: brand, aboutBrand: true, answer: brand['name'] as String, choices: [brand['name'] as String, ...others]..shuffle(_rng)));
      } else {
        String clean(Map m) => (m['name'] as String).split('(').first.trim();
        final answer = clean(model);
        final others = models.skip(1).map(clean).where((n) => n != answer).toSet().take(3).toList();
        if (others.length < 3) continue;
        qs.add(_Question(model: model, brand: brand, aboutBrand: false, answer: answer, choices: [answer, ...others]..shuffle(_rng)));
      }
    }
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _index = 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _picked = null;
      _finished = false;
      _xpEarned = null;
    });
    _timer.forward(from: 0);
  }

  void _answer(String? choice) {
    if (_picked != null || _finished || _questions.isEmpty) return;
    _timer.stop();
    final q = _questions[_index];
    final right = choice == q.answer;
    setState(() {
      _picked = choice ?? '';
      if (right) {
        _score++;
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
      } else {
        _streak = 0;
      }
    });
    if (right) {
      HapticFeedback.lightImpact();
      AudioService.instance.playSfx(SoundEffect.clicPrincipal);
    } else {
      HapticFeedback.heavyImpact();
    }
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_index + 1 >= _questions.length) {
        _finish();
      } else {
        setState(() {
          _index++;
          _picked = null;
        });
        _timer.forward(from: 0);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _finished = true);
    AudioService.instance.playSfx(_score >= 7 ? SoundEffect.achievement : SoundEffect.notification);
    final prefs = await SharedPreferences.getInstance();
    if (_score > _best) await prefs.setInt('quiz_best', _score);
    if (widget.duel != null) {
      await DuelService.instance.submitQuiz(widget.duel!, _score).catchError((_) {});
      if (mounted) setState(() => _xpEarned = 0);
      return;
    }
    final xp = await _claim(_score * QuizScreen.xpPerAnswer);
    if (mounted) setState(() => _xpEarned = xp);
  }

  /// Une partie récompensée par jour, pour garder l'XP du spot au premier plan.
  Future<int> _claim(int xp) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || xp <= 0) return 0;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      return await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if ((snap.data()?['quizClaims'] as Map?)?[DailyChallenge.todayKey()] != null) return 0;
        tx.set(ref, {
          'totalXp': FieldValue.increment(xp),
          'xpByWeek': {weekKey(): FieldValue.increment(xp)},
          'quizClaims': {DailyChallenge.todayKey(): xp},
        }, SetOptions(merge: true));
        return xp;
      });
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.duel == null ? 'Blind test' : 'Blind test · duel')),
      body: _questions.isEmpty ? const Center(child: CircularProgressIndicator()) : _finished ? _results() : _question(),
    );
  }

  Widget _question() {
    final accent = Theme.of(context).colorScheme.primary;
    final q = _questions[_index];
    final credit = q.model['imageCredit'] as String?;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('${_index + 1}/${_questions.length}', style: AppText.mono(14, color: AppColors.inkSoft)),
                const Spacer(),
                if (_streak >= 2)
                  Text('🔥 $_streak d’affilée', style: AppText.body(13, weight: FontWeight.w800, color: const Color(0xFFFFC53D))).animate(key: ValueKey(_streak)).scale(begin: const Offset(1.3, 1.3)),
                const SizedBox(width: 12),
                Text('$_score pts', style: AppText.mono(14)),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _timer,
              builder: (_, _) => RevLights(value: 1 - _timer.value, count: 20, height: 8),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CarImage(key: ValueKey(q.model['id']), urls: [q.model['imageUrl'] as String?], brandName: q.aboutBrand ? null : q.brand['name'] as String?),
                    if (credit != null)
                      Positioned(
                        right: 8,
                        bottom: 6,
                        child: Text('Photo : $credit', style: AppText.body(10, color: Colors.white70)),
                      ),
                  ],
                ),
              ).animate(key: ValueKey(_index)).fadeIn(duration: 250.ms).scale(begin: const Offset(0.97, 0.97)),
            ),
            const SizedBox(height: 14),
            Text(
              q.aboutBrand ? 'Quelle marque ?' : 'Quelle ${q.brand['name']} ?',
              textAlign: TextAlign.center,
              style: AppText.display(24),
            ),
            const SizedBox(height: 12),
            for (final c in q.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pressable(
                  onTap: () => _answer(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _picked == null
                          ? AppColors.card
                          : c == q.answer
                              ? AppColors.success.withValues(alpha: 0.2)
                              : c == _picked
                                  ? AppColors.danger.withValues(alpha: 0.2)
                                  : AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _picked == null
                            ? AppColors.line
                            : c == q.answer
                                ? AppColors.success
                                : c == _picked
                                    ? AppColors.danger
                                    : AppColors.line,
                        width: _picked != null && (c == q.answer || c == _picked) ? 1.8 : 1,
                      ),
                    ),
                    child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(15.5, weight: FontWeight.w700)),
                  ),
                ),
              ),
            if (_picked == '')
              Text('Temps écoulé !', textAlign: TextAlign.center, style: AppText.body(13, color: accent, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _results() {
    final verdict = _score == 10
        ? 'Sans faute. Respect.'
        : _score >= 8
            ? 'Œil de connaisseur.'
            : _score >= 5
                ? 'Pas mal du tout.'
                : 'Il est temps de feuilleter le catalogue.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SCORE', style: AppText.label(13, color: AppColors.inkMuted)),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: _score),
              duration: const Duration(milliseconds: 900),
              builder: (_, v, _) => Text('$v/${_questions.length}', style: AppText.display(72)),
            ),
            Text(verdict, style: AppText.body(16, color: AppColors.inkSoft)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: StatPill(value: '$_bestStreak', label: 'meilleure série')),
                Expanded(child: StatPill(value: '${max(_best, _score)}', label: 'record')),
                Expanded(child: StatPill(value: _xpEarned == null ? '…' : '+$_xpEarned', label: 'XP')),
              ],
            ),
            if (widget.duel != null) ...[
              const SizedBox(height: 14),
              Text('Score envoyé à ton adversaire. Le vainqueur remporte +${widget.duel!.stake} XP dans l’onglet Duels.', textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.inkSoft)),
            ] else if (_xpEarned == 0) ...[
              const SizedBox(height: 14),
              Text('Les XP du blind test se gagnent sur la première partie du jour.', textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.inkMuted)),
            ],
            const SizedBox(height: 28),
            if (widget.duel == null) ...[
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.replay_rounded), label: const Text('Rejouer'))),
              const SizedBox(height: 8),
            ],
            TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.duel == null ? 'Retour au garage' : 'Voir le duel')),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }
}
