import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/wanted_service.dart';
import 'package:spot_my_car/widgets/daily_chest.dart';
import 'package:timezone/timezone.dart' as tz;

/// Rappels locaux (aucun serveur, donc gratuit) : défi du jour, série en danger,
/// bilan du dimanche. Tout est reprogrammé à chaque ouverture du garage.
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _prefKey = 'notifications_enabled';
  static const _channelId = 'spotmycar_reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _enabled = true;
  String? _lastSignature;

  bool get enabled => _enabled;

  static final _social = NotificationDetails(
    android: AndroidNotificationDetails(
      'spotmycar_social',
      tr('Amis et duels'),
      channelDescription: tr('Demandes d\'amis et défis en duel'),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE10600),
    ),
  );

  static final _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      tr('Rappels de spot'),
      channelDescription: tr('Défi du jour, série en cours et bilan de la semaine'),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE10600),
    ),
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      // Canal « Amis et duels » utilisé par les notifications push.
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        'spotmycar_social',
        tr('Amis et duels'),
        description: tr('Demandes d\'amis et défis en duel'),
        importance: Importance.high,
      ));
      _ready = true;
      notifyListeners();
    } catch (e) {
      debugPrint('notifications: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async {
    await init();
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await requestPermission();
      _lastSignature = null;
    } else {
      await _plugin.cancelAll();
    }
  }

  /// Reprogramme les rappels à partir des spots de l'utilisateur.
  Future<void> refresh(List<Map<String, dynamic>> cars, {required int streak}) async {
    await init();
    if (!_ready || !_enabled) return;

    final now = DateTime.now();
    final spottedToday = cars.any((c) {
      final t = (c['spottedAt'] as Timestamp?)?.toDate();
      return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
    });
    Map<String, dynamic> user = const {};
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) user = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data() ?? const {};
    } catch (_) {}
    final today = DailyChallenge.todayKey();
    final challengeDone = (user['dailyClaims'] as Map?)?[today] == true;
    final wantedDone = Wanted.claimed(user);
    final contactPending = DailyChest.pendingStreak(user);
    final signature = '$today|$spottedToday|$streak|${cars.length}|$challengeDone|$wantedDone|$contactPending';
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    try {
      await _plugin.cancelAll();

      // Défi du jour, à 12 h 30 pour les 3 prochains jours (le défi change chaque jour).
      for (var d = 0; d < 3; d++) {
        final day = DateTime(now.year, now.month, now.day + d, 12, 30);
        if (day.isBefore(now) || (d == 0 && spottedToday)) continue;
        final c = DailyChallenge.forDay(day);
        await _schedule(100 + d, day, tr('Défi du jour : {0}', [c.title]), tr('{0} · +{1} XP', [c.hint, c.reward]));
      }

      // Défi du jour qui expire : rappel à 20 h 30 s'il n'est pas validé.
      if (!challengeDone) {
        final lateEve = DateTime(now.year, now.month, now.day, 20, 30);
        if (lateEve.isAfter(now)) {
          final c = DailyChallenge.forDay(now);
          await _schedule(110, lateEve, tr('⏳ Plus que 3 h 30 pour le défi du jour'), tr('{0} · +{1} XP avant minuit', [c.title, c.reward]));
        }
      }

      // Avis de recherche : dernières heures le dimanche, nouvelle cible le lundi.
      final weekEnd = Wanted.weekEnd(now);
      final lastCall = weekEnd.subtract(const Duration(hours: 7)); // dimanche 17 h
      final b = Wanted.brand(now);
      if (!wantedDone && b != null && lastCall.isAfter(now)) {
        await _schedule(500, lastCall, tr('🎯 Avis de recherche : dernières heures'), tr('Spotte une {0} avant minuit : +{1} XP', [b['name'], Wanted.bounty]));
      }
      final nextMonday = weekEnd.add(const Duration(hours: 9, minutes: 15));
      final nb = Wanted.brand(weekEnd.add(const Duration(hours: 12)));
      if (nb != null) {
        await _schedule(501, nextMonday, tr('🎯 Nouvel avis de recherche'), tr('Cette semaine, la cible est {0}. Prime : +{1} XP.', [nb['name'], Wanted.bounty]));
      }

      // Contact du jour : rappel le matin (et en fin de journée s'il n'est pas fait).
      final nextStreak = contactPending == null ? ((user['chest'] as Map?)?['streak'] as num? ?? 0).toInt() + 1 : 1;
      await _schedule(600, DateTime(now.year, now.month, now.day + 1, 9), tr('🔑 Ton moteur t\'attend'), tr('Démarre le moteur : +{0} XP aujourd\'hui.', [DailyChest.rewardFor(nextStreak)]));
      if (contactPending != null && contactPending > 1) {
        final evening = DateTime(now.year, now.month, now.day, 18, 30);
        if (evening.isAfter(now)) {
          await _schedule(601, evening, tr('🔑 Ta série de démarrages est en jeu'), tr('Ouvre l\'appli avant minuit pour garder tes {0} jours d\'affilée.', [contactPending - 1]));
        }
      }

      // Série en danger, à 19 h, si rien n'a été spotté aujourd'hui.
      if (streak > 0 && !spottedToday) {
        final evening = DateTime(now.year, now.month, now.day, 19);
        if (evening.isAfter(now)) {
          await _schedule(200, evening, tr('Ta série de {0} jour{1} est en jeu 🔥', [streak, streak > 1 ? 's' : '']), tr('Un seul spot avant minuit et elle continue.'));
        }
      }

      // Rappel de retour si l'appli n'est pas rouverte pendant 3 jours.
      await _schedule(300, DateTime(now.year, now.month, now.day + 3, 18), tr('Les rues ne se spottent pas toutes seules'), tr('Une nouvelle carte t’attend peut-être au coin de la rue.'));

      // Bilan du dimanche à 18 h.
      final sunday = DateTime(now.year, now.month, now.day + ((DateTime.sunday - now.weekday) % 7), 18);
      final weekCount = cars.where((c) {
        final t = (c['spottedAt'] as Timestamp?)?.toDate();
        return t != null && now.difference(t).inDays < 7;
      }).length;
      if (sunday.isAfter(now)) {
        await _schedule(
          400,
          sunday,
          tr('Ton bilan de la semaine'),
          weekCount == 0 ? tr('Aucun spot cette semaine… dimanche, c’est le jour des belles sorties !') : tr('{0} spot{1} cette semaine. Viens voir ta progression.', [weekCount, weekCount > 1 ? 's' : '']),
        );
      }
    } catch (e) {
      debugPrint('notifications: $e');
    }
  }

  Future<void> _schedule(int id, DateTime local, String title, String body) => _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(local.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );

  /// Notification immédiate (ex. : nouveau duel reçu, détecté à l'ouverture).
  Future<void> showNow(int id, String title, String body, {bool social = false}) async {
    await init();
    if (!_ready || !_enabled) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: social ? _social : _details);
    } catch (_) {}
  }
}
