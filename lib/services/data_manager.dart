// Fichier: lib/services/data_manager.dart (MODIFIÉ)

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class DataManager with ChangeNotifier {
  // ==========================================================
  // === MODIFICATION : TRANSFORMATION EN SINGLETON ===========
  // ==========================================================
  // 1. On crée une instance statique unique
  static final DataManager instance = DataManager._();
  
  // 2. On rend le constructeur privé pour empêcher d'autres créations
  DataManager._();
  // ==========================================================
  
  List<dynamic> _brands = [];
  Map<String, List<dynamic>> _modelsByBrand = {};

  List<dynamic> get brands => _brands;
  Map<String, List<dynamic>> get modelsByBrand => _modelsByBrand;

  bool _isDataLoaded = false;
  bool get isDataLoaded => _isDataLoaded;

  Future<void> loadAllData() async {
    // Si les données sont déjà chargées, on ne fait rien pour gagner du temps
    if (_isDataLoaded) return;
    
    print("DataManager: Début du chargement des données depuis les assets...");
    try {
      final brandsJsonString = await rootBundle.loadString('assets/data/brands.json');
      _brands = (json.decode(brandsJsonString))['brands'];
      print("DataManager: ${_brands.length} marques chargées.");

      for (var brand in _brands) {
        final brandId = brand['id'];
        if (brandId != null) {
          try {
            final modelsJsonString = await rootBundle.loadString('assets/data/models_by_brand/$brandId.json');
            _modelsByBrand[brandId] = (json.decode(modelsJsonString))['models'];
          } catch (_) {
            _modelsByBrand[brandId] = [];
          }
        }
      }
      _isDataLoaded = true;
      print("DataManager: Tous les modèles ont été chargés avec succès.");
      notifyListeners(); // Informe les widgets qui écoutent que les données sont prêtes
    } catch (e) {
      print("DataManager: Erreur de chargement des données: $e");
    }
  }
}