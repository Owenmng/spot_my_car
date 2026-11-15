import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/services/backend_service.dart';

/// Remonte les erreurs de l'appli dans la console (journal « Erreur dans l'appli »)
/// et remplace le bloc gris de Flutter par un espace vide en version Play.
class ErrorReporter {
  ErrorReporter._();

  static final _sent = <String>{};
  static String version = '';

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('permission-denied')) return;
      report(details.exception, details.stack, where: details.library);
      if (previous != null) previous(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, where: 'async');
      return true;
    };
    ErrorWidget.builder = (details) {
      if (kDebugMode) return ErrorWidget(details.exception);
      return const SizedBox.shrink();
    };
  }

  static void report(Object error, StackTrace? stack, {String? where}) {
    final msg = error.toString();
    if (msg.contains('permission-denied') || msg.contains('network') || msg.contains('unavailable')) return;
    final frame = (stack?.toString().split('\n') ?? const <String>[])
        .where((l) => l.contains('package:spot_my_car/'))
        .take(2)
        .map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').trim())
        .join(' | ');
    final detail = '${version.isEmpty ? '' : '[$version] '}${where ?? ''}: ${msg.split('\n').first} @ $frame';
    if (_sent.length >= 10 || !_sent.add(detail)) return;
    try {
      BackendService.instance.event('app.error', detail.length > 400 ? detail.substring(0, 400) : detail);
    } catch (_) {}
  }
}
