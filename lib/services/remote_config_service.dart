import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spot_my_car/l10n/i18n.dart';

/// Réglages pilotés depuis la console d'administration (document Firestore `config/app`).
/// Tout a une valeur par défaut : sans réseau, l'appli fonctionne normalement.
class RemoteConfig extends ChangeNotifier {
  RemoteConfig._();
  static final instance = RemoteConfig._();

  static const _defaults = <String, bool>{
    'blindTest': true,
    'duels': true,
    'community': true,
    'map': true,
    'plateLookup': true,
    'aiRecognition': true,
    'ratePrompt': true,
    'tutorial': true,
    'emailVerification': true,
  };

  Map<String, dynamic> _data = const {};
  StreamSubscription? _sub;
  int build = 0;
  String version = '';

  static const adminEmails = {'owen.mengual@gmail.com'};

  bool feature(String key) {
    final f = _data['features'];
    if (f is Map && f[key] is bool) return f[key] as bool;
    return _defaults[key] ?? true;
  }

  bool get isAdmin => adminEmails.contains(FirebaseAuth.instance.currentUser?.email?.toLowerCase());
  bool get maintenance => _data['maintenance'] == true && !isAdmin;
  String get maintenanceMessage => (_data['maintenanceMessage'] as String?)?.trim().isNotEmpty == true
      ? _data['maintenanceMessage'] as String
      : tr('Spot My Car fait une petite révision au garage. On revient très vite !');
  String get announcement => (_data['announcement'] as String?)?.trim() ?? '';
  String get announcementId => '${_data['announcementId'] ?? ''}';
  String get announcementLevel => '${_data['announcementLevel'] ?? 'info'}';
  int get minVersion => (_data['minVersion'] as num?)?.toInt() ?? 0;
  int get latestVersion => (_data['latestVersion'] as num?)?.toInt() ?? 0;
  bool get mustUpdate => build > 0 && minVersion > build;
  bool get canUpdate => build > 0 && latestVersion > build;
  String get updateMessage => (_data['updateMessage'] as String?)?.trim().isNotEmpty == true
      ? _data['updateMessage'] as String
      : tr('Une nouvelle version de Spot My Car est disponible.');

  Future<void> start() async {
    try {
      final info = await PackageInfo.fromPlatform();
      build = int.tryParse(info.buildNumber) ?? 0;
      version = info.version;
    } catch (_) {}
    _sub ??= FirebaseFirestore.instance.collection('config').doc('app').snapshots().listen((s) {
      _data = s.data() ?? const {};
      notifyListeners();
    }, onError: (_) {});
  }

  /// Note la présence du joueur (pour les statistiques de la console). Une fois par lancement.
  bool _presenceDone = false;
  Future<void> touchPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _presenceDone) return;
    _presenceDone = true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'appVersion': version.isEmpty ? null : '$version+$build',
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      }, SetOptions(merge: true));
    } catch (_) {
      _presenceDone = false;
    }
  }
}
