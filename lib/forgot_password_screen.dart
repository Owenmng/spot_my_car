import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/code_input.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Mot de passe oublié en 3 étapes : e-mail → code reçu → nouveau mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  final _codeKey = GlobalKey<CodeInputState>();

  int _step = 0;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String _code = '';
  String _sentTo = '';
  int _cooldown = 0;
  Timer? _timer;
  bool _offerLink = false;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  void _cool(int s) {
    _timer?.cancel();
    setState(() => _cooldown = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = (_cooldown - 1).clamp(0, 999));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = tr('Entre une adresse e-mail valide.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _offerLink = false;
    });
    try {
      final r = await BackendService.instance.sendResetCode(email);
      if (!mounted) return;
      _sentTo = r.sentTo;
      _cool(r.cooldown);
      setState(() => _step = 1);
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.code == 'cooldown') {
        _cool(int.tryParse(e.detail ?? '') ?? 30);
        setState(() => _step = 1);
      } else {
        setState(() {
          _error = e.message;
          _offerLink = e.code == 'network' || e.code == 'server_error' || e.code == 'mail_quota';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkCode(String code) async {
    if (_busy || code.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BackendService.instance.checkResetCode(_email.text.trim(), code);
      if (!mounted) return;
      _code = code;
      setState(() => _step = 2);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _codeKey.currentState?.clear(error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final p = _pwd.text;
    if (p.length < 6) return setState(() => _error = tr('Choisis un mot de passe d\'au moins 6 caractères.'));
    if (p != _pwd2.text) return setState(() => _error = tr('Les deux mots de passe ne correspondent pas.'));
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BackendService.instance.applyReset(_email.text.trim(), _code, p);
      if (!mounted) return;
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      setState(() => _step = 3);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.code.startsWith('code_')) setState(() => _step = 1);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInNow() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pwd.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _linkFallback() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) showAppSnack(context, tr('Lien de réinitialisation envoyé. Regarde ta boîte mail.'), icon: Icons.mark_email_read_outlined);
    } catch (_) {
      if (mounted) showAppSnack(context, tr('Envoi impossible pour le moment.'), icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 1 || _step == 2) {
              setState(() {
                _step -= 1;
                _error = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(tr('Mot de passe oublié')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Steps(step: _step.clamp(0, 2), done: _step == 3, accent: accent),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: c),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _body(accent)),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: AppText.body(13.5, color: AppColors.danger, weight: FontWeight.w600))),
                          ],
                        ),
                      ),
              ),
              if (_offerLink && _step == 0)
                TextButton(onPressed: _linkFallback, child: Text(tr('Recevoir plutôt un lien par e-mail'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String t, String s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: AppText.display(30)),
          const SizedBox(height: 8),
          Text(s, style: AppText.body(15, color: AppColors.inkSoft)),
          const SizedBox(height: 24),
        ],
      );

  Widget _button(String label, VoidCallback? onTap) => ElevatedButton(
        onPressed: _busy ? null : onTap,
        style: ElevatedButton.styleFrom(minimumSize: const Size(64, 54)),
        child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(label),
      );

  Widget _body(Color accent) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(tr('On te renvoie les clés'), tr('Entre l\'adresse de ton compte : tu vas recevoir un code à 6 chiffres pour choisir un nouveau mot de passe.')),
            TextField(
              controller: _email,
              autofocus: _email.text.isEmpty,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _sendCode(),
              decoration: InputDecoration(labelText: tr('E-mail'), prefixIcon: const Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 18),
            _button(tr('Recevoir le code'), _sendCode),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(tr('Saisis le code'), tr('Si un compte existe pour {0}, un code vient de partir. Il est valable 15 minutes.', [_sentTo.isEmpty ? _email.text.trim() : _sentTo])),
            CodeInput(key: _codeKey, onCompleted: _checkCode, enabled: !_busy),
            const SizedBox(height: 22),
            _button(tr('Continuer'), () => _checkCode(_codeKey.currentState?.value ?? '')),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _cooldown > 0 || _busy ? null : _sendCode,
                child: Text(_cooldown > 0 ? tr('Renvoyer le code dans {0} s', [_cooldown]) : tr('Renvoyer le code')),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(tr('Nouveau mot de passe'), tr('Au moins 6 caractères. Évite celui que tu utilises ailleurs.')),
            TextField(
              controller: _pwd,
              autofocus: true,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('Nouveau mot de passe'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _Strength(password: _pwd.text),
            const SizedBox(height: 12),
            TextField(
              controller: _pwd2,
              obscureText: _obscure,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(labelText: tr('Confirme le mot de passe'), prefixIcon: const Icon(Icons.lock_reset_rounded)),
            ),
            const SizedBox(height: 18),
            _button(tr('Enregistrer'), _apply),
          ],
        );
      default:
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withValues(alpha: 0.15), border: Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 2)),
              child: Icon(Icons.lock_open_rounded, size: 48, color: AppColors.success),
            ).animate().scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 22),
            Text(tr('C\'est réglé !'), style: AppText.display(32)),
            const SizedBox(height: 8),
            Text(tr('Ton mot de passe a été changé. Un e-mail de confirmation t\'a été envoyé.'), textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.inkSoft)),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, child: _button(tr('Me connecter'), _signInNow)),
          ],
        );
    }
  }
}

class _Steps extends StatelessWidget {
  final int step;
  final bool done;
  final Color accent;
  const _Steps({required this.step, required this.done, required this.accent});

  @override
  Widget build(BuildContext context) {
    final labels = [tr('E-mail'), tr('Code'), tr('Mot de passe')];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 5,
                  decoration: BoxDecoration(
                    color: done || i < step ? AppColors.success : i == step ? accent : AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: AppText.label(11, color: i <= step || done ? AppColors.ink : AppColors.inkMuted)),
              ],
            ),
          ),
          if (i < 2) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Strength extends StatelessWidget {
  final String password;
  const _Strength({required this.password});

  @override
  Widget build(BuildContext context) {
    var s = 0;
    if (password.length >= 6) s++;
    if (password.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    final level = password.isEmpty ? 0 : (s <= 1 ? 1 : s <= 3 ? 2 : 3);
    final colors = [AppColors.line, AppColors.danger, AppColors.warning, AppColors.success];
    final names = ['', tr('Faible'), tr('Correct'), tr('Solide')];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(color: i <= level ? colors[level] : AppColors.line, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(width: 6),
        ],
        SizedBox(width: 64, child: Text(names[level], textAlign: TextAlign.right, style: AppText.label(11, color: colors[level]))),
      ],
    );
  }
}
