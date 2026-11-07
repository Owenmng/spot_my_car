import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque partagé pour toutes les photos de voitures (catalogue + spots).
class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'spotmycar_images';
  static final CustomCacheManager _instance = CustomCacheManager._();

  factory CustomCacheManager() => _instance;

  CustomCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 60),
          maxNrOfCacheObjects: 1500,
        ));
}
