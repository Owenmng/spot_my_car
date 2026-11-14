import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/notification_service.dart';

/// Notifications push (gratuites, via Firebase Cloud Messaging) :
/// demande d'ami, ami accepté, défi en duel, duel accepté.
/// Le serveur vérifie que l'événement existe vraiment avant d'envoyer.
class PushService {
  PushService._();

  static bool _started = false;

  static Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    final m = FirebaseMessaging.instance;
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) return;
      try {
        final t = await m.getToken();
        if (t != null) await _save(u.uid, t);
      } catch (e) {
        debugPrint('push: $e');
      }
    });
    m.onTokenRefresh.listen((t) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) unawaited(_save(uid, t));
    });
    // Appli ouverte : Android n'affiche rien tout seul, on montre une notification locale.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      NotificationService.instance.showNow(msg.hashCode & 0x7fffffff, n.title ?? 'Spot My Car', n.body ?? '', social: true);
    });
  }

  static Future<void> _save(String uid, String token) => FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

  /// Prévient l'autre joueur. Silencieux en cas d'échec : la notif est un bonus.
  static void notify(String kind, String ref) {
    unawaited(BackendService.instance.call('push.notify', {'kind': kind, 'ref': ref}).then((_) {}, onError: (_) {}));
  }
}
