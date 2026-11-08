import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une langue proposée dans l'appli.
class AppLanguage {
  final String code;
  final String name;
  final String flag;
  final String dateLocale;
  const AppLanguage(this.code, this.name, this.flag, this.dateLocale);
}

/// Traductions de l'interface. Le texte source (français) sert de clé :
/// `tr('Bonjour {0}', [pseudo])` → « Hello Owen » en anglais.
class I18n extends ChangeNotifier {
  I18n._();
  static final I18n instance = I18n._();

  /// Langues dont la traduction est complète (les autres arrivent avec une mise à jour).
  static const ready = {'fr', 'en'};

  static const allLanguages = [
    AppLanguage('fr', 'Français', '🇫🇷', 'fr_FR'),
    AppLanguage('en', 'English', '🇬🇧', 'en_US'),
    AppLanguage('es', 'Español', '🇪🇸', 'es_ES'),
    AppLanguage('de', 'Deutsch', '🇩🇪', 'de_DE'),
    AppLanguage('it', 'Italiano', '🇮🇹', 'it_IT'),
    AppLanguage('pt', 'Português', '🇧🇷', 'pt_BR'),
  ];

  static final languages = [for (final l in allLanguages) if (ready.contains(l.code)) l];

  static const _prefKey = 'app_language';

  String _code = 'fr';
  Map<String, String> _map = const {};

  String get code => _code;
  AppLanguage get language => languages.firstWhere((l) => l.code == _code, orElse: () => languages.first);
  String get dateLocale => language.dateLocale;
  Locale get locale => Locale(_code);
  List<Locale> get supportedLocales => [for (final l in languages) Locale(l.code)];

  /// Langue enregistrée, sinon celle du téléphone si elle est proposée, sinon le français.
  Future<void> init() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(_prefKey);
    } catch (_) {}
    final device = ui.PlatformDispatcher.instance.locale.languageCode;
    final pick = saved ?? device;
    final code = ready.contains(pick) ? pick : (device == 'fr' ? 'fr' : 'en');
    await _load(code);
  }

  Future<void> _load(String code) async {
    _code = code;
    if (code == 'fr') {
      _map = const {};
      return;
    }
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      _map = Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      _map = const {};
    }
  }

  Future<void> setLanguage(String code) async {
    if (code == _code) return;
    await _load(code);
    try {
      (await SharedPreferences.getInstance()).setString(_prefKey, code);
    } catch (_) {}
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({'language': code}, SetOptions(merge: true)).catchError((_) {});
    }
    notifyListeners();
    // Tout l'arbre relit ses textes, sans perdre la navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    });
  }

  String t(String source, [List<Object?> args = const []]) {
    var out = _map[source];
    if (out == null || out.isEmpty) out = source;
    for (var i = 0; i < args.length; i++) {
      out = out!.replaceAll('{$i}', '${args[i]}');
    }
    return out!;
  }
}

/// Raccourci de traduction utilisé dans toute l'interface.
String tr(String source, [List<Object?> args = const []]) => I18n.instance.t(source, args);
