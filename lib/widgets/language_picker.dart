import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Grille de langues (drapeau + nom). Le changement est immédiat.
class LanguageGrid extends StatelessWidget {
  final VoidCallback? onChanged;
  const LanguageGrid({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: I18n.instance,
      builder: (context, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in I18n.languages)
            Pressable(
              onTap: () async {
                HapticFeedback.selectionClick();
                await I18n.instance.setLanguage(l.code);
                onChanged?.call();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: I18n.instance.code == l.code ? accent.withValues(alpha: 0.14) : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: I18n.instance.code == l.code ? accent : AppColors.line, width: I18n.instance.code == l.code ? 1.6 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(l.name, style: AppText.body(14, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Feuille de choix de langue (paramètres, écran de connexion).
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Langue'), style: AppText.display(24)),
            const SizedBox(height: 14),
            LanguageGrid(onChanged: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ),
  );
}
