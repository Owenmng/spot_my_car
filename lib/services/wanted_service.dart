import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/services/plus_service.dart';

/// « Avis de recherche » : chaque semaine, la même marque pour tous les joueurs.
/// Le premier spot de cette marque dans la semaine rapporte une prime d'XP.
class Wanted {
  Wanted._();

  static const baseBounty = 150;

  /// Prime doublée pour les membres Spot My Car+.
  static int get bounty => baseBounty * (PlusService.instance.isPlus ? 2 : 1);

  /// Marques ni trop banales ni introuvables : on les croise en cherchant un peu.
  static const _pool = [
    'porsche', 'alfa-romeo', 'mini', 'tesla', 'jeep', 'land-rover', 'volvo', 'mazda', 'abarth', 'lexus',
    'jaguar', 'maserati', 'subaru', 'cupra', 'alpine', 'ds', 'smart', 'lancia', 'polestar', 'mg',
    'bmw', 'audi', 'mercedes-benz', 'suzuki', 'mitsubishi', 'aston-martin', 'bentley', 'lotus', 'genesis', 'lynk-and-co',
  ];

  static String brandIdFor([DateTime? date]) {
    final key = weekKey(date);
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _pool[(h * 2654435761 % 0x7fffffff) % _pool.length];
  }

  static Map<String, dynamic>? brand([DateTime? date]) {
    final id = brandIdFor(date);
    for (final b in DataManager.instance.brands) {
      if (b is Map && b['id'] == id) return Map<String, dynamic>.from(b);
    }
    return null;
  }

  /// Fin de la semaine en cours (lundi 00:00 suivant).
  static DateTime weekEnd([DateTime? now]) {
    final d = now ?? DateTime.now();
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return monday.add(const Duration(days: 7));
  }

  static bool claimed(Map<String, dynamic> userData, [DateTime? date]) =>
      (userData['wantedClaims'] as Map?)?[weekKey(date)] == true;
}
