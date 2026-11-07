// Fichier: lib/level_up_overlay.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:spot_my_car/models/level_model.dart';

class LevelUpOverlay extends StatefulWidget {
  final Level oldLevel;
  final Level newLevel;
  final int oldXp;
  final int newXp;
  final VoidCallback onDismissed;

  const LevelUpOverlay({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.oldXp,
    required this.newXp,
    required this.onDismissed,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _numberController;
  late Animation<double> _progressAnimation;
  late Animation<int> _levelNumberAnimation;
  late Animation<double> _xpNumberAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _numberController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    final double startProgress = (widget.oldXp - widget.oldLevel.xpRequired) / (widget.newLevel.xpRequired - widget.oldLevel.xpRequired);
    
    // Animation de la barre de progression circulaire
    _progressAnimation = Tween<double>(begin: startProgress, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    )..addListener(() {
      // Quand la barre atteint 100%, on déclenche l'animation du chiffre
      if (_progressAnimation.value == 1.0 && _numberController.status != AnimationStatus.forward) {
        _numberController.forward();
      }
    });
    
    // Animation du chiffre du niveau qui change
    _levelNumberAnimation = IntTween(begin: widget.oldLevel.level, end: widget.newLevel.level).animate(_numberController);
    
    // Animation du total d'XP qui augmente
    _xpNumberAnimation = Tween<double>(begin: widget.oldXp.toDouble(), end: widget.newXp.toDouble()).animate(_controller);

    // On attend un peu avant de lancer l'animation principale
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _numberController.dispose();
    super.dispose();
  }
  
  @override
Widget build(BuildContext context) {
  return Positioned.fill(
    child: Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: AnimatedBuilder( // On anime l'apparition du panneau entier
              animation: _controller,
              child: Container(
                // ==========================================================
                // >>>>> LE NOUVEAU PANNEAU BLANC EST ICI <<<<<
                // ==========================================================
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Très important
                  children: [
                    Text(
                      "NIVEAU SUPÉRIEUR !",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor, // On utilise la couleur de ton app
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_progressAnimation, _levelNumberAnimation]),
                        builder: (context, child) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _progressAnimation.value,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[600]!),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("NIVEAU", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                                    Text(
                                      _levelNumberAnimation.value.toString(),
                                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Text(
                                      widget.newLevel.title,
                                      style: TextStyle(fontSize: 14, color: Colors.amber[800], fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _xpNumberAnimation,
                      builder: (context, child) {
                        return Text(
                          "${_xpNumberAnimation.value.toInt()} XP",
                          style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.w300),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: widget.onDismissed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Continuer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              // On ajoute une animation d'échelle et de fondu sur le panneau
              builder: (context, child) {
                return Transform.scale(
                  scale: _controller.drive(CurveTween(curve: Curves.elasticOut)).value,
                  child: Opacity(
                    opacity: _controller.drive(CurveTween(curve: Curves.easeIn)).value,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ));
  }
}

// Fonction helper pour afficher l'overlay
Future<void> showLevelUp(BuildContext context, {required Level oldLevel, required Level newLevel, required int oldXp, required int newXp}) {
  final completer = Completer<void>();
  
  final overlayEntry = OverlayEntry(
    builder: (context) => LevelUpOverlay(
      oldLevel: oldLevel,
      newLevel: newLevel,
      oldXp: oldXp,
      newXp: newXp,
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