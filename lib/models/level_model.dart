class Level {
  final int level;
  final String title;
  final int xpRequired;

  const Level(this.level, this.title, this.xpRequired);
}

const List<Level> kLevels = [
  Level(1, 'Novice du Spotting', 0),
  Level(2, 'Débutant', 100),
  Level(3, 'Amateur', 250),
  Level(4, 'Passionné', 500),
  Level(5, 'Connaisseur', 1000),
  Level(6, 'Expert', 2000),
  Level(7, "Chasseur d'Élite", 4000),
  Level(8, 'Maître Spotter', 7500),
  Level(9, 'Légende de la Route', 12000),
  Level(10, 'Dieu du Spotting', 20000),
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
