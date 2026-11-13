import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/auth_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/code_input.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Première arrivée : on confirme que l'adresse e-mail appartient bien au joueur.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static String? _autoSentUid;

  final _codeKey = GlobalKey<CodeInputState>();
  String _sentTo = '';
  String? _error;
  bool _sending = false;
  bool _checking = false;
  bool _done = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _sentTo = email;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_autoSentUid != uid) {
      _autoSentUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int s) {
    _timer?.cancel();
    setState(() => _cooldown = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = (_cooldown - 1).clamp(0, 999));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending || _cooldown > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await BackendService.instance.sendVerifyCode();
      if (!mounted) return;
      setState(() => _sentTo = r.sentTo);
      _startCooldown(r.cooldown);
      showAppSnack(context, tr('Code envoyé ! Regarde ta boîte mail.'), icon: Icons.mark_email_read_outlined);
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.code == 'cooldown') _startCooldown(int.tryParse(e.detail ?? '') ?? 30);
      setState(() => _error = e.code == 'cooldown' ? null : e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check(String code) async {
    if (_checking || code.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await BackendService.instance.checkVerifyCode(code);
      if (!mounted) return;
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      setState(() => _done = true);
      try {
        await FirebaseAuth.instance.currentUser?.reload();
      } catch (_) {}
      // L'écran disparaît tout seul : le serveur a validé le profil.
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _codeKey.currentState?.clear(error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.9),
                  radius: 1.2,
                  colors: [accent.withValues(alpha: 0.28), AppColors.paper],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, pad.top + 18, 24, pad.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 40),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => AuthService.signOut(),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(tr('Changer de compte')),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Center(child: _Envelope(done: _done, accent: accent)),
                const SizedBox(height: 26),
                Text(
                  _done ? tr('Adresse confirmée !') : tr('Vérifie ton e-mail'),
                  textAlign: TextAlign.center,
                  style: AppText.display(34),
                ).animate(key: ValueKey(_done)).fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _done ? tr('Bienvenue dans le garage. On t\'ouvre les portes…') : tr('On t\'a envoyé un code à 6 chiffres à ')),
                    if (!_done) TextSpan(text: _sentTo, style: AppText.body(15, weight: FontWeight.w800)),
                  ]),
                  textAlign: TextAlign.center,
                  style: AppText.body(15, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 30),
                if (!_done) ...[
                  CodeInput(key: _codeKey, onCompleted: _check, enabled: !_checking),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: _error == null
                        ? const SizedBox(height: 18)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                                const SizedBox(width: 6),
                                Flexible(child: Text(_error!, textAlign: TextAlign.center, style: AppText.body(13.5, color: AppColors.danger, weight: FontWeight.w600))),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _checking ? null : () => _check(_codeKey.currentState?.value ?? ''),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(64, 54)),
                    child: _checking
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(tr('Valider')),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: _cooldown > 0 || _sending ? null : _send,
                      child: Text(_sending
                          ? tr('Envoi…')
                          : _cooldown > 0
                              ? tr('Renvoyer le code dans {0} s', [_cooldown])
                              : tr('Renvoyer le code')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined, color: AppColors.inkSoft, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('Pas reçu ? Regarde dans les spams ou l\'onglet Promotions. Le mail vient de « Spot My Car » (noreply.spotmycar@gmail.com).'),
                            style: AppText.body(13, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Envelope extends StatelessWidget {
  final bool done;
  final Color accent;
  const _Envelope({required this.done, required this.accent});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : accent;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 40)],
      ),
      child: Icon(done ? Icons.verified_rounded : Icons.mark_email_unread_rounded, size: 52, color: color),
    )
        .animate(key: ValueKey(done))
        .scale(begin: const Offset(0.6, 0.6), duration: 500.ms, curve: Curves.easeOutBack)
        .then()
        .shimmer(duration: 1400.ms, color: Colors.white24);
  }
}
