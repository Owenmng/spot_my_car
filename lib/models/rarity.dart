import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/material.dart';

enum Rarity { commune, peuCommune, rare, epique, legendaire }

extension RarityInfo on Rarity {
  String get label => tr(const ['Commune', 'Sportive', 'Rare', 'Exotique', 'Mythique'][index]);

  Color get color => const [
        Color(0xFF9DA3AD),
        Color(0xFF3DDC97),
        Color(0xFF4DA3FF),
        Color(0xFFB47CFF),
        Color(0xFFFFC94D),
      ][index];

  /// Dégradé utilisé sur le cadre des cartes de collection.
  List<Color> get frame => const [
        [Color(0xFF3A3D44), Color(0xFF6B7079), Color(0xFF2A2C31)],
        [Color(0xFF1C5E45), Color(0xFF3DDC97), Color(0xFF14432F)],
        [Color(0xFF173D73), Color(0xFF4DA3FF), Color(0xFF102B52)],
        [Color(0xFF3F2273), Color(0xFFB47CFF), Color(0xFF2B1650)],
        [Color(0xFF7A5200), Color(0xFFFFD86B), Color(0xFFB37A00), Color(0xFFFFE9A8)],
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
