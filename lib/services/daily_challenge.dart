import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/widgets/spot_card.dart';

class DailyChallenge {
  final String id;
  final String title;
  final String hint;
  final IconData icon;
  final int target;
  final int reward;
  final bool Function(Map<String, dynamic> car) matches;

  const DailyChallenge({
    required this.id,
    required this.title,
    required this.hint,
    required this.icon,
    required this.target,
    required this.reward,
    required this.matches,
  });

  static String todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static String? _countryOf(Map<String, dynamic> car) {
    final b = DataManager.instance.brands.whereType<Map>().where((x) => x['id'] == car['brandId']);
    return b.isEmpty ? null : b.first['pays'] as String?;
  }

  static int _firstYear(Map<String, dynamic> car) {
    final m = RegExp(r'(18|19|20)\d{2}').firstMatch('${car['production_years'] ?? ''}');
    return m == null ? 9999 : int.parse(m.group(0)!);
  }

  static final List<DailyChallenge> _pool = [
    DailyChallenge(id: 'red', title: 'Voir rouge', hint: 'Spotte une voiture rouge', icon: Icons.local_fire_department_rounded, target: 1, reward: 40, matches: (c) => c['color'] == 'Rouge'),
    DailyChallenge(id: 'yellow', title: 'Rayon de soleil', hint: 'Spotte une voiture jaune ou orange', icon: Icons.wb_sunny_rounded, target: 1, reward: 60, matches: (c) => c['color'] == 'Jaune' || c['color'] == 'Orange'),
    DailyChallenge(id: 'italy', title: 'Dolce vita', hint: 'Spotte une marque italienne', icon: Icons.local_pizza_outlined, target: 1, reward: 50, matches: (c) => _countryOf(c) == 'Italie'),
    DailyChallenge(id: 'japan', title: 'JDM', hint: 'Spotte une marque japonaise', icon: Icons.ramen_dining_outlined, target: 1, reward: 40, matches: (c) => _countryOf(c) == 'Japon'),
    DailyChallenge(id: 'germany', title: 'Das Auto', hint: 'Spotte 2 marques allemandes', icon: Icons.sports_score_rounded, target: 2, reward: 50, matches: (c) => _countryOf(c) == 'Allemagne'),
    DailyChallenge(id: 'uk', title: 'God save the car', hint: 'Spotte une marque britannique', icon: Icons.coffee_outlined, target: 1, reward: 60, matches: (c) => _countryOf(c) == 'Royaume-Uni'),
    DailyChallenge(id: 'rare', title: 'Chasseur de rareté', hint: 'Spotte une voiture Rare ou mieux', icon: Icons.diamond_outlined, target: 1, reward: 80, matches: (c) => rarityOfSpot(c).index >= Rarity.rare.index),
    DailyChallenge(id: 'three', title: 'Tournée du quartier', hint: 'Spotte 3 voitures aujourd’hui', icon: Icons.directions_walk_rounded, target: 3, reward: 50, matches: (_) => true),
    DailyChallenge(id: 'classic', title: 'Retour vers le passé', hint: 'Spotte un modèle lancé avant 1995', icon: Icons.history_rounded, target: 1, reward: 70, matches: (c) => _firstYear(c) < 1995),
    DailyChallenge(id: 'photo', title: 'Œil de photographe', hint: 'Ajoute 2 spots avec photo', icon: Icons.photo_camera_outlined, target: 2, reward: 40, matches: (c) => c['userPhotoUrl'] != null),
    DailyChallenge(id: 'electric', title: 'Silence, ça roule', hint: 'Spotte une voiture électrique', icon: Icons.electric_bolt_rounded, target: 1, reward: 50, matches: (c) => '${c['type_carburant'] ?? ''}'.toLowerCase().contains('lectrique')),
  ];

  /// Le même défi pour tout le monde, un nouveau chaque jour.
  static DailyChallenge forDay([DateTime? now]) {
    final d = now ?? DateTime.now();
    final seed = d.year * 372 + d.month * 31 + d.day;
    return _pool[(seed * 7919) % _pool.length];
  }

  int progress(List<Map<String, dynamic>> cars, [DateTime? now]) {
    final d = now ?? DateTime.now();
    return cars.where((c) {
      final t = (c['spottedAt'] as Timestamp?)?.toDate();
      return t != null && t.year == d.year && t.month == d.month && t.day == d.day && matches(c);
    }).length;
  }

  static Future<bool> claim(DailyChallenge c) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final claimed = (snap.data()?['dailyClaims'] as Map?) ?? {};
      if (claimed[todayKey()] == true) return false;
      tx.set(ref, {
        'totalXp': FieldValue.increment(c.reward),
        'dailyClaims': {todayKey(): true},
      }, SetOptions(merge: true));
      return true;
    });
  }
}
