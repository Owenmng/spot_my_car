import 'package:spot_my_car/l10n/i18n.dart';
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

  Achievement({required this.id, required this.icon, required this.levels, this.category = tr('Collection')});

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
        Achievement(id: 'first_spot', category: tr('Collection'), icon: Icons.flag_rounded, levels: [
          _l(1, tr('Contact'), tr('Enregistrer ton tout premier spot'), 1, 10),
        ]),
        Achievement(id: 'car_count', category: tr('Collection'), icon: Icons.garage_rounded, levels: [
          _l(1, tr('Premier garage'), tr('Spotter 10 voitures'), 10, 50),
          _l(2, tr('Parc privé'), tr('Spotter 50 voitures'), 50, 150),
          _l(3, tr('Concession'), tr('Spotter 150 voitures'), 150, 400),
          _l(4, tr('Musée'), tr('Spotter 500 voitures'), 500, 1000),
        ]),
        Achievement(id: 'model_diversity', category: tr('Collection'), icon: Icons.view_module_rounded, levels: [
          _l(1, tr('Curieux'), tr('Spotter 25 modèles différents'), 25, 80),
          _l(2, tr('Encyclopédiste'), tr('Spotter 100 modèles différents'), 100, 300),
          _l(3, tr('Base de données vivante'), tr('Spotter 300 modèles différents'), 300, 900),
        ]),
        Achievement(id: 'brand_diversity', category: tr('Collection'), icon: Icons.workspace_premium_rounded, levels: [
          _l(1, tr('Multimarque'), tr('Spotter 10 marques différentes'), 10, 60),
          _l(2, tr('Salon de Genève'), tr('Spotter 30 marques différentes'), 30, 200),
          _l(3, tr('Tour du monde'), tr('Spotter 60 marques différentes'), 60, 600),
        ]),

        // ------------------------------------------------------------- Nations
        Achievement(id: 'nation_france', category: tr('Nations'), icon: Icons.flag_circle_rounded, levels: [
          _l(1, tr('Cocorico'), tr('Spotter 5 françaises'), 5, 30),
          _l(2, tr('Made in France'), tr('Spotter 25 françaises'), 25, 120),
          _l(3, tr('Ambassadeur tricolore'), tr('Spotter 75 françaises'), 75, 300),
        ]),
        Achievement(id: 'nation_italy', category: tr('Nations'), icon: Icons.local_fire_department_rounded, levels: [
          _l(1, tr('Dolce vita'), tr('Spotter 3 italiennes'), 3, 30),
          _l(2, tr('Tifoso'), tr('Spotter 15 italiennes'), 15, 150),
          _l(3, tr('Cuore sportivo'), tr('Spotter 40 italiennes'), 40, 400),
        ]),
        Achievement(id: 'nation_germany', category: tr('Nations'), icon: Icons.precision_manufacturing_rounded, levels: [
          _l(1, tr('Ingénierie'), tr('Spotter 10 allemandes'), 10, 40),
          _l(2, tr('Vorsprung'), tr('Spotter 40 allemandes'), 40, 150),
          _l(3, tr('Autobahn Meister'), tr('Spotter 100 allemandes'), 100, 400),
        ]),
        Achievement(id: 'nation_japan', category: tr('Nations'), icon: Icons.landscape_rounded, levels: [
          _l(1, tr('Kaizen'), tr('Spotter 5 japonaises'), 5, 30),
          _l(2, tr('Touge'), tr('Spotter 20 japonaises'), 20, 150),
          _l(3, tr('Wangan Midnight'), tr('Spotter 60 japonaises'), 60, 400),
        ]),
        Achievement(id: 'nation_usa', category: tr('Nations'), icon: Icons.stars_rounded, levels: [
          _l(1, tr('Route 66'), tr('Spotter 3 américaines'), 3, 40),
          _l(2, tr('V8 Country'), tr('Spotter 15 américaines'), 15, 150),
          _l(3, tr('Detroit Iron'), tr('Spotter 40 américaines'), 40, 400),
        ]),
        Achievement(id: 'nation_uk', category: tr('Nations'), icon: Icons.castle_rounded, levels: [
          _l(1, tr('Tea time'), tr('Spotter 3 britanniques'), 3, 40),
          _l(2, tr('British Racing Green'), tr('Spotter 12 britanniques'), 12, 150),
          _l(3, tr('Goodwood'), tr('Spotter 30 britanniques'), 30, 400),
        ]),
        Achievement(id: 'nation_sweden', category: tr('Nations'), icon: Icons.ac_unit_rounded, levels: [
          _l(1, tr('Fika'), tr('Spotter 3 suédoises'), 3, 40),
          _l(2, tr('Scandinave'), tr('Spotter 12 suédoises'), 12, 150),
        ]),
        Achievement(id: 'nation_china', category: tr('Nations'), icon: Icons.bolt_rounded, levels: [
          _l(1, tr('Nouvelle vague'), tr('Spotter 3 chinoises'), 3, 50),
          _l(2, tr('Shenzhen express'), tr('Spotter 12 chinoises'), 12, 200),
        ]),

        // ------------------------------------------------------------- Performances
        Achievement(id: 'perf_power', category: tr('Performances'), icon: Icons.speed_rounded, levels: [
          _l(1, tr('Sportive'), tr('Spotter une voiture de 300 ch ou plus'), 300, 40),
          _l(2, tr('Supercar'), tr('Spotter une voiture de 500 ch ou plus'), 500, 100),
          _l(3, tr('Hypercar'), tr('Spotter une voiture de 750 ch ou plus'), 750, 250),
          _l(4, tr('Mégawatt'), tr('Spotter une voiture de 1 000 ch ou plus'), 1000, 600),
        ]),
        Achievement(id: 'perf_vmax', category: tr('Performances'), icon: Icons.trending_up_rounded, levels: [
          _l(1, tr('Bridée à 250'), tr('Spotter une voiture capable de 260 km/h'), 260, 40),
          _l(2, tr('Club des 300'), tr('Spotter une voiture capable de 300 km/h'), 300, 120),
          _l(3, tr('Vmax'), tr('Spotter une voiture capable de 350 km/h'), 350, 300),
          _l(4, tr('Record du monde'), tr('Spotter une voiture capable de 400 km/h'), 400, 700),
        ]),
        Achievement(id: 'perf_accel', category: tr('Performances'), icon: Icons.timer_rounded, levels: [
          _l(1, tr('Coup de pied'), tr('Spotter une voiture qui fait le 0 à 100 en moins de 4 s'), 1, 60),
          _l(2, tr('Catapulte'), tr('Spotter 5 voitures sous les 4 s'), 5, 200),
          _l(3, tr('Launch control'), tr('Spotter 15 voitures sous les 4 s'), 15, 500),
        ]),
        Achievement(id: 'perf_light', category: tr('Performances'), icon: Icons.air_rounded, levels: [
          _l(1, tr('Poids plume'), tr('Spotter une voiture de moins de 1 000 kg'), 1, 30),
          _l(2, tr('Light is right'), tr('Spotter 10 voitures de moins de 1 000 kg'), 10, 150),
        ]),
        Achievement(id: 'perf_electric', category: tr('Performances'), icon: Icons.electric_car_rounded, levels: [
          _l(1, tr('Courant alternatif'), tr('Spotter 5 électriques'), 5, 30),
          _l(2, tr('Haute tension'), tr('Spotter 25 électriques'), 25, 150),
          _l(3, tr('Gigafactory'), tr('Spotter 75 électriques'), 75, 400),
        ]),

        // ------------------------------------------------------------- Raretés
        Achievement(id: 'rarity_rare', category: tr('Raretés'), icon: Icons.diamond_outlined, levels: [
          _l(1, tr('Œil affûté'), tr('Spotter une voiture Rare ou mieux'), 1, 40),
          _l(2, tr('Chasseur'), tr('Spotter 10 voitures Rares ou mieux'), 10, 150),
          _l(3, tr('Traqueur'), tr('Spotter 30 voitures Rares ou mieux'), 30, 400),
        ]),
        Achievement(id: 'rarity_exotic', category: tr('Raretés'), icon: Icons.diamond_rounded, levels: [
          _l(1, tr('Exotique'), tr('Spotter une voiture Exotique ou mieux'), 1, 80),
          _l(2, tr('Paddock'), tr('Spotter 5 voitures Exotiques ou mieux'), 5, 250),
          _l(3, tr('Club privé'), tr('Spotter 15 voitures Exotiques ou mieux'), 15, 700),
        ]),
        Achievement(id: 'rarity_mythic', category: tr('Raretés'), icon: Icons.auto_awesome_rounded, levels: [
          _l(1, tr('Licorne'), tr('Spotter une voiture Mythique'), 1, 200),
          _l(2, tr('Collection privée'), tr('Spotter 3 voitures Mythiques'), 3, 500),
          _l(3, tr('Concours d’élégance'), tr('Spotter 10 voitures Mythiques'), 10, 1500),
        ]),

        // ------------------------------------------------------------- Icônes
        Achievement(id: 'icon_ferrari', category: tr('Icônes'), icon: Icons.sports_score_rounded, levels: [
          _l(1, tr('Cavallino'), tr('Spotter une Ferrari'), 1, 80),
          _l(2, tr('Maranello'), tr('Spotter 5 Ferrari'), 5, 250),
          _l(3, tr('Scuderia'), tr('Spotter 20 Ferrari'), 20, 800),
        ]),
        Achievement(id: 'icon_lambo', category: tr('Icônes'), icon: Icons.change_history_rounded, levels: [
          _l(1, tr('Toro'), tr('Spotter une Lamborghini'), 1, 100),
          _l(2, tr('Sant’Agata'), tr('Spotter 5 Lamborghini'), 5, 300),
        ]),
        Achievement(id: 'icon_911', category: tr('Icônes'), icon: Icons.all_inclusive_rounded, levels: [
          _l(1, tr('Neunelfer'), tr('Spotter 3 versions différentes de 911'), 3, 60),
          _l(2, tr('Flat-six'), tr('Spotter 8 versions différentes de 911'), 8, 200),
          _l(3, tr('Zuffenhausen'), tr('Spotter 15 versions différentes de 911'), 15, 500),
        ]),
        Achievement(id: 'icon_trinity', category: tr('Icônes'), icon: Icons.change_circle_rounded, levels: [
          _l(1, tr('Un tiers de légende'), tr('Spotter une McLaren P1, une Porsche 918 ou une LaFerrari'), 1, 400),
          _l(2, tr('La Sainte Trinité'), tr('Spotter les trois'), 3, 2000),
        ]),
        Achievement(id: 'icon_jdm', category: tr('Icônes'), icon: Icons.nightlife_rounded, levels: [
          _l(1, 'JDM', tr('Spotter une légende japonaise (Supra, GT-R, NSX, RX-7, Evo, WRX STI…)'), 1, 60),
          _l(2, tr('Tokyo Drift'), tr('Spotter 4 légendes JDM différentes'), 4, 250),
          _l(3, tr('Bayside Blue'), tr('Spotter 8 légendes JDM différentes'), 8, 600),
        ]),
        Achievement(id: 'icon_rally', category: tr('Icônes'), icon: Icons.terrain_rounded, levels: [
          _l(1, tr('Spéciale'), tr('Spotter une icône du rallye (Quattro, Delta Integrale, 205 T16, Impreza, Evo…)'), 1, 60),
          _l(2, tr('Groupe B'), tr('Spotter 4 icônes du rallye différentes'), 4, 300),
        ]),
        Achievement(id: 'era_youngtimer', category: tr('Icônes'), icon: Icons.album_rounded, levels: [
          _l(1, tr('Youngtimer'), tr('Spotter 3 modèles lancés entre 1985 et 1999'), 3, 40),
          _l(2, tr('Années 90'), tr('Spotter 15 youngtimers'), 15, 150),
          _l(3, tr('Néo-rétro'), tr('Spotter 40 youngtimers'), 40, 400),
        ]),
        Achievement(id: 'era_classic', category: tr('Icônes'), icon: Icons.history_rounded, levels: [
          _l(1, tr('Ancêtre'), tr('Spotter un modèle lancé avant 1975'), 1, 50),
          _l(2, tr('Rétromobile'), tr('Spotter 10 modèles d’avant 1975'), 10, 250),
          _l(3, tr('Musée roulant'), tr('Spotter 25 modèles d’avant 1975'), 25, 700),
        ]),

        // ------------------------------------------------------------- Spotter
        Achievement(id: 'spot_photo', category: tr('Spotter'), icon: Icons.photo_camera_rounded, levels: [
          _l(1, tr('Déclencheur'), tr('Ajouter 10 spots avec photo'), 10, 40),
          _l(2, tr('Photographe'), tr('Ajouter 25 spots avec photo'), 25, 120),
          _l(3, tr('Reporter'), tr('Ajouter 100 spots avec photo'), 100, 400),
        ]),
        Achievement(id: 'spot_day', category: tr('Spotter'), icon: Icons.today_rounded, levels: [
          _l(1, tr('Bonne pioche'), tr('Spotter 5 voitures le même jour'), 5, 50),
          _l(2, tr('Journée salon'), tr('Spotter 10 voitures le même jour'), 10, 150),
          _l(3, tr('Rassemblement'), tr('Spotter 20 voitures le même jour'), 20, 400),
        ]),
        Achievement(id: 'spot_streak', category: tr('Spotter'), icon: Icons.local_fire_department_outlined, levels: [
          _l(1, tr('Régulier'), tr('Spotter 3 jours d’affilée'), 3, 40),
          _l(2, tr('Semaine parfaite'), tr('Spotter 7 jours d’affilée'), 7, 150),
          _l(3, tr('Sans relâche'), tr('Spotter 30 jours d’affilée'), 30, 800),
        ]),
        Achievement(id: 'spot_cities', category: tr('Spotter'), icon: Icons.location_city_rounded, levels: [
          _l(1, tr('Voyageur'), tr('Spotter dans 3 villes'), 3, 40),
          _l(2, tr('Road trip'), tr('Spotter dans 10 villes'), 10, 200),
          _l(3, tr('Globe-trotter'), tr('Spotter dans 30 villes'), 30, 600),
        ]),
        Achievement(id: 'spot_plates', category: tr('Spotter'), icon: Icons.public_rounded, levels: [
          _l(1, tr('Plaque étrangère'), tr('Spotter des plaques de 2 pays'), 2, 40),
          _l(2, tr('Douanier'), tr('Spotter des plaques de 5 pays'), 5, 200),
        ]),
        Achievement(id: 'spot_colors', category: tr('Spotter'), icon: Icons.palette_rounded, levels: [
          _l(1, tr('Nuancier'), tr('Spotter 6 couleurs différentes'), 6, 30),
          _l(2, tr('Arc-en-ciel'), tr('Spotter 8 couleurs différentes'), 8, 80),
          _l(3, tr('Spectre complet'), tr('Spotter les 12 couleurs'), 12, 200),
        ]),
        Achievement(id: 'spot_night', category: tr('Spotter'), icon: Icons.dark_mode_rounded, levels: [
          _l(1, tr('Noctambule'), tr('Spotter une voiture entre 22 h et 5 h'), 1, 30),
          _l(2, tr('Night run'), tr('Spotter 10 voitures la nuit'), 10, 150),
        ]),
        Achievement(id: 'spot_loyal', category: tr('Spotter'), icon: Icons.repeat_rounded, levels: [
          _l(1, tr('Déjà-vu'), tr('Spotter 3 fois le même modèle'), 3, 20),
          _l(2, tr('Habitué'), tr('Spotter 10 fois le même modèle'), 10, 100),
        ]),
      ];

  static List<String> get categories => [tr('Collection'), tr('Nations'), tr('Performances'), tr('Raretés'), tr('Icônes'), tr('Spotter')];

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
        return _country(tr('France'));
      case 'nation_italy':
        return _country(tr('Italie'));
      case 'nation_germany':
        return _country(tr('Allemagne'));
      case 'nation_japan':
        return _country(tr('Japon'));
      case 'nation_usa':
        return _country(tr('États-Unis'));
      case 'nation_uk':
        return _country(tr('Royaume-Uni'));
      case 'nation_sweden':
        return _country(tr('Suède'));
      case 'nation_china':
        return _country(tr('Chine')) + _country(tr('République populaire de Chine'));
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
