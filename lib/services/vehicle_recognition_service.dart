import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/gemini_client.dart';

enum RecognitionStatus { car, notACar, notReal, unclear, failed }

class VehicleCandidate {
  final Map<String, dynamic>? brand;
  final Map<String, dynamic>? model;
  final String rawMake;
  final String rawModel;
  final String? generation;
  final int? yearFrom;
  final int? yearTo;
  final double confidence;
  final String? reasoning;
  final List<Map<String, dynamic>> alternatives;

  const VehicleCandidate({
    this.alternatives = const [],
    required this.brand,
    required this.model,
    required this.rawMake,
    required this.rawModel,
    this.generation,
    this.yearFrom,
    this.yearTo,
    required this.confidence,
    this.reasoning,
  });

  bool get inCatalog => brand != null && model != null;

  String get displayBrand => (brand?['name'] as String?) ?? rawMake;
  String get displayModel => (model?['name'] as String?) ?? [rawModel, if (generation != null && generation!.isNotEmpty) generation].join(' ');

  String? get yearsLabel {
    if (yearFrom == null) return null;
    if (yearTo == null || yearTo == yearFrom) return '$yearFrom';
    return '$yearFrom – $yearTo';
  }
}

class RecognitionResult {
  final RecognitionStatus status;
  final String message;
  final List<VehicleCandidate> candidates;
  final String? plate;
  final String? plateCountry;
  final String? colorName;
  final String? bodyType;

  const RecognitionResult({
    required this.status,
    required this.message,
    this.candidates = const [],
    this.plate,
    this.plateCountry,
    this.colorName,
    this.bodyType,
  });

  VehicleCandidate? get best => candidates.isEmpty ? null : candidates.first;
}

/// Reconnaissance d'un véhicule sur une photo avec Gemini (Firebase AI Logic),
/// puis rapprochement avec le catalogue local de SpotMyCar.
class VehicleRecognitionService {
  VehicleRecognitionService._();
  static final VehicleRecognitionService instance = VehicleRecognitionService._();

  static const colorNames = [
    'Noir', 'Blanc', 'Gris', 'Argent', 'Rouge', 'Bleu', 'Vert', 'Jaune', 'Orange', 'Violet', 'Marron', 'Beige',
  ];

  static const Map<String, dynamic> _schema = {
    'type': 'OBJECT',
    'properties': {
      'isIllustration': {
        'type': 'BOOLEAN',
        'description': "true uniquement si l'image est un dessin, un rendu 3D, une capture de jeu vidéo ou un jouet/une miniature. Une photo pro, de presse ou de concession reste false.",
      },
      'vehicleType': {
        'type': 'STRING',
        'enum': ['car', 'motorcycle', 'truck', 'van', 'bus', 'other', 'none'],
      },
      'candidates': {
        'type': 'ARRAY',
        'description': "Jusqu'à 3 hypothèses, de la plus probable à la moins probable",
        'items': {
          'type': 'OBJECT',
          'properties': {
            'make': {'type': 'STRING', 'description': 'Constructeur, écrit comme dans la liste fournie'},
            'model': {'type': 'STRING', 'description': 'Nom commercial du modèle seul, ex: "911", "Clio", "Golf", "3 Series"'},
            'variant': {'type': 'STRING', 'description': 'Version sportive ou finition visible, ex: "GT3 RS", "RS", "GTI", "M Sport"'},
            'generation': {'type': 'STRING', 'description': 'Code de génération court, ex: "992", "Mk8", "E46", "W205", "V"'},
            'yearFrom': {'type': 'INTEGER'},
            'yearTo': {'type': 'INTEGER'},
            'confidence': {'type': 'INTEGER', 'description': 'Confiance de 0 à 100'},
            'cues': {'type': 'STRING', 'description': 'Indices visuels décisifs, en français, une phrase courte'},
          },
          'required': ['make', 'model', 'confidence'],
        },
      },
      'color': {'type': 'STRING', 'enum': colorNames},
      'plateText': {'type': 'STRING', 'description': "Plaque d'immatriculation lisible, sinon chaîne vide. Jamais un texte de cadre de plaque."},
      'plateCountry': {'type': 'STRING', 'description': 'Code pays ISO à 2 lettres de la plaque, sinon chaîne vide'},
      'bodyType': {'type': 'STRING'},
    },
    'required': ['isIllustration', 'vehicleType'],
  };

  String _prompt(List<dynamic> brands) {
    final names = brands.map((b) => b['name']).join(', ');
    return '''
Tu es un expert automobile capable d'identifier n'importe quelle voiture au premier coup d'œil, comme un spotter chevronné.

Analyse la photo et identifie le véhicule principal (le plus grand / le plus net).
- Base-toi sur la calandre, les optiques avant et arrière, les logos, les monogrammes, la forme des vitres, les jantes, les entrées d'air, les sorties d'échappement et les proportions.
- Identifie la génération précise (code châssis si tu le connais) et la période de production.
- Si une version sportive est reconnaissable (AMG, M, RS, GTI, GT3, Type R…), indique-la dans "variant".
- Si tu hésites entre plusieurs modèles, donne-les tous dans "candidates" avec une confiance honnête. Ne gonfle jamais la confiance.
- Écris le constructeur comme dans cette liste quand il y figure : $names.
- Lis la plaque d'immatriculation si elle est lisible, sans rien inventer.
- isIllustration = true seulement pour un dessin, un rendu 3D, un jeu vidéo ou une miniature. Une belle photo de presse reste une photo.
- Les champs "model" et "generation" doivent rester courts (le nom, puis le code), sans phrase.
- S'il n'y a aucune voiture, mets vehicleType à "none" et laisse candidates vide.
''';
  }

  Future<RecognitionResult> analyze(Uint8List imageBytes, {String mimeType = 'image/jpeg'}) async {
    final data = DataManager.instance;
    if (!data.isDataLoaded) await data.loadAllData();

    Map<String, dynamic>? parsed;
    Object? lastError;

    try {
      final text = await GeminiClient.generate(
        parts: [GeminiClient.textPart(_prompt(data.brands)), GeminiClient.imagePart(imageBytes, mime: mimeType)],
        schema: _schema,
      );
      parsed = jsonDecode(_stripFences(text)) as Map<String, dynamic>;
    } catch (e) {
      lastError = e;
      debugPrint('Recognition failed: $e');
    }

    if (parsed == null) {
      return RecognitionResult(
        status: RecognitionStatus.failed,
        message: _friendlyError(lastError),
      );
    }

    final isReal = parsed['isIllustration'] != true;
    final type = (parsed['vehicleType'] as String?) ?? 'other';
    final color = parsed['color'] as String?;
    final plate = _cleanPlate(parsed['plateText'] as String?);
    final plateCountry = (parsed['plateCountry'] as String?)?.toUpperCase();

    if (!isReal) {
      return const RecognitionResult(
        status: RecognitionStatus.notReal,
        message: "On dirait une image qui n'est pas une vraie photo (dessin, jeu, écran…). Prends la voiture en vrai !",
      );
    }
    if (type == 'none') {
      return const RecognitionResult(
        status: RecognitionStatus.notACar,
        message: "Je ne vois pas de voiture sur cette photo. Essaie de cadrer le véhicule en entier.",
      );
    }
    if (type != 'car' && type != 'van') {
      return RecognitionResult(
        status: RecognitionStatus.notACar,
        message: type == 'motorcycle'
            ? "C'est une moto ! SpotMyCar ne collectionne que les voitures pour l'instant."
            : "Ce véhicule ne fait pas partie des voitures que l'on collectionne.",
      );
    }

    final raw = (parsed['candidates'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? [];
    final candidates = <VehicleCandidate>[];
    final seen = <String>{};

    for (final c in raw) {
      final candidate = await _matchCandidate(c);
      final key = candidate.inCatalog ? '${candidate.brand!['id']}/${candidate.model!['id']}' : '${candidate.rawMake}/${candidate.rawModel}'.toLowerCase();
      if (seen.add(key)) candidates.add(candidate);
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (candidates.isEmpty) {
      return RecognitionResult(
        status: RecognitionStatus.unclear,
        message: "Je vois bien une voiture, mais pas assez nettement pour la reconnaître. Approche-toi ou prends-la de 3/4 avant.",
        colorName: colorNames.contains(color) ? color : null,
        plate: plate,
        plateCountry: plateCountry,
      );
    }

    final best = candidates.first;
    final sure = best.confidence >= 0.75;
    return RecognitionResult(
      status: RecognitionStatus.car,
      message: sure ? 'Identifiée avec confiance' : 'Plusieurs pistes possibles, choisis la bonne',
      candidates: candidates.take(3).toList(),
      plate: plate,
      plateCountry: plateCountry,
      colorName: colorNames.contains(color) ? color : null,
      bodyType: parsed['bodyType'] as String?,
    );
  }

  Future<VehicleCandidate> _matchCandidate(Map<String, dynamic> c) async {
    final make = (c['make'] as String? ?? '').trim();
    final model = (c['model'] as String? ?? '').trim();
    final variant = (c['variant'] as String? ?? '').trim();
    final generation = (c['generation'] as String? ?? '').trim();
    final yearFrom = (c['yearFrom'] as num?)?.toInt();
    final yearTo = (c['yearTo'] as num?)?.toInt();
    final confidence = (((c['confidence'] as num?) ?? 50).toDouble() / 100).clamp(0.0, 1.0);

    final brand = findBrand(make, model);
    Map<String, dynamic>? catalogModel;
    var alternatives = <Map<String, dynamic>>[];

    if (brand != null) {
      final models = DataManager.instance.modelsByBrand[brand['id']] ?? const [];
      final scored = models
          .whereType<Map>()
          .map((m) => MapEntry(Map<String, dynamic>.from(m), scoreModel(m, model: model, variant: variant, generation: generation, yearFrom: yearFrom, yearTo: yearTo)))
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      alternatives = scored.take(4).map((e) => e.key).toList();
      if (scored.isNotEmpty && scored.first.value >= 0.45) {
        catalogModel = scored.first.key;
      } else if (models.isNotEmpty) {
        catalogModel = await _askModelPick(brand, models, '$make $model $variant $generation ${yearFrom ?? ''}');
      }
    }

    return VehicleCandidate(
      brand: brand,
      model: catalogModel,
      rawMake: make,
      rawModel: [model, variant].where((s) => s.isNotEmpty).join(' '),
      generation: generation.isEmpty ? null : generation,
      yearFrom: yearFrom,
      yearTo: yearTo,
      confidence: catalogModel == null ? confidence * 0.85 : confidence,
      reasoning: c['cues'] as String?,
      alternatives: alternatives.where((m) => m['id'] != catalogModel?['id']).take(3).toList(),
    );
  }

  /// Quand le rapprochement local hésite, on demande à Gemini de choisir dans la liste exacte.
  Future<Map<String, dynamic>?> _askModelPick(Map<String, dynamic> brand, List<dynamic> models, String description) async {
    final names = models.whereType<Map>().map((m) => '${m['id']} = ${m['name']} (${m['production_years'] ?? '?'})').join('\n');
    final prompt = '''
Voici la liste des modèles ${brand['name']} de notre catalogue (identifiant = nom (années)) :
$names

Le véhicule identifié est : "$description".
Réponds uniquement avec l'identifiant exact du modèle le plus proche, ou "none" si aucun ne correspond vraiment.
''';
    try {
      final text = await GeminiClient.generate(parts: [GeminiClient.textPart(prompt)], timeout: const Duration(seconds: 20));
      final id = text.trim().replaceAll('"', '').split(RegExp(r'\s')).first;
      if (id.isEmpty || id == 'none') return null;
      final match = models.whereType<Map>().firstWhere((m) => m['id'] == id, orElse: () => const {});
      return match.isEmpty ? null : Map<String, dynamic>.from(match);
    } catch (e) {
      debugPrint('Model pick failed: $e');
    }
    return null;
  }

  static const Map<String, String> _brandAliases = {
    'vw': 'volkswagen',
    'volkswagen': 'volkswagen',
    'mercedes': 'mercedes-benz',
    'mercedes benz': 'mercedes-benz',
    'mercedes-amg': 'amg',
    'mercedes amg': 'amg',
    'alfa': 'alfa-romeo',
    'alfa romeo': 'alfa-romeo',
    'aston martin': 'aston-martin',
    'land rover': 'land-rover',
    'range rover': 'land-rover',
    'rolls royce': 'rolls-royce',
    'ds automobiles': 'ds',
    'citroën': 'citroen',
    'škoda': 'skoda',
    'chevy': 'chevrolet',
    'ford mustang': 'mustang',
  };

  /// Retrouve la marque du catalogue à partir du nom donné par l'IA.
  static Map<String, dynamic>? findBrand(String make, [String model = '']) {
    final brands = DataManager.instance.brands.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();
    final n = normalize(make);
    if (n.isEmpty) return null;

    if (normalize(model).startsWith('mustang') && n == 'ford') {
      final m = brands.where((b) => b['id'] == 'mustang');
      if (m.isNotEmpty) return m.first;
    }

    final alias = _brandAliases[make.toLowerCase().trim()] ?? _brandAliases[n];
    if (alias != null) {
      final m = brands.where((b) => b['id'] == alias);
      if (m.isNotEmpty) return m.first;
    }
    for (final b in brands) {
      if (normalize(b['name']) == n || normalize(b['id']) == n) return b;
    }
    for (final b in brands) {
      final bn = normalize(b['name']);
      if (bn.isNotEmpty && (n.contains(bn) || bn.contains(n))) return b;
    }
    return null;
  }

  /// Score entre un modèle du catalogue et la description de l'IA (≥ 0.45 = correspondance fiable).
  static double scoreModel(Map m, {required String model, String variant = '', String generation = '', int? yearFrom, int? yearTo}) {
    final catalogName = normalize(m['name']);
    final catalogTokens = tokens(m['name']);
    final modelTokens = tokens(model);
    final variantTokens = tokens(variant).difference(const {'coupe', 'hatchback', 'berline', 'sedan', 'break', 'estate', 'cabriolet', 'convertible', '5', '3', 'portes', 'door'});
    final genTokens = tokens(generation).where((t) => t.length >= 2 && !const {'generation', 'gen', 'facelift', 'phase', 'restylage', 'nd', 'rd', 'th', 'st'}.contains(t)).toSet();
    if (modelTokens.isEmpty || catalogTokens.isEmpty) return 0;

    final modelHits = modelTokens.intersection(catalogTokens).length;
    if (modelHits == 0 && !catalogName.contains(normalize(model))) return 0;

    var score = modelHits / modelTokens.length * 0.6;
    if (catalogName.startsWith(normalize(model))) score += 0.2;
    score += variantTokens.intersection(catalogTokens).length * 0.18;
    if (genTokens.any(catalogTokens.contains)) score += 0.35;

    final explained = {...modelTokens, ...variantTokens, ...genTokens};
    final extra = catalogTokens.difference(explained).where((t) => !RegExp(r'^\d{4}$').hasMatch(t)).length;
    score -= extra * 0.12;

    final years = RegExp(r'(19|20)\d{2}').allMatches('${m['production_years'] ?? ''}').map((x) => int.parse(x.group(0)!)).toList();
    if (yearFrom != null && years.isNotEmpty) {
      final from = years.first;
      final to = years.length > 1 ? years.last : DateTime.now().year;
      final overlap = (yearFrom <= to + 1) && ((yearTo ?? yearFrom) >= from - 1);
      score += overlap ? 0.15 : -0.3;
    }
    return score;
  }

  static String normalize(dynamic s) {
    var t = (s ?? '').toString().toLowerCase();
    const map = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ç': 'c', 'š': 's', 'ñ': 'n',
    };
    map.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll('serie ', 'series ').replaceAll('classe ', 'class ').replaceAll('-class', ' class');
    return t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Set<String> tokens(dynamic s) => normalize(s).split(' ').where((w) => w.isNotEmpty).toSet();

  static String _stripFences(String text) {
    final t = text.trim();
    if (!t.startsWith('```')) return t;
    return t.replaceAll(RegExp(r'^```[a-z]*\n?'), '').replaceAll(RegExp(r'```$'), '').trim();
  }

  static String? _cleanPlate(String? p) {
    if (p == null) return null;
    final t = p.trim().toUpperCase();
    if (t.length < 4 || t.length > 12) return null;
    return t;
  }

  static String _friendlyError(Object? e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') || s.contains('network') || s.contains('timeout') || s.contains('failed host lookup')) {
      return "Pas de connexion pour analyser la photo. Réessaie dès que tu as du réseau, ou ajoute-la à la main.";
    }
    if (s.contains('quota') || s.contains('resource exhausted') || s.contains('429')) {
      return "L'analyse est très demandée en ce moment. Réessaie dans une minute.";
    }
    if (s.contains('permission') || s.contains('api has not been used') || s.contains('not enabled') || s.contains('403')) {
      return "L'analyse automatique n'est pas encore activée sur le serveur. Tu peux ajouter la voiture à la main.";
    }
    return "L'analyse n'a pas abouti. Réessaie ou ajoute la voiture à la main.";
  }
}
