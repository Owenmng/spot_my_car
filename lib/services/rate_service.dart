import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/contact_support_screen.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/screens/system_screens.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Propose (une seule fois, après quelques ouvertures) de noter l'appli sur Google Play.
class RateService {
  RateService._();

  static const _opens = 'rate_open_count';
  static const _first = 'rate_first_open';
  static const _done = 'rate_done';
  static const _next = 'rate_next_at';

  /// À appeler à chaque arrivée sur l'accueil.
  static Future<void> maybeAsk(BuildContext context) async {
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getInt(_opens) ?? 0) + 1;
      await p.setInt(_opens, n);
      final now = DateTime.now().millisecondsSinceEpoch;
      final first = p.getInt(_first) ?? now;
      if (!p.containsKey(_first)) await p.setInt(_first, now);
      if (p.getBool(_done) == true) return;
      if (!RemoteConfig.instance.feature('ratePrompt')) return;
      final nextAt = p.getInt(_next) ?? 6;
      final days = (now - first) / 86400000;
      if (n < nextAt || days < 2) return;
      await Future.delayed(const Duration(seconds: 4));
      if (!context.mounted) return;
      await _ask(context, p, n);
    } catch (_) {}
  }

  static Future<void> _ask(BuildContext context, SharedPreferences p, int opens) async {
    BackendService.instance.event('rate.prompt', 'ouvertures $opens');
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _RateSheet(),
    );
    if (res == 'love') {
      await p.setBool(_done, true);
      BackendService.instance.event('rate.accept');
      final review = InAppReview.instance;
      try {
        if (await review.isAvailable()) {
          await review.requestReview();
        } else {
          await openPlayStore();
        }
      } catch (_) {
        await openPlayStore();
      }
    } else if (res == 'meh') {
      await p.setBool(_done, true);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
      }
    } else {
      // Plus tard : on redemande dans une dizaine d'ouvertures, une seule fois.
      BackendService.instance.event('rate.later');
      final asked = (p.getInt('rate_asked') ?? 0) + 1;
      await p.setInt('rate_asked', asked);
      if (asked >= 2) {
        await p.setBool(_done, true);
      } else {
        await p.setInt(_next, opens + 10);
      }
    }
  }
}

class _RateSheet extends StatefulWidget {
  const _RateSheet();
  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 0;

  void _tap(int s) {
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    setState(() => _stars = s);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) Navigator.pop(context, s >= 4 ? 'love' : 'meh');
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(22, 26, 22, 18 + bottom),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFC94D).withValues(alpha: 0.15)),
            child: const Icon(Icons.star_rounded, color: Color(0xFFFFC94D), size: 44),
          ).animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack, duration: 500.ms),
          const SizedBox(height: 16),
          Text(tr('Tu aimes Spot My Car ?'), textAlign: TextAlign.center, style: AppText.display(28)),
          const SizedBox(height: 8),
          Text(tr('Ta note aide l\'appli à se faire connaître et motive l\'équipe à ajouter encore plus de voitures.'),
              textAlign: TextAlign.center, style: AppText.body(14.5, color: AppColors.inkSoft)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => _tap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: i <= _stars ? 1.15 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: i <= _stars ? const Color(0xFFFFC94D) : AppColors.inkMuted),
                    ),
                  ),
                ).animate(delay: (80 * i).ms).fadeIn().slideY(begin: 0.4, end: 0),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(onPressed: () => Navigator.pop(context, 'later'), style: TextButton.styleFrom(foregroundColor: accent), child: Text(tr('Plus tard'))),
        ],
      ),
    );
  }
}
