// Fichier: lib/services/user_stats_service.dart (NOUVEAU)

// Classe qui définit la structure des statistiques
class UserStats {
  final int totalSpots;
  final int uniqueModels;
  final int uniqueBrands;
  final String mostSpottedBrand;

  UserStats({
    this.totalSpots = 0,
    this.uniqueModels = 0,
    this.uniqueBrands = 0,
    this.mostSpottedBrand = "Aucune",
  });
}

// Classe qui contient la logique de calcul
class UserStatsService {
  final List<Map<String, dynamic>> spottedCars;

  UserStatsService({required this.spottedCars});

  UserStats calculateStats() {
    if (spottedCars.isEmpty) {
      return UserStats(); // Retourne des stats à zéro si le garage est vide
    }

    // Calcul des stats de base
    final int totalSpots = spottedCars.length;
    final int uniqueModels = spottedCars.map((car) => car['modelId']).toSet().length;
    final int uniqueBrands = spottedCars.map((car) => car['brandId']).toSet().length;

    // Calcul de la marque la plus spottée
    Map<String, int> brandCounts = {};
    for (var car in spottedCars) {
      // On utilise le 'brandName' pour un affichage direct
      brandCounts.update(car['brandName'], (value) => value + 1, ifAbsent: () => 1);
    }
    
    String mostSpottedBrand = "Aucune";
    if (brandCounts.isNotEmpty) {
      // On trouve l'entrée avec la plus grande valeur (le plus grand nombre de spots)
      final sortedBrands = brandCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostSpottedBrand = sortedBrands.first.key;
    }

    return UserStats(
      totalSpots: totalSpots,
      uniqueModels: uniqueModels,
      uniqueBrands: uniqueBrands,
      mostSpottedBrand: mostSpottedBrand,
    );
  }
}