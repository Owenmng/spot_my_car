import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/theme_notifier.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            "Choisis la couleur qui t'accompagne partout dans l'appli.",
            style: AppText.body(15, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          _Preview(accent: notifier.accent),
          const SizedBox(height: 28),
          Wrap(
            spacing: 14,
            runSpacing: 18,
            children: [
              for (final theme in notifier.availableThemes)
                _Swatch(
                  theme: theme,
                  selected: theme.name == notifier.currentAppTheme.name,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.setTheme(theme);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 40 - 28) / 3;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: selected ? 64 : 56,
              height: selected ? 64 : 56,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.ink : Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: selected ? 0.45 : 0.18),
                    blurRadius: selected ? 18 : 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
            ),
            const SizedBox(height: 8),
            Text(
              theme.name,
              textAlign: TextAlign.center,
              style: AppText.body(13, weight: selected ? FontWeight.w800 : FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final Color accent;
  const _Preview({required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('APERÇU', style: AppText.label(11, color: Colors.white54)),
                const SizedBox(height: 6),
                Text('Porsche 911 GT3', style: AppText.display(20, color: Colors.white)),
                const SizedBox(height: 12),
                const PlateBadge(plate: 'GT-911-RS', countryCode: 'FR', scale: 0.8),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('+250 XP', style: AppText.body(14, color: Colors.white, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
