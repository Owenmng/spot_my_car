import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/auth_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/code_input.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Suppression du compte, confirmée par un code envoyé par e-mail.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _codeKey = GlobalKey<CodeInputState>();
  bool _sent = false;
  bool _busy = false;
  bool _understood = false;
  String _code = '';
  String _sentTo = '';
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await BackendService.instance.sendDeleteCode();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentTo = r.sentTo;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.code == 'cooldown') {
        setState(() => _sent = true);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_code.length != 6) {
      setState(() => _error = tr('Saisis les 6 chiffres reçus par e-mail.'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 34),
        title: Text(tr('Dernière confirmation')),
        content: Text(tr('Ton garage, tes cartes, tes photos et ta progression seront effacés pour toujours. On ne pourra rien récupérer.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(tr('Tout supprimer')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BackendService.instance.applyDelete(_code);
      try {
        await AuthService.signOut();
      } catch (_) {
        await FirebaseAuth.instance.signOut();
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
      messenger.showSnackBar(SnackBar(content: Text(tr('Ton compte a été supprimé. À bientôt peut-être !'))));
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _codeKey.currentState?.clear(error: true);
      _code = '';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.garage_rounded, tr('Ton garage et toutes tes cartes')),
      (Icons.photo_library_outlined, tr('Les photos de tes spots')),
      (Icons.emoji_events_outlined, tr('Ton XP, ton niveau et tes succès')),
      (Icons.group_outlined, tr('Tes amis, duels et classements')),
    ];
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(tr('Supprimer mon compte')), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr('Action définitive'), style: AppText.display(24))),
                  ]),
                  const SizedBox(height: 12),
                  Text(tr('En supprimant ton compte, tu perds pour toujours :'), style: AppText.body(14.5, color: AppColors.inkSoft)),
                  const SizedBox(height: 10),
                  for (final (icon, label) in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Icon(icon, size: 19, color: AppColors.ink),
                        const SizedBox(width: 10),
                        Expanded(child: Text(label, style: AppText.body(14.5, weight: FontWeight.w600))),
                      ]),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 20),
            if (!_sent) ...[
              CheckboxListTile(
                value: _understood,
                onChanged: (v) => setState(() => _understood = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tr('J\'ai compris que c\'est irréversible'), style: AppText.body(14.5, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: !_understood || _busy ? null : _send,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : const Icon(Icons.mail_lock_outlined),
                label: Text(tr('Recevoir le code de confirmation')),
                style: ElevatedButton.styleFrom(minimumSize: const Size(64, 54), backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(tr('Par sécurité, on t\'envoie un code par e-mail : la suppression n\'est possible qu\'avec ce code.'),
                  textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.inkMuted)),
            ] else ...[
              Text(tr('Code envoyé à {0}', [_sentTo.isEmpty ? (FirebaseAuth.instance.currentUser?.email ?? '') : _sentTo]),
                  textAlign: TextAlign.center, style: AppText.body(14.5, color: AppColors.inkSoft)),
              const SizedBox(height: 18),
              CodeInput(key: _codeKey, onCompleted: (c) => setState(() => _code = c), onChanged: (c) => _code = c, enabled: !_busy),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _delete,
                style: ElevatedButton.styleFrom(minimumSize: const Size(64, 54), backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(tr('Supprimer définitivement')),
              ),
              TextButton(onPressed: _busy ? null : _send, child: Text(tr('Renvoyer le code'))),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: AppText.body(13.5, color: AppColors.danger, weight: FontWeight.w600))),
                ]),
              ),
            const SizedBox(height: 26),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr('Finalement, je garde mon garage'))),
          ],
        ),
      ),
    );
  }
}
