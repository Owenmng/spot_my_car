// Fichier: lib/services/achievement_service.dart (VERSION FINALE CORRIGÉE)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Les modèles (classes AchievementLevel et Achievement) ---
class AchievementLevel {
  final int level;
  final String title;
  final String description;
  final int target;
  final int xpReward;

  AchievementLevel({
    required this.level,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
  });
}

class Achievement {
  final String id;
  final IconData icon;
  final List<AchievementLevel> levels;
  int currentProgress = 0;
  int unlockedLevel = 0;

  Achievement({required this.id, required this.icon, required this.levels});

  AchievementLevel get displayLevel {
    if (unlockedLevel >= levels.length) return levels.last;
    return levels[unlockedLevel];
  }
  bool get isFullyCompleted => unlockedLevel >= levels.length;
}

class RewardResult {
  final int xpGained;
  // MODIFIÉ : On renvoie maintenant la liste des niveaux de succès débloqués
  final List<AchievementLevel> newAchievements; 
  final Map<String, dynamic> updatedClaims;
  // MODIFIÉ : On ajoute l'icône dans le constructeur pour un accès facile
  final Map<String, IconData> achievementIcons;

  RewardResult(this.xpGained, this.newAchievements, this.updatedClaims, this.achievementIcons);
}

// --- Le Service de logique ---
class AchievementService {
  final List<dynamic> allBrands;
  final List<Map<String, dynamic>> spottedCars;
  late final Set<String> _uniqueBrandIds;
  late final Set<String> _uniqueModelIds;

  AchievementService({required this.allBrands, required this.spottedCars}) {
    _uniqueBrandIds = spottedCars.where((c) => c['brandId'] != null).map((car) => car['brandId'] as String).toSet();
    _uniqueModelIds = spottedCars.where((c) => c['modelId'] != null).map((car) => car['modelId'] as String).toSet();
  }

  RewardResult claimRewards(Map<String, dynamic> currentClaims) {
    final allAchievements = checkAchievements(calculateProgress: true);
    int totalXpGained = 0;
    // MODIFIÉ : On crée une liste de AchievementLevel
    final List<AchievementLevel> newAchievements = []; 
    final Map<String, dynamic> updatedClaims = Map.from(currentClaims.cast<String, dynamic>());
    // MODIFIÉ : On crée une map pour stocker les icônes correspondantes
    final Map<String, IconData> achievementIcons = {
      for (var ach in allAchievements) ach.id: ach.icon
    };
    
    print("--- Début du calcul des récompenses ---");
    print("Succès déjà réclamés : $currentClaims");

    for (var achievement in allAchievements) {
      final int previouslyClaimedLevel = updatedClaims[achievement.id] ?? 0;
      
      if (achievement.unlockedLevel > previouslyClaimedLevel) {
        print("NOUVEAU SUCCÈS DÉTECTÉ POUR '${achievement.id}' !");
        print("Niveau atteint: ${achievement.unlockedLevel}, Niveau précédent: $previouslyClaimedLevel");
        for (int i = previouslyClaimedLevel; i < achievement.unlockedLevel; i++) {
          final newLevel = achievement.levels[i];
          totalXpGained += newLevel.xpReward;
          // MODIFIÉ : On ajoute l'objet AchievementLevel complet
          newAchievements.add(newLevel); 
        }
        updatedClaims[achievement.id] = achievement.unlockedLevel;
      }
    }
    print("Nouveaux succès à afficher : ${newAchievements.map((a) => a.title).toList()}");
    print("--- Fin du calcul des récompenses ---");    
    return RewardResult(totalXpGained, newAchievements, updatedClaims, achievementIcons);
  }
  List<Achievement> checkAchievements({bool calculateProgress = true}) {
    List<Achievement> allAchievements = _defineAllAchievements();
    if (calculateProgress) {
      for (var achievement in allAchievements) {
        _calculateProgress(achievement);
      }
    }
    allAchievements.sort((a, b) {
      if (a.isFullyCompleted && !b.isFullyCompleted) return 1;
      if (!a.isFullyCompleted && b.isFullyCompleted) return -1;
      double progressA = a.isFullyCompleted ? 1.0 : a.currentProgress / a.displayLevel.target;
      double progressB = b.isFullyCompleted ? 1.0 : b.currentProgress / b.displayLevel.target;
      if (progressB.compareTo(progressA) != 0) return progressB.compareTo(progressA);
      return a.displayLevel.title.compareTo(b.displayLevel.title);
    });
    return allAchievements;
  }

  List<Achievement> _defineAllAchievements() {
    return [
      // ... (TON IMPRESSIONNANTE LISTE DE SUCCÈS RESTE ICI, INCHANGÉE)
       Achievement(id: 'car_count', icon: Icons.auto_stories_outlined, levels: [
          AchievementLevel(level: 1, title: 'Collectionneur Débutant', description: 'Spotter 10 voitures', target: 10, xpReward: 50),
          AchievementLevel(level: 2, title: 'Passionné Confirmé', description: 'Spotter 50 voitures', target: 50, xpReward: 150),
          AchievementLevel(level: 3, title: 'Maître du Spotting', description: 'Spotter 100 voitures', target: 100, xpReward: 300),
      ]),
      Achievement(id: 'brand_diversity', icon: Icons.menu_book, levels: [
          AchievementLevel(level: 1, title: 'Touriste Automobile', description: 'Spotter 10 marques différentes', target: 10, xpReward: 50),
          AchievementLevel(level: 2, title: 'Explorateur', description: 'Spotter 25 marques différentes', target: 25, xpReward: 150),
          AchievementLevel(level: 3, title: 'L\'Encyclopédie Roulante', description: 'Spotter 50 marques différentes', target: 50, xpReward: 300),
      ]),
      Achievement(id: 'model_diversity', icon: Icons.shield_outlined, levels: [
          AchievementLevel(level: 1, title: 'Variété', description: 'Spotter 20 modèles uniques', target: 20, xpReward: 40),
          AchievementLevel(level: 2, title: 'Spécialiste', description: 'Spotter 75 modèles uniques', target: 75, xpReward: 120),
          AchievementLevel(level: 3, title: 'Expert en Modèles', description: 'Spotter 150 modèles uniques', target: 150, xpReward: 250),
      ]),
      Achievement(id: 'french_specialist', icon: Icons.public, levels: [
          AchievementLevel(level: 1, title: 'Spécialiste Français I', description: 'Spotter 5 voitures françaises', target: 5, xpReward: 30),
          AchievementLevel(level: 2, title: 'Spécialiste Français II', description: 'Spotter 15 françaises', target: 15, xpReward: 100),
          AchievementLevel(level: 3, title: 'Ambassadeur Français', description: 'Spotter 30 françaises', target: 30, xpReward: 200),
      ]),
      Achievement(id: 'italian_aficionado', icon: Icons.local_fire_department, levels: [
          AchievementLevel(level: 1, title: 'Aficionado Italien I', description: 'Spotter 5 voitures italiennes', target: 5, xpReward: 30),
          AchievementLevel(level: 2, title: 'Aficionado Italien II', description: 'Spotter 15 italiennes', target: 15, xpReward: 100),
          AchievementLevel(level: 3, title: 'Tifoso', description: 'Spotter 30 italiennes', target: 30, xpReward: 200),
      ]),
      Achievement(id: 'german_engineer', icon: Icons.precision_manufacturing, levels: [
          AchievementLevel(level: 1, title: 'Ingénierie Allemande I', description: 'Spotter 10 voitures allemandes', target: 10, xpReward: 40),
          AchievementLevel(level: 2, title: 'Ingénierie Allemande II', description: 'Spotter 30 allemandes', target: 30, xpReward: 120),
          AchievementLevel(level: 3, title: 'Autobahn Meister', description: 'Spotter 50 allemandes', target: 50, xpReward: 250),
      ]),
      Achievement(id: 'japanese_legend', icon: Icons.explore, levels: [
          AchievementLevel(level: 1, title: 'Légende Japonaise I', description: 'Spotter 10 voitures japonaises', target: 10, xpReward: 40),
          AchievementLevel(level: 2, title: 'Légende Japonaise II', description: 'Spotter 30 japonaises', target: 30, xpReward: 120),
          AchievementLevel(level: 3, title: 'Drift King', description: 'Spotter 50 japonaises', target: 50, xpReward: 250),
      ]),
      Achievement(id: 'american_muscle', icon: Icons.sports_motorsports, levels: [
          AchievementLevel(level: 1, title: 'American Muscle I', description: 'Spotter 5 voitures américaines', target: 5, xpReward: 30),
          AchievementLevel(level: 2, title: 'American Muscle II', description: 'Spotter 15 américaines', target: 15, xpReward: 100),
          AchievementLevel(level: 3, title: 'Spirit of Detroit', description: 'Spotter 30 américaines', target: 30, xpReward: 200),
      ]),
      Achievement(id: 'british_elegance', icon: Icons.account_balance, levels: [
          AchievementLevel(level: 1, title: 'Élégance Britannique I', description: 'Spotter 5 voitures britanniques', target: 5, xpReward: 30),
          AchievementLevel(level: 2, title: 'Élégance Britannique II', description: 'Spotter 15 britanniques', target: 15, xpReward: 100),
          AchievementLevel(level: 3, title: 'God Save the Cars', description: 'Spotter 30 britanniques', target: 30, xpReward: 200),
      ]),
      Achievement(id: 'unicorn_hunter', icon: Icons.whatshot_outlined, levels: [
          AchievementLevel(level: 1, title: 'Chasseur de Licornes', description: 'Spotter 1 voiture de luxe/hypercar', target: 1, xpReward: 100),
          AchievementLevel(level: 2, title: 'Collectionneur de Trophées', description: 'Spotter 5 voitures de luxe/hypercar', target: 5, xpReward: 250),
          AchievementLevel(level: 3, title: 'Membre du Club Exclusif', description: 'Spotter 10 voitures de luxe/hypercar', target: 10, xpReward: 500),
      ]),
      Achievement(id: 'vintage_lover', icon: Icons.car_repair, levels: [
          AchievementLevel(level: 1, title: 'Amateur de Vintage', description: 'Spotter 1 voiture produite avant 1990', target: 1, xpReward: 20),
          AchievementLevel(level: 2, title: 'Retour vers le Futur', description: 'Spotter 10 voitures produites avant 1990', target: 10, xpReward: 100),
          AchievementLevel(level: 3, title: 'Historien de l\'Automobile', description: 'Spotter 25 voitures produites avant 1990', target: 25, xpReward: 200),
      ]),
      Achievement(id: 'color_collector', icon: Icons.color_lens_outlined, levels: [
          AchievementLevel(level: 1, title: 'Arc-en-ciel I', description: 'Spotter une voiture de 5 couleurs différentes', target: 5, xpReward: 25),
          AchievementLevel(level: 2, title: 'Arc-en-ciel II', description: 'Spotter une voiture de 8 couleurs différentes', target: 8, xpReward: 75),
          AchievementLevel(level: 3, title: 'Le Spectre Complet', description: 'Spotter une voiture de 12 couleurs différentes', target: 12, xpReward: 150),
      ]),
      Achievement(id: 'electric_pioneer', icon: Icons.electric_car, levels: [
          AchievementLevel(level: 1, title: 'Pionnier de l\'Électrique', description: 'Spotter 5 voitures électriques', target: 5, xpReward: 30),
          AchievementLevel(level: 2, title: 'Volt-Face', description: 'Spotter 20 voitures électriques', target: 20, xpReward: 100),
          AchievementLevel(level: 3, title: 'Gourou du Silence', description: 'Spotter 50 voitures électriques', target: 50, xpReward: 200),
      ]),
      Achievement(id: 'horsepower_king', icon: Icons.speed, levels: [
          AchievementLevel(level: 1, title: 'Gros Moteur', description: 'Spotter une voiture de plus de 400ch', target: 1, xpReward: 40),
          AchievementLevel(level: 2, title: 'Cavalerie Lourde', description: 'Spotter une voiture de plus de 600ch', target: 1, xpReward: 80),
          AchievementLevel(level: 3, title: 'Club des 800', description: 'Spotter une voiture de plus de 800ch', target: 1, xpReward: 150),
      ]),
      Achievement(id: 'lightweight_fan', icon: Icons.eco_outlined, levels: [
          AchievementLevel(level: 1, title: 'Poids Plume', description: 'Spotter une voiture de moins de 1000kg', target: 1, xpReward: 30),
          AchievementLevel(level: 2, title: 'Aérodynamique', description: 'Spotter 5 voitures de moins de 1000kg', target: 5, xpReward: 100),
          AchievementLevel(level: 3, title: 'Light is Right', description: 'Spotter 10 voitures de moins de 1000kg', target: 10, xpReward: 200),
      ]),
      Achievement(id: 'loyal_spotter', icon: Icons.repeat_one, levels: [
          AchievementLevel(level: 1, title: 'Fidèle au Poste', description: 'Spotter 3 fois le même modèle de voiture', target: 3, xpReward: 20),
          AchievementLevel(level: 2, title: 'Habitué', description: 'Spotter 5 fois le même modèle', target: 5, xpReward: 50),
          AchievementLevel(level: 3, title: 'Déjà-vu', description: 'Spotter 10 fois le même modèle', target: 10, xpReward: 100),
      ]),
      Achievement(id: 'porsche_911_fan', icon: Icons.favorite, levels: [
          AchievementLevel(level: 1, title: 'Fan de 911', description: 'Spotter 3 modèles de Porsche 911 différents', target: 3, xpReward: 50),
          AchievementLevel(level: 2, title: 'Expert en 911', description: 'Spotter 5 modèles de 911 différents', target: 5, xpReward: 100),
          AchievementLevel(level: 3, title: 'Neunelfer', description: 'Spotter 10 modèles de 911 différents', target: 10, xpReward: 200),
      ]),
      Achievement(id: 'same_day_spot', icon: Icons.calendar_today, levels: [
          AchievementLevel(level: 1, title: 'Journée Fructueuse', description: 'Spotter 5 voitures en une seule journée', target: 1, xpReward: 50),
      ]),
      Achievement(id: 'first_spot', icon: Icons.flag, levels: [
          AchievementLevel(level: 1, title: 'Le Début d\'une Passion', description: 'Spottez votre toute première voiture', target: 1, xpReward: 10),
      ]),
      Achievement(id: 'photographer', icon: Icons.photo_camera, levels: [
          AchievementLevel(level: 1, title: 'Photographe I', description: 'Ajouter 1 photo personnalisée', target: 1, xpReward: 10),
          AchievementLevel(level: 2, title: 'Photographe II', description: 'Ajouter 10 photos personnalisées', target: 10, xpReward: 50),
          AchievementLevel(level: 3, title: 'Reporter Automobile', description: 'Ajouter 25 photos personnalisées', target: 25, xpReward: 100),
      ]),
    ];
  }
  
  // ========================== AJOUT : FONCTION UTILITAIRE SÉCURISÉE ==========================
  /// Tente de convertir une valeur (String, int, double) en int de manière sécurisée.
  /// Gère les chaînes de caractères non numériques (comme "non renseigné") en retournant une valeur par défaut.
  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // Tente de parser la chaîne. Si ça échoue, retourne la valeur par défaut.
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }
  // =========================================================================================

  void _calculateProgress(Achievement achievement) {
    int progress = 0;
    switch (achievement.id) {
      case 'car_count': progress = spottedCars.length; break;
      case 'brand_diversity': progress = _uniqueBrandIds.length; break;
      case 'model_diversity': progress = _uniqueModelIds.length; break;
      case 'french_specialist': progress = _countCarsByCountry('France'); break;
      case 'italian_aficionado': progress = _countCarsByCountry('Italie'); break;
      case 'german_engineer': progress = _countCarsByCountry('Allemagne'); break;
      case 'japanese_legend': progress = _countCarsByCountry('Japon'); break;
      case 'american_muscle': progress = _countCarsByCountry('États-Unis'); break;
      case 'british_elegance': progress = _countCarsByCountry('Royaume-Uni'); break;
      case 'unicorn_hunter':
        List<String> rareBrands = ['ferrari', 'lamborghini', 'bugatti', 'koenigsegg', 'pagani', 'mclaren', 'aston-martin', 'rolls-royce'];
        progress = spottedCars.where((car) => rareBrands.contains(car['brandId'])).length;
        break;
      case 'electric_pioneer':
        progress = spottedCars.where((car) {
          final modelData = _getModelData(car);
          return modelData?['type_carburant'] == 'Électrique';
        }).length;
        break;
      case 'vintage_lover':
        progress = spottedCars.where((car) {
            final modelData = _getModelData(car);
            if (modelData == null) return false;
            final yearString = (modelData['production_years'] ?? '9999').split(' - ')[0];
            final startYear = int.tryParse(yearString) ?? 9999;
            return startYear < 1990;
        }).length;
        break;
      case 'color_collector':
        progress = spottedCars.map((car) => car['color']).where((c) => c != null).toSet().length;
        break;
      
      // ========================== MODIFICATION : UTILISATION DE _parseInt ==========================
      case 'horsepower_king':
        int level = 0;
        if (spottedCars.any((car) => _parseInt(_getModelData(car)?['puissance_ch']) >= 400)) level++;
        if (spottedCars.any((car) => _parseInt(_getModelData(car)?['puissance_ch']) >= 600)) level++;
        if (spottedCars.any((car) => _parseInt(_getModelData(car)?['puissance_ch']) >= 800)) level++;
        progress = level;
        break;
      case 'lightweight_fan':
        progress = spottedCars.where((car) => _parseInt(_getModelData(car)?['poids_kg'], defaultValue: 9999) < 1000).length;
        break;
      // =========================================================================================

      case 'loyal_spotter':
        final allModelIds = spottedCars.where((c) => c['modelId'] != null).map((car) => car['modelId'] as String).toList();
        final counts = <String, int>{};
        for (var id in allModelIds) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
        progress = counts.values.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);
        break;
      case 'porsche_911_fan':
        progress = spottedCars.where((car) => (car['modelId'] as String?)?.contains('porsche_911') ?? false).toSet().length;
        break;
      case 'same_day_spot':
        final spotsByDay = <String, int>{};
        for(var car in spottedCars) {
            if (car['spottedAt'] is Timestamp) {
              final date = (car['spottedAt'] as Timestamp).toDate();
              final dayKey = "${date.year}-${date.month}-${date.day}";
              spotsByDay[dayKey] = (spotsByDay[dayKey] ?? 0) + 1;
            }
        }
        progress = spotsByDay.values.any((count) => count >= 5) ? 1 : 0;
        break;
      case 'first_spot':
        progress = spottedCars.isNotEmpty ? 1 : 0;
        break;
      case 'photographer':
        progress = spottedCars.where((car) => car['userPhotoUrl'] != null).length;
        break;
    }
    
    achievement.currentProgress = progress;
    achievement.unlockedLevel = 0;
    for (var level in achievement.levels) {
      if (progress >= level.target) {
        achievement.unlockedLevel = level.level;
      } else {
        break;
      }
    }
  }

  int _countCarsByCountry(String country) {
    final countryBrandIds = allBrands.where((b) => b['pays'] == country).map((b) => b['id']).toSet();
    return spottedCars.where((car) => countryBrandIds.contains(car['brandId'])).length;
  }

  Map<String, dynamic>? _getModelData(Map<String, dynamic> spottedCar) {
    if (spottedCar['isCatalogued'] != true) {
      return null;
    }
    return spottedCar;
  }
}