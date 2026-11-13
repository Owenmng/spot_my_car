import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/shared/app_constants.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Parrainage : partager son code ami, ou saisir celui d'un pote (+300 XP chacun).
class ReferralScreen extends StatefulWidget {
  final Map<String, dynamic>? demoData;
  const ReferralScreen({super.key, this.demoData});

  static const reward = 300;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sponsor = await BackendService.instance.claimReferral(code);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      showAppSnack(
        context,
        sponsor.isEmpty ? tr('+{0} XP pour toi et ton parrain !', [ReferralScreen.reward]) : tr('+{0} XP pour toi et {1} !', [ReferralScreen.reward, sponsor]),
        icon: Icons.celebration_rounded,
        color: AppColors.success,
      );
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr('Une erreur est survenue. Réessaie dans un instant.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _share(String code) {
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    SharePlus.instance.share(ShareParams(
      text: tr('Viens spotter des voitures avec moi sur Spot My Car 🏎️ Entre mon code {0} dans « Parrainage » : on gagne {1} XP chacun ! {2}', [code, ReferralScreen.reward, AppConstants.playStoreUrl]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.demoData != null) return _build(context, widget.demoData!, DateTime.now());
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final created = FirebaseAuth.instance.currentUser?.metadata.creationTime ?? DateTime.now();
        return _build(context, snap.data?.data() ?? const {}, created);
      },
    );
  }

  Widget _build(BuildContext context, Map<String, dynamic> data, DateTime created) {
    final accent = Theme.of(context).colorScheme.primary;
    final code = '${data['friendId'] ?? ''}';
    final count = (data['referralCount'] as num?)?.toInt() ?? 0;
    final referred = data['referredBy'] != null;
    final canClaim = !referred && DateTime.now().difference(created).inDays < 30;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Parrainage'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Carte héros
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF0B0B10), Color.lerp(const Color(0xFF0B0B10), accent, 0.4)!]),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('INVITE TES POTES'), style: AppText.label(11.5, color: accent).copyWith(letterSpacing: 2.5)),
                const SizedBox(height: 6),
                Text(tr('+{0} XP pour toi, +{0} XP pour eux', [ReferralScreen.reward]), style: AppText.display(28, color: Colors.white)),
                const SizedBox(height: 8),
                Text(tr('Ton pote entre ton code dans les 30 jours après son inscription : vous gagnez tous les deux.'),
                    style: AppText.body(13.5, color: Colors.white70, weight: FontWeight.w600)),
                const SizedBox(height: 18),
                Text(tr('TON CODE'), style: AppText.label(10.5, color: Colors.white54)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: code.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: code));
                                HapticFeedback.selectionClick();
                                showAppSnack(context, tr('Code copié'), icon: Icons.copy_rounded);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                          child: Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(code.isEmpty ? '— — —' : _spaced(code), style: AppText.display(28, color: Colors.white).copyWith(letterSpacing: 3)),
                                ),
                              ),
                              const Icon(Icons.copy_rounded, color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: code.isEmpty ? null : () => _share(code),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(tr('Partager')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      count == 0 ? tr('Aucun filleul pour l\'instant') : tr('{0} filleul{1} · +{2} XP gagnés', [count, count > 1 ? 's' : '', count * ReferralScreen.reward]),
                      style: AppText.body(13.5, color: Colors.white, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
          const SizedBox(height: 18),
          // Étapes
          for (final (i, step) in [
            (Icons.ios_share_rounded, tr('Envoie ton code à un pote')),
            (Icons.download_rounded, tr('Il installe Spot My Car et crée son compte')),
            (Icons.redeem_rounded, tr('Il entre ton code ici : +{0} XP chacun', [ReferralScreen.reward])),
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(step.$1, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${i + 1}. ${step.$2}', style: AppText.body(14, weight: FontWeight.w600))),
                ],
              ).animate().fadeIn(delay: (120 + i * 60).ms),
            ),
          const SizedBox(height: 14),
          // Saisie d'un code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
            child: referred
                ? Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('Tu as été parrainé : ton bonus est déjà encaissé.'), style: AppText.body(14, weight: FontWeight.w600))),
                    ],
                  )
                : !canClaim
                    ? Text(tr('Le parrainage est réservé aux comptes de moins de 30 jours.'), style: AppText.body(13.5, color: AppColors.inkSoft))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('On t\'a invité ?'), style: AppText.body(16, weight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(tr('Entre le code de ton parrain pour débloquer ton bonus.'), style: AppText.body(13, color: AppColors.inkSoft)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _code,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _claim(),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z ]')), LengthLimitingTextInputFormatter(24)],
                                  style: AppText.display(20).copyWith(letterSpacing: 2),
                                  decoration: InputDecoration(hintText: '12345678', errorText: _error, errorMaxLines: 3),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _busy ? null : _claim,
                                  child: _busy
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                      : Text(tr('Valider')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  static String _spaced(String code) => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
}
