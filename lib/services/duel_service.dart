import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/notification_service.dart';
import 'package:spot_my_car/widgets/spot_card.dart';

/// Semaine ISO, ex. « 2026W45 » : sert aux classements hebdomadaires entre amis.
String weekKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstDay = DateTime(thursday.year, 1, 1);
  final week = 1 + thursday.difference(firstDay).inDays ~/ 7;
  return '${thursday.year}W${week.toString().padLeft(2, '0')}';
}

enum DuelMode { xp, rarity, brands, theme }

extension DuelModeInfo on DuelMode {
  String get title => switch (this) {
        DuelMode.xp => 'Course aux XP',
        DuelMode.rarity => 'Le plus rare',
        DuelMode.brands => 'Tour des marques',
        DuelMode.theme => 'Thème imposé',
      };

  String get rule => switch (this) {
        DuelMode.xp => 'Le plus d’XP gagnés en spottant pendant le duel.',
        DuelMode.rarity => 'La voiture la plus rare spottée pendant le duel l’emporte.',
        DuelMode.brands => 'Le plus de marques différentes spottées.',
        DuelMode.theme => 'Le plus de voitures correspondant au thème.',
      };

  IconData get icon => switch (this) {
        DuelMode.xp => Icons.bolt_rounded,
        DuelMode.rarity => Icons.diamond_rounded,
        DuelMode.brands => Icons.grid_view_rounded,
        DuelMode.theme => Icons.casino_rounded,
      };
}

class Duel {
  final String id;
  final String challengerId;
  final String opponentId;
  final DuelMode mode;
  final String? themeId;
  final int hours;
  final String status; // pending, active, declined, cancelled
  final DateTime? startAt;
  final DateTime? endAt;
  final Map<String, int> scores;
  final Map<String, bool> claimed;
  final DateTime? createdAt;

  Duel({
    required this.id,
    required this.challengerId,
    required this.opponentId,
    required this.mode,
    required this.themeId,
    required this.hours,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.scores,
    required this.claimed,
    required this.createdAt,
  });

  factory Duel.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Duel(
      id: d.id,
      challengerId: m['challengerId'] as String? ?? '',
      opponentId: m['opponentId'] as String? ?? '',
      mode: DuelMode.values.firstWhere((x) => x.name == m['mode'], orElse: () => DuelMode.xp),
      themeId: m['themeId'] as String?,
      hours: (m['hours'] as num?)?.toInt() ?? 24,
      status: m['status'] as String? ?? 'pending',
      startAt: (m['startAt'] as Timestamp?)?.toDate(),
      endAt: (m['endAt'] as Timestamp?)?.toDate(),
      scores: {for (final e in ((m['scores'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toInt()},
      claimed: {for (final e in ((m['claimed'] as Map?) ?? {}).entries) '${e.key}': e.value == true},
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  DailyChallenge? get theme => themeId == null ? null : DailyChallenge.byId(themeId!);

  String get title => mode == DuelMode.theme && theme != null ? theme!.title : mode.title;
  String get rule => mode == DuelMode.theme && theme != null ? theme!.hint : mode.rule;

  bool get isActive => status == 'active' && endAt != null && DateTime.now().isBefore(endAt!);
  bool get isFinished => status == 'active' && endAt != null && !DateTime.now().isBefore(endAt!);
  bool get isPending => status == 'pending';

  String other(String uid) => uid == challengerId ? opponentId : challengerId;
  int scoreOf(String uid) => scores[uid] ?? 0;

  /// uid du vainqueur, '' en cas d'égalité, null si pas terminé.
  String? get winner {
    if (!isFinished) return null;
    final a = scoreOf(challengerId), b = scoreOf(opponentId);
    if (a == b) return '';
    return a > b ? challengerId : opponentId;
  }

  int get stake => switch (hours) { <= 24 => 100, <= 72 => 150, _ => 250 };

  String scoreLabel(int score) {
    if (mode == DuelMode.rarity) {
      if (score == 0) return '—';
      return Rarity.values.lastWhere((r) => r.xp <= score, orElse: () => Rarity.commune).label;
    }
    if (mode == DuelMode.xp) return '$score XP';
    return '$score';
  }
}

class DuelService {
  DuelService._();
  static final DuelService instance = DuelService._();

  final _col = FirebaseFirestore.instance.collection('duels');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Duel>> watch() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col.where('participants', arrayContains: uid).snapshots().map((s) {
      final list = s.docs.map(Duel.fromDoc).where((d) => d.status != 'cancelled').toList();
      int weight(Duel d) => d.isPending ? 0 : d.isActive ? 1 : 2;
      list.sort((a, b) {
        final w = weight(a).compareTo(weight(b));
        if (w != 0) return w;
        return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
      });
      return list;
    });
  }

  Future<void> challenge({required String opponentUid, required DuelMode mode, String? themeId, required int hours}) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.add({
      'challengerId': uid,
      'opponentId': opponentUid,
      'participants': [uid, opponentUid],
      'mode': mode.name,
      'themeId': themeId,
      'hours': hours,
      'status': 'pending',
      'scores': <String, int>{},
      'claimed': <String, bool>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> accept(Duel d) => _col.doc(d.id).update({
        'status': 'active',
        'startAt': Timestamp.now(),
        'endAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: d.hours))),
      });

  Future<void> decline(Duel d) => _col.doc(d.id).update({'status': 'declined'});
  Future<void> cancel(Duel d) => _col.doc(d.id).update({'status': 'cancelled'});
  Future<void> remove(Duel d) => _col.doc(d.id).delete();

  static int computeScore(Duel d, List<Map<String, dynamic>> cars) {
    if (d.startAt == null || d.endAt == null) return 0;
    final inWindow = cars.where((c) {
      final t = (c['spottedAt'] as Timestamp?)?.toDate();
      return t != null && !t.isBefore(d.startAt!) && t.isBefore(d.endAt!);
    }).toList();
    switch (d.mode) {
      case DuelMode.xp:
        return inWindow.fold<int>(0, (s, c) => s + ((c['xp'] as num?)?.toInt() ?? 0));
      case DuelMode.rarity:
        return inWindow.where((c) => c['isCatalogued'] == true).fold<int>(0, (best, c) {
          final x = rarityOfSpot(c).xp;
          return x > best ? x : best;
        });
      case DuelMode.brands:
        return inWindow.map((c) => c['brandName']).whereType<String>().toSet().length;
      case DuelMode.theme:
        final t = d.theme;
        return t == null ? 0 : inWindow.where(t.matches).length;
    }
  }

  int? _lastSyncCount;
  DateTime? _lastSyncAt;

  /// Appelé à chaque rafraîchissement du garage : ne resynchronise que si
  /// le nombre de spots a changé ou toutes les 10 minutes.
  void syncDebounced(List<Map<String, dynamic>> cars) {
    final now = DateTime.now();
    if (_lastSyncCount == cars.length && _lastSyncAt != null && now.difference(_lastSyncAt!).inMinutes < 10) return;
    _lastSyncCount = cars.length;
    _lastSyncAt = now;
    unawaited(sync(cars));
  }

  /// Met à jour mon score dans chaque duel en cours, à partir de mes propres spots.
  Future<void> sync(List<Map<String, dynamic>> cars) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _col.where('participants', arrayContains: uid).get();
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList('duels_seen') ?? [];
      for (final doc in snap.docs) {
        final d = Duel.fromDoc(doc);
        if (d.status == 'active' && d.endAt != null && DateTime.now().isBefore(d.endAt!.add(const Duration(days: 2)))) {
          final score = computeScore(d, cars);
          if (score != d.scoreOf(uid)) await doc.reference.update({'scores.$uid': score});
        }
        // Nouveau défi reçu : petite notification locale, une seule fois.
        if (d.isPending && d.opponentId == uid && !seen.contains(d.id)) {
          seen.add(d.id);
          unawaited(NotificationService.instance.showNow(500 + seen.length % 50, 'Nouveau duel : ${d.title}', 'Un ami te défie pendant ${d.hours < 48 ? '24 h' : '${d.hours ~/ 24} jours'}. Relève le défi !'));
        }
      }
      await prefs.setStringList('duels_seen', seen.length > 100 ? seen.sublist(seen.length - 100) : seen);
    } catch (e) {
      debugPrint('duels sync: $e');
    }
  }

  /// Le vainqueur encaisse la mise une seule fois.
  Future<bool> claim(Duel d) async {
    final uid = _uid;
    if (uid == null || d.winner != uid || d.claimed[uid] == true) return false;
    final db = FirebaseFirestore.instance;
    final duelRef = _col.doc(d.id);
    final userRef = db.collection('users').doc(uid);
    return db.runTransaction((tx) async {
      final fresh = await tx.get(duelRef);
      if ((fresh.data()?['claimed'] as Map?)?[uid] == true) return false;
      tx.update(duelRef, {'claimed.$uid': true});
      tx.set(userRef, {
        'totalXp': FieldValue.increment(d.stake),
        'xpByWeek': {weekKey(): FieldValue.increment(d.stake)},
        'stats': {'duelsWon': FieldValue.increment(1)},
      }, SetOptions(merge: true));
      return true;
    });
  }
}
