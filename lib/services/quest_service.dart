import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/widgets/spot_card.dart';

/// Quêtes de la semaine : trois objectifs qui se renouvellent chaque lundi.
class Quest {
  final String id;
  final String title;
  final int goal;
  final int reward;
  final int progress;
  final bool claimed;
  const Quest({required this.id, required this.title, required this.goal, required this.reward, required this.progress, required this.claimed});

  bool get done => progress >= goal;
}

class QuestService {
  QuestService._();

  static DateTime weekStart([DateTime? now]) {
    final d = now ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  }

  static List<Quest> forWeek(List<Map<String, dynamic>> cars, Map<String, dynamic> user) {
    final start = weekStart();
    final week = cars.where((c) {
      final t = (c['spottedAt'] as Timestamp?)?.toDate();
      return t != null && !t.isBefore(start);
    }).toList();
    final brands = week.map((c) => c['brandId'] ?? c['brandName']).whereType<Object>().toSet().length;
    final rare = week.where((c) => rarityOfSpot(c).index >= Rarity.rare.index).length;
    final cities = week.map((c) => c['locationName']).whereType<String>().where((s) => s.isNotEmpty).toSet().length;
    final claims = (user['questClaims'] as Map?) ?? const {};
    final wk = weekKey();
    bool c(String id) => claims['${wk}_$id'] == true;
    // La 3e quête tourne d'une semaine à l'autre pour varier.
    final rotate = wk.hashCode.abs() % 2 == 0;
    return [
      Quest(id: 'spots', title: tr('Spotte {0} voitures', [8]), goal: 8, reward: 120, progress: week.length, claimed: c('spots')),
      Quest(id: 'brands', title: tr('{0} marques différentes', [4]), goal: 4, reward: 90, progress: brands, claimed: c('brands')),
      rotate
          ? Quest(id: 'rare', title: tr('Une voiture rare ou mieux'), goal: 1, reward: 150, progress: rare, claimed: c('rare'))
          : Quest(id: 'cities', title: tr('Spotte dans {0} villes', [2]), goal: 2, reward: 130, progress: cities, claimed: c('cities')),
    ];
  }

  static Future<bool> claim(Quest q) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !q.done) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final key = '${weekKey()}_${q.id}';
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final d = (await tx.get(ref)).data() ?? {};
      if ((d['questClaims'] as Map?)?[key] == true) return false;
      tx.set(ref, {
        'totalXp': FieldValue.increment(q.reward),
        'xpByWeek': {weekKey(): FieldValue.increment(q.reward)},
        'questClaims': {key: true},
      }, SetOptions(merge: true));
      return true;
    });
  }
}
