// Fichier: lib/level_up_dialog.dart (NOUVEAU FICHIER)
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:spot_my_car/models/level_model.dart'; // On importe notre modèle centralisé

class LevelUpDialog extends StatefulWidget {
  final Level newLevel;
  const LevelUpDialog({super.key, required this.newLevel});

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    
    _confettiController.play();

    // Ferme automatiquement le dialogue après 4 secondes
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Theme.of(context).primaryColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LEVEL UP !',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2),
                ),
                const SizedBox(height: 20),
                Text(
                  'Niveau ${widget.newLevel.level}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  widget.newLevel.title,
                  style: const TextStyle(fontSize: 22, color: Colors.white70, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Icon(Icons.star, color: Colors.amber, size: 50),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // vers le bas
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
            colors: const [Colors.amber, Colors.white, Colors.orange],
          ),
        ),
      ],
    );
  }
}