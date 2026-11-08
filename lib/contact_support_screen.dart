import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/shared/app_constants.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Contact support : le message part directement par e-mail, mis en forme,
/// avec le contexte utile (version, compte) pour répondre vite.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static Map<String, (String, IconData)> get _topics => {
    'bug': (tr('Un bug'), Icons.bug_report_outlined),
    'idea': (tr('Une idée'), Icons.lightbulb_outline_rounded),
    'car': (tr('Voiture ou photo'), Icons.directions_car_outlined),
    'account': (tr('Mon compte'), Icons.person_outline_rounded),
    'other': (tr('Autre'), Icons.chat_bubble_outline_rounded),
  };

  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _topic = 'bug';
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _context() async {
    final user = FirebaseAuth.instance.currentUser;
    final info = await PackageInfo.fromPlatform();
    String pseudo = '—';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      pseudo = (doc.data()?['pseudo'] as String?) ?? '—';
    } catch (_) {}
    return {
      'Pseudo': pseudo,
      'E-mail du joueur': user?.email ?? '—',
      'Identifiant': user?.uid ?? '—',
      'Version': '${info.version} (${info.buildNumber})',
      'Système': kIsWeb ? 'web' : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    };
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final ctx = await _context();
    final topic = _topics[_topic]!.$1;
    final subject = tr('[Spot My Car · {0}] {1}', [topic, _subject.text.trim()]);

    var ok = false;
    try {
      final res = await http
          .post(
            Uri.parse(AppConstants.supportRelay),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Origin': 'https://formsubmit.co',
              'Referer': 'https://formsubmit.co/',
            },
            body: jsonEncode({
              '_subject': subject,
              '_template': 'table',
              '_captcha': 'false',
              if (ctx['E-mail du joueur'] != '—') '_replyto': ctx['E-mail du joueur'],
              'Catégorie': topic,
              'Objet': _subject.text.trim(),
              'Message': _message.text.trim(),
              ...ctx,
            }),
          )
          .timeout(const Duration(seconds: 20));
      ok = res.statusCode == 200 && '${jsonDecode(res.body)['success']}' == 'true';
    } catch (_) {}

    if (!mounted) return;
    if (ok) {
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      setState(() {
        _sending = false;
        _sent = true;
      });
      return;
    }

    // Pas d'appli mail externe : on reste dans Spot My Car et on propose de réessayer.
    setState(() => _sending = false);
    showAppSnack(context, tr('Le message n\'est pas parti (connexion ?). Réessaie dans un instant.'), icon: Icons.wifi_off_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Contacter le support'))),
      body: _sent
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_read_outlined, size: 42, color: AppColors.success),
                    ).animate().scale(curve: Curves.easeOutBack, duration: 450.ms),
                    const SizedBox(height: 20),
                    Text(tr('Message envoyé'), style: AppText.display(28)),
                    const SizedBox(height: 8),
                    Text(tr('Merci ! On te répond par e-mail, en général sous 48 h.'), textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.inkSoft)),
                    const SizedBox(height: 28),
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(tr('Retour'))),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Text(tr('Une question, un bug, une idée ?'), style: AppText.display(26)),
                  const SizedBox(height: 6),
                  Text(tr('Écris ton message ici, l’équipe Spot My Car te répond par e-mail.'), style: AppText.body(14, color: AppColors.inkSoft)),
                  const SizedBox(height: 20),
                  Text('SUJET', style: AppText.label(11, color: AppColors.inkMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _topics.entries)
                        ChoiceChip(
                          avatar: Icon(e.value.$2, size: 16, color: _topic == e.key ? Theme.of(context).colorScheme.onPrimary : accent),
                          label: Text(e.value.$1),
                          selected: _topic == e.key,
                          onSelected: (_) => setState(() => _topic = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _subject,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    decoration: InputDecoration(labelText: tr('Objet'), prefixIcon: Icon(Icons.short_text_rounded), counterText: ''),
                    validator: (v) => (v == null || v.trim().isEmpty) ? tr('Donne un titre à ton message') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _message,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 2000,
                    decoration: InputDecoration(labelText: tr('Ton message'), alignLabelWithHint: true),
                    validator: (v) => (v == null || v.trim().length < 10) ? tr('Quelques mots de plus ?') : null,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(tr('Ton pseudo, ton e-mail et la version de l’appli sont joints pour pouvoir te répondre.'), style: AppText.body(12, color: AppColors.inkMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? tr('Envoi…') : tr('Envoyer')),
                  ),
                ],
              ),
            ),
    );
  }
}
