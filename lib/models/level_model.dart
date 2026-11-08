import 'package:spot_my_car/l10n/i18n.dart';

class Level {
  final int level;
  final String _title;
  final int xpRequired;

  const Level(this.level, this._title, this.xpRequired);

  String get title => tr(_title);
}

/// Courbe progressive : les premiers niveaux arrivent vite pour accrocher,
/// puis chaque palier demande nettement plus que le précédent (≈ ×1,45).
const List<Level> kLevels = [
  Level(1, 'Rookie', 0),
  Level(2, 'Spotter', 120),
  Level(3, 'Curieux', 300),
  Level(4, 'Amateur éclairé', 600),
  Level(5, 'Passionné', 1000),
  Level(6, 'Connaisseur', 1600),
  Level(7, 'Œil affûté', 2400),
  Level(8, 'Expert', 3500),
  Level(9, 'Chasseur', 5000),
  Level(10, 'Pro du trottoir', 7000),
  Level(11, 'Traqueur', 9700),
  Level(12, 'Collectionneur', 13300),
  Level(13, 'Maître spotteur', 18000),
  Level(14, 'Légende', 24500),
  Level(15, 'Icône', 33000),
  Level(16, 'Mythe vivant', 45000),
];

Level levelForXp(int xp) {
  var current = kLevels.first;
  for (final l in kLevels) {
    if (xp >= l.xpRequired) {
      current = l;
    } else {
      break;
    }
  }
  return current;
}

Level? nextLevel(Level l) => l.level < kLevels.length ? kLevels[l.level] : null;

/// Progression (0 → 1) vers le niveau suivant.
double levelProgress(int xp) {
  final l = levelForXp(xp);
  final n = nextLevel(l);
  if (n == null) return 1;
  return ((xp - l.xpRequired) / (n.xpRequired - l.xpRequired)).clamp(0.0, 1.0);
}
