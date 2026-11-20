// Fichier: scripts/tag_models.dart (Version Finale, Affichage Récapitulatif)

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// =======================================================================
// === CONFIGURATION ===
// =======================================================================

// IMPORTANT : Remplace "..." par ta propre clé API de Google AI Studio.
const String googleApiKey = "YOUR_GOOGLE_API_KEY"; // ancienne clé supprimée (20/11/2026)

// On définit le chemin ABSOLU vers le dossier des modèles.
const String modelsDirectoryPath = r'C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand';

// La liste des fichiers à ignorer.
const List<String> filesToSkip = ["abarth.json"]; 

// =======================================================================

Future<void> main() async {
  if (googleApiKey == "YOUR_GOOGLE_API_KEY") {
    print("\nERREUR : Veuillez remplacer 'YOUR_GOOGLE_API_KEY' par votre clé API de Google AI Studio.");
    return;
  }

  final modelsDirectory = Directory(modelsDirectoryPath);
  if (!await modelsDirectory.exists()) {
    print("Erreur: Le dossier '$modelsDirectoryPath' n'a pas été trouvé. Vérifiez que le chemin est exact.");
    return;
  }

  final brandFiles = modelsDirectory
      .listSync()
      .where((item) => item.path.endsWith('.json'))
      .map((item) => File(item.path))
      .toList();
      
  print("Trouvé ${brandFiles.length} fichiers de marques à traiter.");
  if (filesToSkip.isNotEmpty) {
    print("Fichiers à ignorer : ${filesToSkip.join(', ')}");
  }
  print("ATTENTION: Cette opération va modifier les fichiers originaux !");
  print("-------------------------------------------------------------\n");
  
  int fileCount = 0;
  for (final file in brandFiles) {
    fileCount++;
    final fileName = path.basename(file.path);

    if (filesToSkip.contains(fileName)) {
      print("(${fileCount}/${brandFiles.length}) Ignoré : $fileName");
      continue;
    }

    print("(${fileCount}/${brandFiles.length}) Traitement de : $fileName...");
    
    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    if (data['models'] == null) {
      print(" -> Fichier '$fileName' ignoré (pas de clé 'models').\n");
      continue;
    }
    final models = (data['models'] as List<dynamic>).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> updatedModels = [];

    // --- Compteurs pour le résumé ---
    int successCount = 0;
    int errorCount = 0;
    int skippedCount = 0;

    for (final model in models) {
      if (model.containsKey('tags') && (model['tags'] as List).isNotEmpty) {
        skippedCount++;
        updatedModels.add(model);
        continue;
      }

      final modelName = model['name'] as String;
      
      try {
        final tags = await getTagsFromGemini(modelName);
        model['tags'] = tags;
        updatedModels.add(model);
        successCount++;
      } catch (e) {
        print("    !!! ERREUR pour '$modelName': $e");
        updatedModels.add(model);
        errorCount++;
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // On écrase le fichier original
    final updatedData = {'models': updatedModels};
    final encoder = JsonEncoder.withIndent('  ');
    final formattedJson = encoder.convert(updatedData);
    await file.writeAsString(formattedJson);

    // --- Affichage du résumé pour la marque ---
    print(" -> Résultat pour '$fileName':");
    print("    - ${successCount} modèles tagués avec succès.");
    if (errorCount > 0) {
      print("    - ${errorCount} modèles en erreur (tags non ajoutés).");
    }
    if (skippedCount > 0) {
      print("    - ${skippedCount} modèles ignorés (déjà tagués).");
    }
    print(""); // Ligne vide pour séparer les marques
  }

  print("\n=============================================");
  print("Opération de tagging de masse terminée !");
  print("=============================================");
}

Future<List<String>> getTagsFromGemini(String modelName) async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$googleApiKey');
  
  final prompt = 
    "Pour le modèle de voiture suivant : \"$modelName\", génère une liste de 10 à 15 mots-clés (tags) très pertinents en anglais et en minuscule. "
    "Priorise la précision. Inclus des tags des catégories suivantes si applicables : "
    "1. **Type de carrosserie** (ex: sedan, suv, coupe, hatchback, convertible, wagon, pickup truck, minivan). "
    "2. **Catégorie de marché** (ex: compact car, subcompact car, mid-size car, full-size car, city car). "
    "3. **Segment** (ex: luxury car, sports car, performance car, supercar, hypercar, executive car, grand tourer). "
    "4. **Technologie** (ex: electric car, hybrid, phev). "
    "5. **Termes généraux importants** (ex: car, vehicle, land vehicle, motor vehicle). "
    "Le format de la réponse doit être UNIQUEMENT une liste de tags séparés par des virgules, sans numérotation, sans introduction et sans retour à la ligne. "
    "Exemple de réponse pour 'Tesla Model S Plaid': electric car, sedan, luxury car, performance car, full-size car, car, vehicle, liftback, executive car, battery electric vehicle";

  final response = await http.post(
    url,
    headers: { 'Content-Type': 'application/json' },
    body: json.encode({
      'contents': [{'parts': [{'text': prompt}]}],
      'generationConfig': {
        'temperature': 0.1,
        'topK': 1,
        'topP': 1,
        'maxOutputTokens': 2048,
      },
    }),
  );

  if (response.statusCode == 200) {
    final responseBody = json.decode(utf8.decode(response.bodyBytes));
    final content = responseBody['candidates'][0]['content']['parts'][0]['text'] as String;
    return content.split(',').map((tag) => tag.trim().replaceAll('\n', '')).where((tag) => tag.isNotEmpty).toList();
  } else {
    throw Exception('Erreur API Gemini: ${response.statusCode} - ${response.body}');
  }
}