import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';

class AchievementLevel {
  final int level;
  final String title;
  final String description;
  final int target;
  final int xpReward;

  AchievementLevel({required this.level, required this.title, required this.description, required this.target, required this.xpReward});
}

class Achievement {
  final String id;
  final IconData icon;
  final String category;
  final List<AchievementLevel> levels;
  int currentProgress = 0;
  int unlockedLevel = 0;

  Achievement({required this.id, required this.icon, required this.levels, this.category = 'Collection'});

  AchievementLevel get displayLevel => unlockedLevel >= levels.length ? levels.last : levels[unlockedLevel];
  bool get isFullyCompleted => unlockedLevel >= levels.length;
  double get progressToNext {
    if (isFullyCompleted) return 1;
    final prev = unlockedLevel == 0 ? 0 : levels[unlockedLevel - 1].target;
    final next = levels[unlockedLevel].target;
    return ((currentProgress - prev) / (next - prev)).clamp(0.0, 1.0);
  }
}

/// Succès pensés pour les passionnés : nations, performances, raretés, icônes et habitudes de spotter.
class AchievementService {
  final List<dynamic> allBrands;
  final List<Map<String, dynamic>> spottedCars;

  AchievementService({required this.allBrands, required this.spottedCars});

  static AchievementLevel _l(int level, String title, String description, int target, int xp) =>
      AchievementLevel(level: level, title: title, description: description, target: target, xpReward: xp);

  static List<Achievement> catalog() => [
        // ------------------------------------------------------------- Collection
        Achievement(id: 'first_spot', category: 'Collection', icon: Icons.flag_rounded, levels: [
          _l(1, 'Contact', 'Enregistrer ton tout premier spot', 1, 10),
        ]),
        Achievement(id: 'car_count', category: 'Collection', icon: Icons.garage_rounded, levels: [
          _l(1, 'Premier garage', 'Spotter 10 voitures', 10, 50),
          _l(2, 'Parc privé', 'Spotter 50 voitures', 50, 150),
          _l(3, 'Concession', 'Spotter 150 voitures', 150, 400),
          _l(4, 'Musée', 'Spotter 500 voitures', 500, 1000),
        ]),
        Achievement(id: 'model_diversity', category: 'Collection', icon: Icons.view_module_rounded, levels: [
          _l(1, 'Curieux', 'Spotter 25 modèles différents', 25, 80),
          _l(2, 'Encyclopédiste', 'Spotter 100 modèles différents', 100, 300),
          _l(3, 'Base de données vivante', 'Spotter 300 modèles différents', 300, 900),
        ]),
        Achievement(id: 'brand_diversity', category: 'Collection', icon: Icons.workspace_premium_rounded, levels: [
          _l(1, 'Multimarque', 'Spotter 10 marques différentes', 10, 60),
          _l(2, 'Salon de Genève', 'Spotter 30 marques différentes', 30, 200),
          _l(3, 'Tour du monde', 'Spotter 60 marques différentes', 60, 600),
        ]),

        // ------------------------------------------------------------- Nations
        Achievement(id: 'nation_france', category: 'Nations', icon: Icons.flag_circle_rounded, levels: [
          _l(1, 'Cocorico', 'Spotter 5 françaises', 5, 30),
          _l(2, 'Made in France', 'Spotter 25 françaises', 25, 120),
          _l(3, 'Ambassadeur tricolore', 'Spotter 75 françaises', 75, 300),
        ]),
        Achievement(id: 'nation_italy', category: 'Nations', icon: Icons.local_fire_department_rounded, levels: [
          _l(1, 'Dolce vita', 'Spotter 3 italiennes', 3, 30),
          _l(2, 'Tifoso', 'Spotter 15 italiennes', 15, 150),
          _l(3, 'Cuore sportivo', 'Spotter 40 italiennes', 40, 400),
        ]),
        Achievement(id: 'nation_germany', category: 'Nations', icon: Icons.precision_manufacturing_rounded, levels: [
          _l(1, 'Ingénierie', 'Spotter 10 allemandes', 10, 40),
          _l(2, 'Vorsprung', 'Spotter 40 allemandes', 40, 150),
          _l(3, 'Autobahn Meister', 'Spotter 100 allemandes', 100, 400),
        ]),
        Achievement(id: 'nation_japan', category: 'Nations', icon: Icons.landscape_rounded, levels: [
          _l(1, 'Kaizen', 'Spotter 5 japonaises', 5, 30),
          _l(2, 'Touge', 'Spotter 20 japonaises', 20, 150),
          _l(3, 'Wangan Midnight', 'Spotter 60 japonaises', 60, 400),
        ]),
        Achievement(id: 'nation_usa', category: 'Nations', icon: Icons.stars_rounded, levels: [
          _l(1, 'Route 66', 'Spotter 3 américaines', 3, 40),
          _l(2, 'V8 Country', 'Spotter 15 américaines', 15, 150),
          _l(3, 'Detroit Iron', 'Spotter 40 américaines', 40, 400),
        ]),
        Achievement(id: 'nation_uk', category: 'Nations', icon: Icons.castle_rounded, levels: [
          _l(1, 'Tea time', 'Spotter 3 britanniques', 3, 40),
          _l(2, 'British Racing Green', 'Spotter 12 britanniques', 12, 150),
          _l(3, 'Goodwood', 'Spotter 30 britanniques', 30, 400),
        ]),
        Achievement(id: 'nation_sweden', category: 'Nations', icon: Icons.ac_unit_rounded, levels: [
          _l(1, 'Fika', 'Spotter 3 suédoises', 3, 40),
          _l(2, 'Scandinave', 'Spotter 12 suédoises', 12, 150),
        ]),
        Achievement(id: 'nation_china', category: 'Nations', icon: Icons.bolt_rounded, levels: [
          _l(1, 'Nouvelle vague', 'Spotter 3 chinoises', 3, 50),
          _l(2, 'Shenzhen express', 'Spotter 12 chinoises', 12, 200),
        ]),

        // ------------------------------------------------------------- Performances
        Achievement(id: 'perf_power', category: 'Performances', icon: Icons.speed_rounded, levels: [
          _l(1, 'Sportive', 'Spotter une voiture de 300 ch ou plus', 300, 40),
          _l(2, 'Supercar', 'Spotter une voiture de 500 ch ou plus', 500, 100),
          _l(3, 'Hypercar', 'Spotter une voiture de 750 ch ou plus', 750, 250),
          _l(4, 'Mégawatt', 'Spotter une voiture de 1 000 ch ou plus', 1000, 600),
        ]),
        Achievement(id: 'perf_vmax', category: 'Performances', icon: Icons.trending_up_rounded, levels: [
          _l(1, 'Bridée à 250', 'Spotter une voiture capable de 250 km/h', 250, 40),
          _l(2, 'Club des 300', 'Spotter une voiture capable de 300 km/h', 300, 120),
          _l(3, 'Vmax', 'Spotter une voiture capable de 350 km/h', 350, 300),
          _l(4, 'Record du monde', 'Spotter une voiture capable de 400 km/h', 400, 700),
        ]),
        Achievement(id: 'perf_accel', category: 'Performances', icon: Icons.timer_rounded, levels: [
          _l(1, 'Coup de pied', 'Spotter une voiture qui fait le 0 à 100 en moins de 4 s', 1, 60),
          _l(2, 'Catapulte', 'Spotter 5 voitures sous les 4 s', 5, 200),
          _l(3, 'Launch control', 'Spotter 15 voitures sous les 4 s', 15, 500),
        ]),
        Achievement(id: 'perf_light', category: 'Performances', icon: Icons.air_rounded, levels: [
          _l(1, 'Poids plume', 'Spotter une voiture de moins de 1 000 kg', 1, 30),
          _l(2, 'Light is right', 'Spotter 10 voitures de moins de 1 000 kg', 10, 150),
        ]),
        Achievement(id: 'perf_electric', category: 'Performances', icon: Icons.electric_car_rounded, levels: [
          _l(1, 'Courant alternatif', 'Spotter 5 électriques', 5, 30),
          _l(2, 'Haute tension', 'Spotter 25 électriques', 25, 150),
          _l(3, 'Gigafactory', 'Spotter 75 électriques', 75, 400),
        ]),

        // ------------------------------------------------------------- Raretés
        Achievement(id: 'rarity_rare', category: 'Raretés', icon: Icons.diamond_outlined, levels: [
          _l(1, 'Œil affûté', 'Spotter une voiture Rare ou mieux', 1, 40),
          _l(2, 'Chasseur', 'Spotter 10 voitures Rares ou mieux', 10, 150),
          _l(3, 'Traqueur', 'Spotter 30 voitures Rares ou mieux', 30, 400),
        ]),
        Achievement(id: 'rarity_exotic', category: 'Raretés', icon: Icons.diamond_rounded, levels: [
          _l(1, 'Exotique', 'Spotter une voiture Exotique ou mieux', 1, 80),
          _l(2, 'Paddock', 'Spotter 5 voitures Exotiques ou mieux', 5, 250),
          _l(3, 'Club privé', 'Spotter 15 voitures Exotiques ou mieux', 15, 700),
        ]),
        Achievement(id: 'rarity_mythic', category: 'Raretés', icon: Icons.auto_awesome_rounded, levels: [
          _l(1, 'Licorne', 'Spotter une voiture Mythique', 1, 200),
          _l(2, 'Collection privée', 'Spotter 3 voitures Mythiques', 3, 500),
          _l(3, 'Concours d’élégance', 'Spotter 10 voitures Mythiques', 10, 1500),
        ]),

        // ------------------------------------------------------------- Icônes
        Achievement(id: 'icon_ferrari', category: 'Icônes', icon: Icons.sports_score_rounded, levels: [
          _l(1, 'Cavallino', 'Spotter une Ferrari', 1, 80),
          _l(2, 'Maranello', 'Spotter 5 Ferrari', 5, 250),
          _l(3, 'Scuderia', 'Spotter 20 Ferrari', 20, 800),
        ]),
        Achievement(id: 'icon_lambo', category: 'Icônes', icon: Icons.change_history_rounded, levels: [
          _l(1, 'Toro', 'Spotter une Lamborghini', 1, 100),
          _l(2, 'Sant’Agata', 'Spotter 5 Lamborghini', 5, 300),
        ]),
        Achievement(id: 'icon_911', category: 'Icônes', icon: Icons.all_inclusive_rounded, levels: [
          _l(1, 'Neunelfer', 'Spotter 3 versions différentes de 911', 3, 60),
          _l(2, 'Flat-six', 'Spotter 8 versions différentes de 911', 8, 200),
          _l(3, 'Zuffenhausen', 'Spotter 15 versions différentes de 911', 15, 500),
        ]),
        Achievement(id: 'icon_trinity', category: 'Icônes', icon: Icons.change_circle_rounded, levels: [
          _l(1, 'Un tiers de légende', 'Spotter une McLaren P1, une Porsche 918 ou une LaFerrari', 1, 400),
          _l(2, 'La Sainte Trinité', 'Spotter les trois', 3, 2000),
        ]),
        Achievement(id: 'icon_jdm', category: 'Icônes', icon: Icons.nightlife_rounded, levels: [
          _l(1, 'JDM', 'Spotter une légende japonaise (Supra, GT-R, NSX, RX-7, Evo, WRX STI…)', 1, 60),
          _l(2, 'Tokyo Drift', 'Spotter 4 légendes JDM différentes', 4, 250),
          _l(3, 'Bayside Blue', 'Spotter 8 légendes JDM différentes', 8, 600),
        ]),
        Achievement(id: 'icon_rally', category: 'Icônes', icon: Icons.terrain_rounded, levels: [
          _l(1, 'Spéciale', 'Spotter une icône du rallye (Quattro, Delta Integrale, 205 T16, Impreza, Evo…)', 1, 60),
          _l(2, 'Groupe B', 'Spotter 4 icônes du rallye différentes', 4, 300),
        ]),
        Achievement(id: 'era_youngtimer', category: 'Icônes', icon: Icons.album_rounded, levels: [
          _l(1, 'Youngtimer', 'Spotter 3 modèles lancés entre 1985 et 1999', 3, 40),
          _l(2, 'Années 90', 'Spotter 15 youngtimers', 15, 150),
          _l(3, 'Néo-rétro', 'Spotter 40 youngtimers', 40, 400),
        ]),
        Achievement(id: 'era_classic', category: 'Icônes', icon: Icons.history_rounded, levels: [
          _l(1, 'Ancêtre', 'Spotter un modèle lancé avant 1975', 1, 50),
          _l(2, 'Rétromobile', 'Spotter 10 modèles d’avant 1975', 10, 250),
          _l(3, 'Musée roulant', 'Spotter 25 modèles d’avant 1975', 25, 700),
        ]),

        // ------------------------------------------------------------- Spotter
        Achievement(id: 'spot_photo', category: 'Spotter', icon: Icons.photo_camera_rounded, levels: [
          _l(1, 'Déclencheur', 'Ajouter 1 spot avec photo', 1, 10),
          _l(2, 'Photographe', 'Ajouter 25 spots avec photo', 25, 120),
          _l(3, 'Reporter', 'Ajouter 100 spots avec photo', 100, 400),
        ]),
        Achievement(id: 'spot_day', category: 'Spotter', icon: Icons.today_rounded, levels: [
          _l(1, 'Bonne pioche', 'Spotter 5 voitures le même jour', 5, 50),
          _l(2, 'Journée salon', 'Spotter 10 voitures le même jour', 10, 150),
          _l(3, 'Rassemblement', 'Spotter 20 voitures le même jour', 20, 400),
        ]),
        Achievement(id: 'spot_streak', category: 'Spotter', icon: Icons.local_fire_department_outlined, levels: [
          _l(1, 'Régulier', 'Spotter 3 jours d’affilée', 3, 40),
          _l(2, 'Semaine parfaite', 'Spotter 7 jours d’affilée', 7, 150),
          _l(3, 'Sans relâche', 'Spotter 30 jours d’affilée', 30, 800),
        ]),
        Achievement(id: 'spot_cities', category: 'Spotter', icon: Icons.location_city_rounded, levels: [
          _l(1, 'Voyageur', 'Spotter dans 3 villes', 3, 40),
          _l(2, 'Road trip', 'Spotter dans 10 villes', 10, 200),
          _l(3, 'Globe-trotter', 'Spotter dans 30 villes', 30, 600),
        ]),
        Achievement(id: 'spot_plates', category: 'Spotter', icon: Icons.public_rounded, levels: [
          _l(1, 'Plaque étrangère', 'Spotter des plaques de 2 pays', 2, 40),
          _l(2, 'Douanier', 'Spotter des plaques de 5 pays', 5, 200),
        ]),
        Achievement(id: 'spot_colors', category: 'Spotter', icon: Icons.palette_rounded, levels: [
          _l(1, 'Nuancier', 'Spotter 5 couleurs différentes', 5, 25),
          _l(2, 'Arc-en-ciel', 'Spotter 8 couleurs différentes', 8, 80),
          _l(3, 'Spectre complet', 'Spotter les 12 couleurs', 12, 200),
        ]),
        Achievement(id: 'spot_night', category: 'Spotter', icon: Icons.dark_mode_rounded, levels: [
          _l(1, 'Noctambule', 'Spotter une voiture entre 22 h et 5 h', 1, 30),
          _l(2, 'Night run', 'Spotter 10 voitures la nuit', 10, 150),
        ]),
        Achievement(id: 'spot_loyal', category: 'Spotter', icon: Icons.repeat_rounded, levels: [
          _l(1, 'Déjà-vu', 'Spotter 3 fois le même modèle', 3, 20),
          _l(2, 'Habitué', 'Spotter 10 fois le même modèle', 10, 100),
        ]),
      ];

  static const categories = ['Collection', 'Nations', 'Performances', 'Raretés', 'Icônes', 'Spotter'];

  List<Achievement> checkAchievements({bool calculateProgress = true}) {
    final list = catalog();
    final ctx = _Context(allBrands, spottedCars);
    for (final a in list) {
      final p = ctx.progress(a.id);
      a.currentProgress = p;
      a.unlockedLevel = a.levels.where((l) => p >= l.target).length;
    }
    return list;
  }
}


class _Context {
  final List<Map<String, dynamic>> cars;
  final Map<String, String> brandCountry = {};

  _Context(List<dynamic> brands, this.cars) {
    for (final b in brands) {
      if (b is Map && b['id'] != null) brandCountry[b['id'] as String] = (b['pays'] ?? '') as String;
    }
  }

  static int _int(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return 0;
  }

  Map<String, dynamic> _spec(Map<String, dynamic> c) {
    final m = DataManager.instance.modelById(c['modelId'] as String?);
    return m == null ? c : {...m, ...c};
  }

  int _year(Map<String, dynamic> c) {
    final m = RegExp(r'(18|19|20)\d{2}').firstMatch('${_spec(c)['production_years'] ?? ''}');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  String _name(Map<String, dynamic> c) => '${c['brandName'] ?? ''} ${c['modelName'] ?? ''}'.toLowerCase();

  int _country(String country) => cars.where((c) => brandCountry[c['brandId']] == country).length;

  int _distinct(bool Function(Map<String, dynamic>) test) =>
      cars.where(test).map((c) => c['modelId'] ?? c['modelName']).toSet().length;

  static final _jdm = RegExp(r'supra|skyline|gt-r|gtr|nsx|rx-7|rx7|rx-8|lancer evolution|evo |impreza wrx|wrx sti|silvia|s2000|integra type r|civic type r|180sx|200sx|300zx|celica gt-four|mr2|ae86|sprinter trueno|3000gt|gto');
  static final _rally = RegExp(r'quattro|delta (hf )?integrale|delta s4|205 t16|037|stratos|impreza|lancer evolution|celica gt-four|escort rs cosworth|sierra rs cosworth|r5 turbo|5 turbo|clio v6');
  static final _trinity = {'p1': RegExp(r'mclaren p1'), '918': RegExp(r'918 spyder|porsche 918'), 'laf': RegExp(r'laferrari')};

  int progress(String id) {
    switch (id) {
      case 'first_spot':
      case 'car_count':
        return cars.length;
      case 'model_diversity':
        return cars.map((c) => c['modelId']).whereType<String>().toSet().length;
      case 'brand_diversity':
        return cars.map((c) => c['brandId'] ?? c['brandName']).whereType<String>().toSet().length;
      case 'nation_france':
        return _country('France');
      case 'nation_italy':
        return _country('Italie');
      case 'nation_germany':
        return _country('Allemagne');
      case 'nation_japan':
        return _country('Japon');
      case 'nation_usa':
        return _country('États-Unis');
      case 'nation_uk':
        return _country('Royaume-Uni');
      case 'nation_sweden':
        return _country('Suède');
      case 'nation_china':
        return _country('Chine') + _country('République populaire de Chine');
      case 'perf_power':
        return cars.map((c) => _int(_spec(c)['puissance_ch'])).fold(0, (a, b) => a > b ? a : b);
      case 'perf_vmax':
        return cars.map((c) => _int(_spec(c)['vitesse_max_kmh'])).fold(0, (a, b) => a > b ? a : b);
      case 'perf_accel':
        return cars.where((c) {
          final v = _double(_spec(c)['zero_a_cent_s']);
          return v > 0 && v < 4;
        }).length;
      case 'perf_light':
        return cars.where((c) {
          final w = _int(_spec(c)['poids_kg']);
          return w > 300 && w < 1000;
        }).length;
      case 'perf_electric':
        return cars.where((c) => '${_spec(c)['type_carburant'] ?? ''}'.toLowerCase().contains('lectrique')).length;
      case 'rarity_rare':
        return cars.where((c) => _rarity(c).index >= Rarity.rare.index).length;
      case 'rarity_exotic':
        return cars.where((c) => _rarity(c).index >= Rarity.epique.index).length;
      case 'rarity_mythic':
        return cars.where((c) => _rarity(c) == Rarity.legendaire).length;
      case 'icon_ferrari':
        return cars.where((c) => c['brandId'] == 'ferrari').length;
      case 'icon_lambo':
        return cars.where((c) => c['brandId'] == 'lamborghini').length;
      case 'icon_911':
        return _distinct((c) => c['brandId'] == 'porsche' && '${c['modelName']}'.contains('911'));
      case 'icon_trinity':
        return _trinity.values.where((re) => cars.any((c) => re.hasMatch(_name(c)))).length;
      case 'icon_jdm':
        return _distinct((c) => _jdm.hasMatch(_name(c)));
      case 'icon_rally':
        return _distinct((c) => _rally.hasMatch(_name(c)));
      case 'era_youngtimer':
        return cars.where((c) {
          final y = _year(c);
          return y >= 1985 && y <= 1999;
        }).length;
      case 'era_classic':
        return cars.where((c) {
          final y = _year(c);
          return y > 0 && y < 1975;
        }).length;
      case 'spot_photo':
        return cars.where((c) => c['hasPhoto'] == true || c['userPhotoUrl'] != null).length;
      case 'spot_day':
        final perDay = <String, int>{};
        for (final d in _dates()) {
          final k = '${d.year}-${d.month}-${d.day}';
          perDay[k] = (perDay[k] ?? 0) + 1;
        }
        return perDay.values.fold(0, (a, b) => a > b ? a : b);
      case 'spot_streak':
        final days = _dates().map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
        var best = 0, run = 0;
        DateTime? prev;
        for (final d in days) {
          run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
          if (run > best) best = run;
          prev = d;
        }
        return best;
      case 'spot_cities':
        return cars.map((c) => (c['locationName'] as String?)?.trim().toLowerCase()).whereType<String>().where((s) => s.isNotEmpty).toSet().length;
      case 'spot_plates':
        return cars.map((c) => c['plateCountryCode']).whereType<String>().where((s) => s != 'XX').toSet().length;
      case 'spot_colors':
        return cars.map((c) => c['color']).whereType<String>().toSet().length;
      case 'spot_night':
        return _dates().where((d) => d.hour >= 22 || d.hour < 5).length;
      case 'spot_loyal':
        final counts = <String, int>{};
        for (final c in cars) {
          final k = c['modelId'] as String?;
          if (k != null) counts[k] = (counts[k] ?? 0) + 1;
        }
        return counts.values.fold(0, (a, b) => a > b ? a : b);
    }
    return 0;
  }

  Iterable<DateTime> _dates() => cars.map((c) {
        final t = c['spottedAt'];
        if (t is Timestamp) return t.toDate();
        if (t is DateTime) return t;
        return null;
      }).whereType<DateTime>();

  Rarity _rarity(Map<String, dynamic> c) {
    final stored = c['rarity'];
    if (stored is String) {
      final r = Rarity.values.where((x) => x.name == stored);
      if (r.isNotEmpty) return r.first;
    }
    if (c['isCatalogued'] != true) return Rarity.commune;
    final brand = DataManager.instance.brands.whereType<Map>().where((b) => b['id'] == c['brandId']);
    return rarityFor(brand: brand.isEmpty ? null : Map<String, dynamic>.from(brand.first), model: _spec(c));
  }
}
