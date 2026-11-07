import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Apparence : une ambiance (sombre, bleu nuit, graphite, clair) et une couleur d'accent.
class ThemeNotifier with ChangeNotifier {
  static const _accentKey = 'selected_theme';
  static const _paletteKey = 'selected_palette';

  AccentChoice _accent;
  AppPalette _palette;
  late ThemeData _data;

  ThemeNotifier._(this._accent, this._palette) {
    _data = buildAppTheme(_accent.color, _palette);
  }

  static Future<ThemeNotifier> create() async {
    var accent = accentChoices.first;
    var palette = palettes.first;
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = prefs.getString(_accentKey);
      final p = prefs.getString(_paletteKey);
      accent = accentChoices.firstWhere((c) => c.name == a, orElse: () => accentChoices.first);
      palette = palettes.firstWhere((x) => x.id == p, orElse: () => palettes.first);
    } catch (_) {}
    return ThemeNotifier._(accent, palette);
  }

  ThemeData get currentThemeData => _data;
  Color get accent => _accent.color;
  AccentChoice get accentChoice => _accent;
  AppPalette get palette => _palette;

  void setAccent(AccentChoice a) {
    if (a.name == _accent.name) return;
    _accent = a;
    _apply();
    SharedPreferences.getInstance().then((p) => p.setString(_accentKey, a.name));
  }

  void setPalette(AppPalette p) {
    if (p.id == _palette.id) return;
    _palette = p;
    _apply();
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_paletteKey, p.id));
  }

  void _apply() {
    _data = buildAppTheme(_accent.color, _palette);
    notifyListeners();
    // Les couleurs sont lues au moment du build : on redessine tout l'arbre,
    // sans perdre la navigation ni l'état des écrans.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    });
  }
}
