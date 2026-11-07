// Fichier: lib/achievement_overlay.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:spot_my_car/services/achievement_service.dart';

class AchievementOverlay extends StatefulWidget {
  final AchievementLevel achievement;
  final IconData icon;
  final VoidCallback onDismissed;

  const AchievementOverlay({
    super.key,
    required this.achievement,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<AchievementOverlay> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _starControllers = List.generate(3, (index) => AnimationController(duration: const Duration(milliseconds: 300), vsync: this));
    _starAnimations = _starControllers.map((controller) => Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: controller, curve: Curves.bounceOut))).toList();
    
    _controller.forward().whenComplete(() {
      _animateStars();
    });
  }

  void _animateStars() async {
    for (int i = 0; i < widget.achievement.level; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _starControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var c in _starControllers) {
      c.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Couche de flou qui capture les clics
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            
            // Le contenu du succès
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, spreadRadius: 5)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 40, color: Colors.amber[700]),
                        const SizedBox(height: 16),
                        Text(
                          widget.achievement.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.achievement.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),

                        // Affichage des étoiles animées
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final isUnlocked = (index + 1) <= widget.achievement.level;
                            return ScaleTransition(
                              scale: _starAnimations[index],
                              child: Icon(
                                isUnlocked ? Icons.star : Icons.star_border,
                                color: isUnlocked ? Colors.amber[600] : Colors.grey[300],
                                size: 40,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "+${widget.achievement.xpReward} XP",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                        ),
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: widget.onDismissed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)
                            )
                          ),
                          child: const Text('Super !', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAchievementUnlocked(BuildContext context, AchievementLevel achievement, IconData icon) {
  final completer = Completer<void>();
  
  final overlayEntry = OverlayEntry(
    builder: (context) => AchievementOverlay(
      achievement: achievement,
      icon: icon,
      onDismissed: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    ),
  );

  Overlay.of(context).insert(overlayEntry);

  return completer.future.then((_) {
    overlayEntry.remove();
  });
}