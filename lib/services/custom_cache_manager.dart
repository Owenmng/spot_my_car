// lib/services/custom_cache_manager.dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'customCacheKey';
  static CustomCacheManager? _instance;

  factory CustomCacheManager() {
    _instance ??= CustomCacheManager._();
    return _instance!;
  }

  CustomCacheManager._() : super(Config(
    key,
    // On définit la durée de validité du cache (ex: 30 jours)
    stalePeriod: const Duration(days: 30),
    // Le nombre maximum d'objets dans le cache
    maxNrOfCacheObjects: 200, 
    // Le repo qui s'occupe de télécharger
    fileService: HttpFileService(),
    // Le service qui génère le chemin de sauvegarde
    fileSystem: IOFileSystem(key),
  ));

  // Cette partie est importante pour les versions récentes de path_provider
  @override
  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }
}