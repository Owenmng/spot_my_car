import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/services/gemini_client.dart';

class FactSheet {
  final String summary;
  final String engine;
  final String keyFigures;
  final String production;
  final List<String> anecdotes;
  final String howToSpot;

  FactSheet({required this.summary, required this.engine, required this.keyFigures, required this.production, required this.anecdotes, required this.howToSpot});

  factory FactSheet.fromJson(Map<String, dynamic> j) => FactSheet(
        summary: '${j['summary'] ?? ''}',
        engine: '${j['engine'] ?? ''}',
        keyFigures: '${j['keyFigures'] ?? ''}',
        production: '${j['production'] ?? ''}',
        anecdotes: ((j['anecdotes'] as List?) ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(),
        howToSpot: '${j['howToSpot'] ?? ''}',
      );
}

/// Fiche « passionné » d'un modèle, rédigée par Gemini puis gardée sur le téléphone.
class FactSheetService {
  FactSheetService._();
  static const _prefix = 'factsheet_v1_';

  static const Map<String, dynamic> _schema = {
    'type': 'OBJECT',
    'properties': {
      'summary': {'type': 'STRING', 'description': "3 à 4 phrases : ce qu'est ce modèle, son époque, sa place dans l'histoire de la marque"},
      'engine': {'type': 'STRING', 'description': 'Motorisations principales (architecture, cylindrée, puissance), en une ou deux phrases'},
      'keyFigures': {'type': 'STRING', 'description': 'Chiffres clés : 0-100, vitesse max, poids, prix de lancement si connus'},
      'production': {'type': 'STRING', 'description': 'Années et volume de production si connu, lieu de fabrication'},
      'anecdotes': {'type': 'ARRAY', 'items': {'type': 'STRING'}, 'description': '2 ou 3 anecdotes vérifiables qui plaisent aux passionnés'},
      'howToSpot': {'type': 'STRING', 'description': 'Comment la reconnaître dans la rue (détails visuels distinctifs)'},
    },
    'required': ['summary', 'engine', 'keyFigures', 'production', 'anecdotes', 'howToSpot'],
  };

  static Future<FactSheet?> cached(String modelId) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('$_prefix$modelId');
      return raw == null ? null : FactSheet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<FactSheet> load({required String modelId, required String brand, required String model, String? years}) async {
    final hit = await cached(modelId);
    if (hit != null) return hit;
    final prompt = '''
Tu es journaliste automobile spécialisé, très rigoureux.
Rédige en français la fiche de la $brand $model${years == null ? '' : ' (production : $years)'} pour des passionnés.
Ton ton est direct, précis, sans superlatifs creux. N'invente jamais un chiffre : si tu n'es pas sûr, écris « non communiqué ».
''';
    final text = await GeminiClient.generate(parts: [GeminiClient.textPart(prompt)], schema: _schema, temperature: 0.3);
    final json = jsonDecode(text) as Map<String, dynamic>;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('$_prefix$modelId', jsonEncode(json));
    } catch (_) {}
    return FactSheet.fromJson(json);
  }
}
