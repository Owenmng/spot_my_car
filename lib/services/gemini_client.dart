import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spot_my_car/firebase_options.dart';

class GeminiException implements Exception {
  final int status;
  final String message;
  GeminiException(this.status, this.message);

  @override
  String toString() => 'Gemini $status: $message';
}

/// Appel direct de Gemini via Firebase AI Logic (offre gratuite de l'API Gemini Developer).
class GeminiClient {
  GeminiClient._();

  /// Rapide d'abord (≈1 s), puis repli, puis le modèle lourd en dernier recours.
  static const fast = [
    ('gemini-3.5-flash-lite', {'thinkingLevel': 'MINIMAL'}),
    ('gemini-3.5-flash-lite', null),
    ('gemini-3.8-flash', {'thinkingBudget': 0}),
  ];

  /// Analyse approfondie, plus lente mais plus fine sur les cas difficiles.
  static const deep = [
    ('gemini-3.8-flash', null),
    ('gemini-3.8-flash', {'thinkingBudget': 0}),
    ('gemini-3.5-flash-lite', null),
  ];

  static Future<String?> _appCheckToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken(false).timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  static Future<String> generate({
    required List<Map<String, dynamic>> parts,
    Map<String, dynamic>? schema,
    double temperature = 0.1,
    Duration timeout = const Duration(seconds: 30),
    bool deepMode = false,
  }) async {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final token = await _appCheckToken();
    Object? last;

    for (final (model, thinking) in deepMode ? deep : fast) {
      final uri = Uri.parse('https://firebasevertexai.googleapis.com/v1beta/projects/${opts.projectId}/models/$model:generateContent');
      final body = {
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {
          'temperature': temperature,
          if (schema != null) 'responseMimeType': 'application/json',
          if (schema != null) 'responseSchema': schema,
          if (thinking != null) 'thinkingConfig': thinking,
        },
      };
      try {
        final res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': opts.apiKey,
                'X-Firebase-AppId': opts.appId,
                if (token != null) 'X-Firebase-AppCheck': token,
              },
              body: jsonEncode(body),
            )
            .timeout(deepMode && model.contains('3.8') ? const Duration(seconds: 90) : timeout);
        if (res.statusCode != 200) {
          String msg = res.body;
          try {
            msg = (jsonDecode(res.body)['error']?['message'] as String?) ?? msg;
          } catch (_) {}
          last = GeminiException(res.statusCode, msg);
          debugPrint('$model -> ${res.statusCode} $msg');
          continue;
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final parts = (data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
        final text = parts?.map((p) => p['text'] ?? '').join() ?? '';
        if (text.trim().isEmpty) {
          last = GeminiException(200, 'réponse vide');
          continue;
        }
        return text;
      } catch (e) {
        last = e;
        debugPrint('$model failed: $e');
      }
    }
    throw last ?? GeminiException(0, 'inconnue');
  }

  static Map<String, dynamic> imagePart(Uint8List bytes, {String mime = 'image/jpeg'}) => {
        'inlineData': {'mimeType': mime, 'data': base64Encode(bytes)},
      };

  static Map<String, dynamic> textPart(String text) => {'text': text};
}
