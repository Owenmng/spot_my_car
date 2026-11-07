import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Écran de démarrage : le logo respire pendant que le garage se charge.
class LoadingAnimationWidget extends StatelessWidget {
  final String loadingMessage;

  const LoadingAnimationWidget({super.key, this.loadingMessage = 'Chargement…'});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 104)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 900.ms, curve: Curves.easeInOut),
            const SizedBox(height: 34),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(delay: (160 * i).ms, duration: 300.ms)
                    .then()
                    .fadeOut(duration: 300.ms, delay: 300.ms),
              ),
            ),
            const SizedBox(height: 18),
            Text(loadingMessage, style: AppText.body(15, color: AppColors.inkSoft, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
