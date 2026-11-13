import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Choix de l'ambiance musicale (compositions originales).
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  static const _icons = {
    'night': Icons.nightlight_round,
    'synthwave': Icons.wb_twilight_rounded,
    'lofi': Icons.coffee_rounded,
    'phonk': Icons.local_fire_department_rounded,
    'circuit': Icons.speed_rounded,
  };
  static const _colors = {
    'night': Color(0xFF5B8CFF),
    'synthwave': Color(0xFFFF4FA3),
    'lofi': Color(0xFFE0A15A),
    'phonk': Color(0xFFFF5A4E),
    'circuit': Color(0xFF3DDC97),
  };

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(tr('Musique d\'ambiance')), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: audio.isMusicEnabled,
              onChanged: audio.toggleMusic,
              title: Text(tr('Musique activée'), style: AppText.body(15.5, weight: FontWeight.w800)),
              subtitle: Text(tr('Elle se met en pause quand tu quittes l\'appli.'), style: AppText.body(12.5, color: AppColors.inkSoft)),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('CHOISIS TON AMBIANCE'), style: AppText.label(12, color: AppColors.inkMuted).copyWith(letterSpacing: 2)),
          const SizedBox(height: 10),
          for (final (i, t) in AudioService.tracks.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TrackTile(
                name: t.name,
                mood: tr(t.mood),
                icon: _icons[t.id] ?? Icons.music_note_rounded,
                color: _colors[t.id] ?? Theme.of(context).colorScheme.primary,
                selected: audio.trackId == t.id,
                playing: audio.trackId == t.id && audio.isMusicEnabled,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (!audio.isMusicEnabled) audio.toggleMusic(true);
                  audio.setTrack(t.id);
                },
              ).animate(delay: (60 * i).ms).fadeIn(duration: 300.ms).slideX(begin: 0.06, end: 0),
            ),
          const SizedBox(height: 10),
          Text(tr('Toutes les musiques sont des créations originales pour Spot My Car.'), textAlign: TextAlign.center, style: AppText.body(12.5, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final String name;
  final String mood;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  const _TrackTile({required this.name, required this.mood, required this.icon, required this.color, required this.selected, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: selected ? color : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.45)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16)] : null,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.display(20)),
                    const SizedBox(height: 2),
                    Text(mood, style: AppText.body(12.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              if (playing) _Equalizer(color: color) else if (selected) Icon(Icons.check_circle_rounded, color: color) else Icon(Icons.play_circle_outline_rounded, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Equalizer extends StatefulWidget {
  final Color color;
  const _Equalizer({required this.color});
  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 6 + 16 * (0.5 + 0.5 * sin(_c.value * 2 * pi + i * 1.7)).abs(),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      );
}
