import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/shared/app_constants.dart';

/// Erreur renvoyée par le serveur Spot My Car (codes e-mail, support…).
class BackendException implements Exception {
  final String code;
  final String? detail;
  BackendException(this.code, [this.detail]);

  /// Message lisible pour l'utilisateur.
  String get message {
    switch (code) {
      case 'code_wrong':
        final left = int.tryParse(detail ?? '');
        return left == null
            ? tr('Code incorrect. Vérifie les 6 chiffres reçus.')
            : left <= 1
                ? tr('Code incorrect. Dernier essai avant que le code ne soit bloqué.')
                : tr('Code incorrect. Il te reste {0} essais.', [left]);
      case 'code_expired':
        return tr('Ce code a expiré. Demande-en un nouveau.');
      case 'code_locked':
        return tr('Trop d\'essais : ce code est bloqué. Demande-en un nouveau.');
      case 'cooldown':
        return tr('Patiente {0} s avant de redemander un code.', [detail ?? '30']);
      case 'too_many':
        return tr('Trop de demandes. Réessaie dans une heure.');
      case 'mail_quota':
        return tr('Nos envois d\'e-mails sont saturés pour aujourd\'hui. Réessaie demain.');
      case 'bad_email':
        return tr('Cette adresse e-mail n\'est pas valide.');
      case 'weak_password':
        return tr('Choisis un mot de passe d\'au moins 6 caractères.');
      case 'auth_invalid':
      case 'auth_required':
        return tr('Ta session a expiré. Reconnecte-toi.');
      case 'auth_disabled':
        return tr('Ce compte a été désactivé.');
      case 'network':
        return tr('Pas de connexion au serveur. Vérifie ton réseau.');
      default:
        return tr('Une erreur est survenue. Réessaie dans un instant.');
    }
  }

  @override
  String toString() => 'BackendException($code, $detail)';
}

/// Résultat d'un envoi de code.
class CodeSent {
  final String sentTo;
  final int cooldown;
  CodeSent(this.sentTo, this.cooldown);
}

/// Client du serveur gratuit (Google Apps Script) de Spot My Car.
class BackendService {
  BackendService._();
  static final instance = BackendService._();

  final _client = http.Client();

  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}, bool withToken = true]) async {
    final payload = <String, dynamic>{'action': action, 'lang': I18n.instance.code, ...body};
    if (withToken) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) payload['idToken'] = token;
    }
    try {
      // Apps Script répond par une redirection 302 vers le résultat : on la suit à la main.
      final req = http.Request('POST', Uri.parse(AppConstants.serverUrl))
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode(payload);
      var res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 30)));
      var hops = 0;
      while ((res.statusCode == 302 || res.statusCode == 303 || res.statusCode == 301) && hops < 3) {
        final loc = res.headers['location'];
        if (loc == null) break;
        res = await _client.get(Uri.parse(loc)).timeout(const Duration(seconds: 30));
        hops++;
      }
      if (res.statusCode != 200) throw BackendException('server_error', '${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (data['ok'] != true) throw BackendException('${data['error'] ?? 'server_error'}', data['message']?.toString());
      return data;
    } on BackendException {
      rethrow;
    } on TimeoutException {
      throw BackendException('network');
    } catch (e) {
      if (e is FormatException) throw BackendException('server_error');
      throw BackendException('network');
    }
  }

  CodeSent _sent(Map<String, dynamic> r) => CodeSent('${r['sentTo'] ?? ''}', (r['cooldown'] as num?)?.toInt() ?? 45);

  // Vérification de l'adresse à l'inscription
  Future<CodeSent> sendVerifyCode() async => _sent(await call('verify.send'));
  Future<void> checkVerifyCode(String code) => call('verify.check', {'code': code});

  // Mot de passe oublié
  Future<CodeSent> sendResetCode(String email) async => _sent(await call('reset.send', {'email': email}, false));
  Future<void> checkResetCode(String email, String code) => call('reset.check', {'email': email, 'code': code}, false);
  Future<void> applyReset(String email, String code, String password) =>
      call('reset.apply', {'email': email, 'code': code, 'password': password}, false);

  // Suppression du compte
  Future<CodeSent> sendDeleteCode() async => _sent(await call('delete.send'));
  Future<void> applyDelete(String code) => call('delete.apply', {'code': code});

  // Support
  Future<String> sendSupport({required String topic, required String subject, required String message, required Map<String, String> context}) async {
    final r = await call('support.send', {'topic': topic, 'subject': subject, 'message': message, 'context': context});
    return '${r['ticket'] ?? ''}';
  }

  /// Petit événement anonyme pour la console (ne bloque jamais l'appli).
  void event(String name, [String detail = '']) {
    unawaited(call('event', {'name': name, 'detail': detail}).catchError((_) => <String, dynamic>{}));
  }
}
