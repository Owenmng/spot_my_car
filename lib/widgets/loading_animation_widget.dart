// Fichier: lib/widgets/loading_animation_widget.dart

import 'package:flutter/material.dart';

class LoadingAnimationWidget extends StatefulWidget {
  final String loadingMessage;

  const LoadingAnimationWidget({
    Key? key,
    this.loadingMessage = "Chargement...",
  }) : super(key: key);

  @override
  State<LoadingAnimationWidget> createState() => _LoadingAnimationWidgetState();
}

class _LoadingAnimationWidgetState extends State<LoadingAnimationWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, spreadRadius: 2)],
                ),
                child: Image.asset('assets/logo.png'),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.loadingMessage, // On utilise le message passé en paramètre
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}