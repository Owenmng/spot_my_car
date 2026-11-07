import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/theme_notifier.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Apparence : ambiance de l'interface + couleur dominante, avec aperçu en direct.
class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ThemeNotifier>();
    final w = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Preview(accent: notifier.accent),
          const SizedBox(height: 26),
          Text('AMBIANCE', style: AppText.label(11.5, color: AppColors.inkMuted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in palettes)
                SizedBox(
                  width: (w - 32 - 10) / 2,
                  child: _PaletteCard(
                    palette: p,
                    accent: notifier.accent,
                    selected: p.id == notifier.palette.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      AudioService.instance.playSfx(SoundEffect.clicLeger);
                      notifier.setPalette(p);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          Text('COULEUR DOMINANTE', style: AppText.label(11.5, color: AppColors.inkMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 14,
            children: [
              for (final a in accentChoices)
                _Swatch(
                  choice: a,
                  width: (w - 32 - 6 * 4) / 5,
                  selected: a.name == notifier.accentChoice.name,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    AudioService.instance.playSfx(SoundEffect.clicLeger);
                    notifier.setAccent(a);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final AppPalette palette;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteCard({required this.palette, required this.accent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.paper,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? accent : p.line, width: selected ? 2.4 : 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // mini-écran
            Container(
              height: 64,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
              child: Row(
                children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: p.panelHi, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(height: 7, width: 60, decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Container(height: 6, width: 40, decoration: BoxDecoration(color: p.inkMuted, borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(p.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 16, color: p.inkSoft),
                const SizedBox(width: 6),
                Expanded(child: Text(p.name, style: AppText.body(14, weight: FontWeight.w800, color: p.ink))),
                if (selected) Icon(Icons.check_circle_rounded, size: 18, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final AccentChoice choice;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({required this.choice, required this.width, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onC = choice.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: selected ? 50 : 42,
              height: selected ? 50 : 42,
              decoration: BoxDecoration(
                color: choice.color,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 2.5),
                boxShadow: [BoxShadow(color: choice.color.withValues(alpha: selected ? 0.5 : 0.2), blurRadius: selected ? 16 : 6)],
              ),
              child: selected ? Icon(Icons.check_rounded, color: onC, size: 22) : null,
            ),
            const SizedBox(height: 6),
            Text(
              choice.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: AppText.body(10.5, weight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? AppColors.ink : AppColors.inkSoft),
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
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(AppColors.card, accent, 0.25)!, AppColors.card],
        ),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('APERÇU', style: AppText.label(11, color: AppColors.inkMuted)),
              const Spacer(),
              const RarityBadge(rarity: Rarity.legendaire, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Text('Porsche 911 GT3', style: AppText.display(26)),
          const SizedBox(height: 4),
          Text('Génération 992 · 510 ch', style: AppText.body(13.5, color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          Row(
            children: [
              const PlateBadge(plate: 'GT-911-RS', countryCode: 'FR', scale: 0.75),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text('+250 XP', style: AppText.body(14, color: onAccent, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: 0.62, minHeight: 6, color: accent, backgroundColor: AppColors.paperDeep),
          ),
        ],
      ),
    );
  }
}
