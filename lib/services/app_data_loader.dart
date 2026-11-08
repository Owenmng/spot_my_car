// Fichier: lib/services/app_data_loader.dart
import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// Classe pour stocker les données chargées
class AppData {
  static List<dynamic> brands = [];
  static Map<String, List<dynamic>> modelsByBrand = {};
  static bool isDataLoaded = false;
}

// Le service de chargement avec un callback pour suivre la progression
class AppDataLoader {
  Future<void> loadAllData({Function(String message)? onProgress}) async {
    if (AppData.isDataLoaded) {
      onProgress?.call(tr('Données déjà chargées !'));
      return;
    }

    try {
      // --- Étape 1: Charger les marques ---
      onProgress?.call(tr('Chargement des constructeurs...'));
      await Future.delayed(const Duration(milliseconds: 500)); // Petite pause pour l'effet
      final brandsResponse = await rootBundle.loadString('assets/data/brands.json');
      final brandsData = json.decode(brandsResponse);
      AppData.brands = brandsData['brands'];

      // --- Étape 2: Charger tous les modèles ---
      int totalModels = 0;
      for (int i = 0; i < AppData.brands.length; i++) {
        final brand = AppData.brands[i];
        final brandId = brand['id'];
        
        // Affiche la progression
        onProgress?.call(tr('Synchronisation : {0}...', [brand['name']]));
        
        try {
          final path = 'assets/data/models_by_brand/$brandId.json';
          final modelsResponse = await rootBundle.loadString(path);
          final modelsData = json.decode(modelsResponse);
          final modelsList = modelsData['models'] as List<dynamic>;
          AppData.modelsByBrand[brandId] = modelsList;
          totalModels += modelsList.length;
        } catch (e) {
          AppData.modelsByBrand[brandId] = [];
        }
        // Petite pause pour que le message de chargement soit visible
        await Future.delayed(const Duration(milliseconds: 20));
      }

      onProgress?.call(tr('Préparation du garage...'));
      await Future.delayed(const Duration(milliseconds: 800));
      
      AppData.isDataLoaded = true;
      onProgress?.call(tr('Prêt !'));

    } catch (e) {
      print("Erreur critique lors du chargement des données : $e");
      // Gérer l'erreur, peut-être en relançant une exception
      throw Exception("Impossible de charger les données de l'application.");
    }
  }
}