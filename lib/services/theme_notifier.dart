// Fichier: lib/services/theme_notifier.dart (Version Complète et Corrigée)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String name;
  final ThemeData themeData;
  const AppTheme(this.name, this.themeData);
}

class ThemeNotifier with ChangeNotifier {
  // La liste des thèmes est maintenant complète
  static final List<AppTheme> _availableThemes = [
    // 1. Bleu Marine -> Fond blanc froid
    AppTheme(
      'Bleu Marine',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2D3D8A),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D3D8A),
          secondary: Color(0xFF5C6BC0),
          background: Color(0xFFF5F7FA), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D3D8A),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 2. Rose Bonbon -> Fond blanc rosé
    AppTheme(
      'Rose Bonbon',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFE91E63),
        scaffoldBackgroundColor: const Color(0xFFFFF8F8), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFE91E63),
          secondary: Color(0xFFF06292),
          background: Color(0xFFFFF8F8), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE91E63),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 3. Vert Nature -> Fond blanc mentholé
    AppTheme(
      'Vert Nature',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFFF8FFF8), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF81C784),
          background: Color(0xFFF8FFF8), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 4. Sombre (appelé Nuit inversé dans ton code, mais il est sombre)
    AppTheme(
      'Nuit Inversé',
      ThemeData(
      brightness: Brightness.light, // Toujours un thème clair pour la barre de statut
      primaryColor: const Color(0xFF212121), // Noir pour les boutons, etc.
      scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Fond gris clair
      colorScheme: const ColorScheme.light(
      primary: Color(0xFF212121),       // Couleur primaire (boutons, FAB)
      secondary: Color(0xFF616161),     // Couleur secondaire
      background: Color(0xFFF5F5F5),    // Fond de l'écran
      surface: Colors.white,            // Fond des cartes
      onPrimary: Colors.white,          // Texte sur les boutons noirs (blanc)
      onSecondary: Colors.white,
      onBackground: Colors.black,       // Texte sur le fond de l'écran (noir)
      onSurface: Colors.black,          // Texte sur les cartes (noir)
      ),
      appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121), // AppBar noire
      foregroundColor: Colors.white,    // Titre et icônes de l'AppBar en blanc
      ),
      // ==========================================================
      useMaterial3: true,
      ),
      ),
    AppTheme(
      'Orange Vitalité',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFFFF7F5), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Colors.deepOrange,
          secondary: Colors.orangeAccent,
          background: Color(0xFFFFF7F5), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 6. Violet Intense -> Fond blanc lavande
    AppTheme(
      'Violet Intense',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF9F8FF), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Colors.deepPurple,
          secondary: Colors.purpleAccent,
          background: Color(0xFFF9F8FF), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 7. Gris Urbain (Le fond était déjà harmonisé)
    AppTheme(
      'Gris Urbain',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueGrey.shade800,
        scaffoldBackgroundColor: const Color(0xFFECEFF1),
        colorScheme: ColorScheme.light(
          primary: Colors.blueGrey.shade800,
          secondary: Colors.blueGrey,
          background: const Color(0xFFECEFF1),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 8. Rouge Passion -> Fond blanc cassé
    AppTheme(
      'Rouge Passion',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFD32F2F),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD32F2F),
          secondary: Color(0xFFFF5252),
          background: Color(0xFFFAFAFA), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 9. Turquoise Océan -> Fond blanc écume
    AppTheme(
      'Turquoise Océan',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF0FFFF), // MODIFIÉ
        colorScheme: const ColorScheme.light(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
          background: Color(0xFFF0FFFF), // MODIFIÉ
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
    // 10. Marron Cuir (Le fond était déjà harmonisé)
    AppTheme(
      'Marron Cuir',
      ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF795548),
        scaffoldBackgroundColor: const Color(0xFFEFEBE9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF795548),
          secondary: Color(0xFFA1887F),
          background: Color(0xFFEFEBE9),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF795548),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
    ),
  ];  AppTheme _currentTheme;

  // Constructeur privé
  ThemeNotifier._(this._currentTheme);

  // Méthode "factory" pour créer une instance de manière asynchrone
  static Future<ThemeNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('selected_theme');
    
    final initialTheme = _availableThemes.firstWhere(
      (t) => t.name == themeName,
      orElse: () => _availableThemes[0], // Thème par défaut
    );
    
    return ThemeNotifier._(initialTheme);
  }

  // Getters
  ThemeData get currentThemeData => _currentTheme.themeData;
  AppTheme get currentAppTheme => _currentTheme;
  List<AppTheme> get availableThemes => _availableThemes;

  // Méthode pour changer le thème
  void setTheme(AppTheme newTheme) {
    if (_currentTheme.name != newTheme.name) {
      _currentTheme = newTheme;
      _saveTheme(newTheme.name);
      notifyListeners();
    }
  }

  // Méthode de sauvegarde
  Future<void> _saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', themeName);
  }
}