// Fichier: lib/theme_selection_screen.dart (Version Finale Complète)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/theme_notifier.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // On récupère notre ThemeNotifier pour savoir quel thème est actif et pour le changer
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      // L'AppBar et le fond prennent automatiquement les couleurs du thème ACTUEL
      appBar: AppBar(
        title: const Text('Choisir un thème'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: themeNotifier.availableThemes.length,
          itemBuilder: (context, index) {
            final theme = themeNotifier.availableThemes[index];
            final isSelected = theme.name == themeNotifier.currentAppTheme.name;

            return GestureDetector(
              onTap: () {
                // Au clic, on change le thème global de l'application
                themeNotifier.setTheme(theme);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.themeData.primaryColor : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                  // La couleur de fond de la carte est maintenant celle du thème qu'elle représente
                  color: theme.themeData.colorScheme.surface,
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: theme.themeData.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Le cercle bicolore
                    ThemePreviewCircle(
                      primaryColor: theme.themeData.primaryColor,
                      backgroundColor: theme.themeData.scaffoldBackgroundColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        // Le texte prend la couleur appropriée pour le fond de la carte
                        color: theme.themeData.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Widget dédié pour le cercle bicolore (corrigé)
class ThemePreviewCircle extends StatelessWidget {
  final Color primaryColor;
  final Color backgroundColor;

  const ThemePreviewCircle({
    super.key,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipOval(
        child: Row(
          children: [
            Expanded(child: Container(color: primaryColor)),
            Expanded(child: Container(color: backgroundColor)),
          ],
        ),
      ),
    );
  }
}