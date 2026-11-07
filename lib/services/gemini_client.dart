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

  static const models = ['gemini-3.8-flash', 'gemini-3.5-flash-lite'];

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
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final token = await _appCheckToken();
    Object? last;

    for (final model in models) {
      final uri = Uri.parse('https://firebasevertexai.googleapis.com/v1beta/projects/${opts.projectId}/models/$model:generateContent');
      final body = {
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {
          'temperature': temperature,
          if (schema != null) 'responseMimeType': 'application/json',
          if (schema != null) 'responseSchema': schema,
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
            .timeout(timeout);
        if (res.statusCode != 200) {
          String msg = res.body;
          try {
            msg = (jsonDecode(res.body)['error']?['message'] as String?) ?? msg;
          } catch (_) {}
          last = GeminiException(res.statusCode, msg);
          debugPrint('$model -> ${res.statusCode} $msg');
          if (res.statusCode == 400) break;
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
