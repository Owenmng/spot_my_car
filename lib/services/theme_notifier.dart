import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/theme/app_theme.dart';

class AppTheme {
  final String name;
  final Color accent;
  final ThemeData themeData;

  AppTheme(this.name, this.accent) : themeData = buildAppTheme(accent);
}

class ThemeNotifier with ChangeNotifier {
  static const _prefsKey = 'selected_theme';

  static final List<AppTheme> _availableThemes =
      accentChoices.map((c) => AppTheme(c.name, c.color)).toList();

  AppTheme _currentTheme;

  ThemeNotifier._(this._currentTheme);

  static Future<ThemeNotifier> create() async {
    AppTheme initial = _availableThemes.first;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      initial = _availableThemes.firstWhere(
        (t) => t.name == saved,
        orElse: () => _availableThemes.first,
      );
    } catch (_) {}
    return ThemeNotifier._(initial);
  }

  ThemeData get currentThemeData => _currentTheme.themeData;
  AppTheme get currentAppTheme => _currentTheme;
  Color get accent => _currentTheme.accent;
  List<AppTheme> get availableThemes => _availableThemes;

  void setTheme(AppTheme newTheme) {
    if (newTheme.name == _currentTheme.name) return;
    _currentTheme = newTheme;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_prefsKey, newTheme.name));
  }
}
