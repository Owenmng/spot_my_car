import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Cette liste est maintenant la source unique de vérité pour les couleurs.
final List<Map<String, dynamic>> carColors = [
  {'name': 'Noir', 'color': Colors.black},
  {'name': 'Blanc', 'color': Colors.white},
  {'name': 'Gris', 'color': Colors.grey},
  {'name': 'Argent', 'color': Colors.blueGrey[100]!},
  {'name': 'Rouge', 'color': Colors.red},
  {'name': 'Bleu', 'color': Colors.blue},
  {'name': 'Vert', 'color': Colors.green},
  {'name': 'Jaune', 'color': Colors.yellow},
  {'name': 'Orange', 'color': Colors.orange},
  {'name': 'Violet', 'color': Colors.purple},
  {'name': 'Marron', 'color': Colors.brown},
  {'name': 'Beige', 'color': Colors.brown[100]!},
];

// ----- VERSION CORRIGÉE de loadWorldCities dans app_data.dart -----

class AppData {
  static List<Map<String, dynamic>> worldCities = [];

  static bool _areCitiesLoaded = false; // On ajoute un drapeau

  static Future<void> loadWorldCities() async {
    // Si les villes ont déjà été chargées, on ne fait rien. C'est la clé.
    if (_areCitiesLoaded) {
      return; 
    }

    print("--- AppData: Chargement du fichier world_cities.json ---");
    try {
      final String response = await rootBundle.loadString('assets/data/world_cities.json');
      final data = await json.decode(response);
      
      // On s'assure que les données sont bien une liste
      if (data is List) {
        worldCities = List<Map<String, dynamic>>.from(data.map((item) => Map<String, dynamic>.from(item as Map)));
        _areCitiesLoaded = true; // On lève le drapeau
        print("--- AppData: ${worldCities.length} villes chargées avec succès. ---");
      } else {
        print("--- AppData ERREUR: Le fichier JSON n'est pas une liste. ---");
      }
    } catch (e) {
      print("--- AppData ERREUR: Impossible de charger ou parser world_cities.json: $e ---");
    }
  }
}