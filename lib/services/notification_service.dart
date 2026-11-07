import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
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

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Rappels de spot',
      channelDescription: 'Défi du jour, série en cours et bilan de la semaine',
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
    final signature = '${DailyChallenge.todayKey()}|$spottedToday|$streak|${cars.length}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    try {
      await _plugin.cancelAll();

      // Défi du jour, à 12 h 30 pour les 3 prochains jours (le défi change chaque jour).
      for (var d = 0; d < 3; d++) {
        final day = DateTime(now.year, now.month, now.day + d, 12, 30);
        if (day.isBefore(now) || (d == 0 && spottedToday)) continue;
        final c = DailyChallenge.forDay(day);
        await _schedule(100 + d, day, 'Défi du jour : ${c.title}', '${c.hint} · +${c.reward} XP');
      }

      // Série en danger, à 19 h, si rien n'a été spotté aujourd'hui.
      if (streak > 0 && !spottedToday) {
        final evening = DateTime(now.year, now.month, now.day, 19);
        if (evening.isAfter(now)) {
          await _schedule(200, evening, 'Ta série de $streak jour${streak > 1 ? 's' : ''} est en jeu 🔥', "Un seul spot avant minuit et elle continue.");
        }
      }

      // Rappel de retour si l'appli n'est pas rouverte pendant 3 jours.
      await _schedule(300, DateTime(now.year, now.month, now.day + 3, 18), 'Les rues ne se spottent pas toutes seules', 'Une nouvelle carte t’attend peut-être au coin de la rue.');

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
          'Ton bilan de la semaine',
          weekCount == 0 ? 'Aucun spot cette semaine… dimanche, c’est le jour des belles sorties !' : '$weekCount spot${weekCount > 1 ? 's' : ''} cette semaine. Viens voir ta progression.',
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
  Future<void> showNow(int id, String title, String body) async {
    await init();
    if (!_ready || !_enabled) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
    } catch (_) {}
  }
}
