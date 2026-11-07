import 'package:flutter/material.dart';
import 'package:spot_my_car/widgets/car_image.dart';

/// Ancienne API conservée pour les écrans existants : délègue à [CarImage].
class CarImageCard extends StatelessWidget {
  final String? imageUrl;
  final List<String?> fallbackUrls;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius borderRadius;
  final String? brandName;
  final String? modelName;

  const CarImageCard({
    super.key,
    required this.imageUrl,
    this.fallbackUrls = const [],
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius = BorderRadius.zero,
    this.brandName,
    this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    return CarImage(
      urls: [imageUrl, ...fallbackUrls],
      fit: fit,
      borderRadius: borderRadius,
      brandName: brandName,
      modelName: modelName,
    );
  }
}
