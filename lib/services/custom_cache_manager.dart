import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque partagé pour toutes les photos de voitures (catalogue + spots).
/// En-têtes envoyés avec chaque image (Wikimedia demande une identification de l'appli).
const Map<String, String> kImageHeaders = {
  'User-Agent': 'SpotMyCar/2.0 (Android app; contact.spotmycar@gmail.com)',
};

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
