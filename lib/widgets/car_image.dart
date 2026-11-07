import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/photo_store.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Affiche la photo d'une voiture en essayant plusieurs sources dans l'ordre.
/// Si aucune ne répond (réseau coupé, image supprimée…), on dessine une vignette
/// propre aux couleurs de la marque plutôt qu'une icône d'erreur grise.
class CarImage extends StatelessWidget {
  final List<String?> urls;
  final String? brandName;
  final String? modelName;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color? tint;

  const CarImage({
    super.key,
    required this.urls,
    this.brandName,
    this.modelName,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final sources = urls.whereType<String>().where((u) => u.startsWith('http')).toList();
    return ClipRRect(
      borderRadius: borderRadius,
      child: sources.isEmpty
          ? CarImageFallback(brandName: brandName, modelName: modelName, tint: tint)
          : _Chain(sources: sources, index: 0, fit: fit, fallback: () => CarImageFallback(brandName: brandName, modelName: modelName, tint: tint)),
    );
  }
}

class _Chain extends StatelessWidget {
  final List<String> sources;
  final int index;
  final BoxFit fit;
  final Widget Function() fallback;

  const _Chain({required this.sources, required this.index, required this.fit, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: sources[index],
      cacheManager: CustomCacheManager(),
      httpHeaders: kImageHeaders,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 260),
      placeholder: (_, _) => const _Shimmer(),
      errorWidget: (_, _, _) => index + 1 < sources.length
          ? _Chain(sources: sources, index: index + 1, fit: fit, fallback: fallback)
          : fallback(),
    );
  }
}

class CarImageFallback extends StatelessWidget {
  final String? brandName;
  final String? modelName;
  final Color? tint;

  const CarImageFallback({super.key, this.brandName, this.modelName, this.tint});

  static const _tones = [
    Color(0xFF2B2D42),
    Color(0xFF3D348B),
    Color(0xFF1F4E5F),
    Color(0xFF6B2737),
    Color(0xFF3E5641),
    Color(0xFF5C4D3C),
    Color(0xFF283845),
  ];

  @override
  Widget build(BuildContext context) {
    final name = (brandName ?? '').trim();
    final base = tint ?? _tones[name.isEmpty ? 0 : name.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];
    final initials = name.isEmpty
        ? '?'
        : name.split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return LayoutBuilder(builder: (context, c) {
      final small = c.maxHeight < 120;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(base, Colors.white, 0.12)!, Color.lerp(base, Colors.black, 0.35)!],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -c.maxWidth * 0.08,
              bottom: -c.maxHeight * 0.12,
              child: Icon(
                Icons.directions_car_filled_rounded,
                size: c.maxHeight * 0.95,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(small ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: small ? MainAxisAlignment.center : MainAxisAlignment.end,
                children: [
                  Text(initials, style: AppText.display(small ? 26 : 40, color: Colors.white.withValues(alpha: 0.92))),
                  if (!small && (modelName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      modelName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(13, color: Colors.white70, weight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, -0.3),
            end: Alignment(-0.5 + 3 * _c.value, 0.3),
            colors: const [AppColors.paperDeep, Color(0xFFF7F4EF), AppColors.paperDeep],
          ),
        ),
      ),
    );
  }
}

/// Image d'un spot du garage : la photo du joueur (Firestore) si elle existe,
/// sinon la photo officielle du catalogue, sinon la vignette aux couleurs de la marque.
class SpotImage extends StatelessWidget {
  final String carId;
  final Map<String, dynamic> car;
  final bool preferOfficial;
  final BorderRadius borderRadius;

  const SpotImage({super.key, required this.carId, required this.car, this.preferOfficial = false, this.borderRadius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) {
    final catalog = DataManager.instance.modelById(car['modelId'] as String?);
    final official = [catalog?['imageUrl'] as String?, car['modelImageUrl'] as String?];
    final fallback = CarImage(
      urls: preferOfficial ? [...official, car['userPhotoUrl'] as String?] : [car['userPhotoUrl'] as String?, ...official],
      brandName: car['brandName'] as String?,
      modelName: car['modelName'] as String?,
      borderRadius: borderRadius,
    );
    if (preferOfficial || car['hasPhoto'] != true) return fallback;

    return FutureBuilder<Uint8List?>(
      future: PhotoStore.load(carId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return ClipRRect(borderRadius: borderRadius, child: const _Shimmer());
        }
        final bytes = snap.data;
        if (bytes == null) return fallback;
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true),
        );
      },
    );
  }
}
