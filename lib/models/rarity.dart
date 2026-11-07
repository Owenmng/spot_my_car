import 'package:flutter/material.dart';

enum Rarity { commune, peuCommune, rare, epique, legendaire }

extension RarityInfo on Rarity {
  String get label => const ['Commune', 'Peu commune', 'Rare', 'Épique', 'Légendaire'][index];

  Color get color => const [
        Color(0xFF8A8F98),
        Color(0xFF2E9E6A),
        Color(0xFF2F6BFF),
        Color(0xFF8A3FFC),
        Color(0xFFE0A100),
      ][index];

  /// Dégradé utilisé sur le cadre des cartes de collection.
  List<Color> get frame => const [
        [Color(0xFFB9BDC4), Color(0xFF7D828B)],
        [Color(0xFF5CD69B), Color(0xFF1E7F52)],
        [Color(0xFF6E9BFF), Color(0xFF1F4FD6)],
        [Color(0xFFB98AFF), Color(0xFF6420D8)],
        [Color(0xFFFFE07A), Color(0xFFE89A00), Color(0xFFFFD447)],
      ][index];

  int get xp => const [10, 25, 50, 100, 250][index];

  int get stars => index + 1;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  return 0;
}

int _firstYear(dynamic years) {
  if (years == null) return 0;
  final m = RegExp(r'(18|19|20)\d{2}').firstMatch(years.toString());
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// Rareté d'un véhicule : on part de la rareté de la marque, puis la puissance,
/// le prix et l'âge (les anciennes se font rares dans la rue) font monter d'un cran.
Rarity rarityFor({Map<String, dynamic>? brand, Map<String, dynamic>? model}) {
  var score = _asInt(brand?['rarete']);
  if (score <= 0) score = 2;

  if (model != null) {
    final hp = _asInt(model['puissance_ch']);
    final price = _asInt(model['prix_lancement_eur']);
    final year = _firstYear(model['production_years']);

    if (hp >= 550 || price >= 180000) score += 1;
    if (year > 0 && year < 1985) score += 1;
  }

  return Rarity.values[(score.clamp(1, 5)) - 1];
}
