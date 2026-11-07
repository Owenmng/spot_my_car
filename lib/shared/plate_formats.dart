// Fichier: lib/shared/plate_formats.dart

// 'A' = Lettre (A-Z), '#' = Chiffre (0-9)
// Tous les autres caractères (espace, tiret) sont des séparateurs fixes.
const Map<String, String> plateFormats = {
  'FR': 'AA-###-AA',
  'DE': 'A AA ####',  // Format simplifié, la ville peut avoir 1 à 3 lettres
  'IT': 'AA ### AA',
  'ES': '#### AAA',
  'GB': 'AA## AAA',
  'BE': '#-AAA-###',
  'CH': 'AA ######',
  'LU': 'AA ####',
  'AT': 'A ##### A',  // Format simplifié, la ville peut avoir 1 à 2 lettres
  'US': 'AAA ####',   // Format très variable, ceci est un exemple commun
  'CA': 'AAAA ###',   // Format très variable, ceci est un exemple commun
};