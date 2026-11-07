// Fichier: lib/widgets/car_image_card.dart (Version Corrigée)

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CarImageCard extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius borderRadius; // <-- AJOUTE CETTE LIGNE

  const CarImageCard({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    // On met une valeur par défaut pour ne pas casser le code existant
    this.borderRadius = BorderRadius.zero, // <-- AJOUTE CETTE LIGNE
  });

  @override
  Widget build(BuildContext context) {
    // Le design que l'on veut réutiliser
    return Card(
      elevation: 4,
      // ON UTILISE LE clipBehavior DU PARENT, MAIS LE shape VIENT D'ICI
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius, // <-- MODIFIE CETTE LIGNE
      ),
      child: Container(
        // Fond gris pour les cas où l'image ne charge pas
        color: Colors.grey[200],
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: fit,
                placeholder: (context, url) =>
                    placeholder ?? const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                errorWidget: (context, url, error) =>
                    errorWidget ?? const Icon(Icons.image_not_supported, color: Colors.grey),
              )
            : const Icon(Icons.directions_car, size: 40, color: Colors.grey),
      ),
    );
  }
}