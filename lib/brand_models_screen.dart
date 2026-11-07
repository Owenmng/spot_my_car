// Fichier: lib/brand_models_screen.dart (Version Corrigée pour l'appel)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';


enum SortOption { nameAsc, nameDesc, yearAsc, yearDesc }

class BrandModelsScreen extends StatefulWidget {
  final Map<String, dynamic> brand;
  final bool showAsGrayscaleCollection;

  const BrandModelsScreen({
    super.key, 
    required this.brand,
    this.showAsGrayscaleCollection = false,
  });
  @override
  State<BrandModelsScreen> createState() => _BrandModelsScreenState();
}

class _BrandModelsScreenState extends State<BrandModelsScreen> {
  List<dynamic> _sortedModels = []; 
  bool _isLoadingFirestoreData = true;
  SortOption _currentSortOption = SortOption.nameAsc;
  Set<String> _spottedModelIds = {};

  @override
  void initState() {
    super.initState();
    _initializeModelsAndLoadSpottedData();
  }

  void _initializeModelsAndLoadSpottedData() {
    final dataManager = Provider.of<DataManager>(context, listen: false);
    final brandId = widget.brand['id'];
    
    final modelsFromManager = dataManager.modelsByBrand[brandId] ?? [];
    _sortedModels = List.from(modelsFromManager);
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingFirestoreData = false);
      return;
    }
    
    FirebaseFirestore.instance
        .collection('spotted_cars')
        .where('userId', isEqualTo: currentUser.uid)
        .where('brandId', isEqualTo: brandId)
        .snapshots()
        .listen((snapshot) {
            final newSpottedIds = snapshot.docs
                .map((doc) => doc['modelId'] as String?)
                .where((id) => id != null)
                .toSet()
                .cast<String>();
            
            if (mounted) setState(() => _spottedModelIds = newSpottedIds);
        });

    if (mounted) {
      setState(() {
        _sortModels();
        _isLoadingFirestoreData = false;
      });
    }
  }

  void _sortModels() {
    _sortedModels.sort((a, b) {
      switch (_currentSortOption) {
        case SortOption.nameAsc: 
        return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
        case SortOption.nameDesc: 
        return b['name'].toString().toLowerCase().compareTo(a['name'].toString().toLowerCase());
        case SortOption.yearAsc: return _getYear(a['production_years']).compareTo(_getYear(b['production_years']));
        case SortOption.yearDesc: return _getYear(b['production_years']).compareTo(_getYear(a['production_years']));
      }
    });
  }

  int _getYear(String? years) {
    if (years == null || years.isEmpty) return 0;
    return int.tryParse(years.split(' ')[0]) ?? 0;
  }
  
  void _updateSortOption(SortOption? newOption) {
    if (newOption != null) {
      setState(() { _currentSortOption = newOption; _sortModels(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // On ajoute le bouton de retour manuellement pour y mettre un son
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            Navigator.of(context).pop();
          },
        ),
        title: Text('Modèles ${widget.brand['name']}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingFirestoreData
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Trier par :", style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<SortOption>(
                        value: _currentSortOption,
                        underline: const SizedBox(),
                        onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                        items: const [
                          DropdownMenuItem(value: SortOption.nameAsc, child: Text("Nom (A-Z)")),
                          DropdownMenuItem(value: SortOption.nameDesc, child: Text("Nom (Z-A)")),
                          DropdownMenuItem(value: SortOption.yearAsc, child: Text("Année (Anciens)")),
                          DropdownMenuItem(value: SortOption.yearDesc, child: Text("Année (Récents)")),
                        ],
                        onChanged: _updateSortOption,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _sortedModels.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("Aucun modèle disponible pour cette marque.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey))))
                      : GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: kIsWeb ? 4 : 3, 
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _sortedModels.length,
                          itemBuilder: (context, index) {
                            final model = _sortedModels[index];
                            final bool isSpotted = _spottedModelIds.contains(model['id']);
                            final imageUrl = model['imageUrl'] as String?;
                            final bool applyGrayscale = widget.showAsGrayscaleCollection && !isSpotted;

                            // ==========================================================
                            // === LA CORRECTION EST ICI ================================
                            // ==========================================================
                            return GestureDetector(
                              onTap: () {
                                AudioService.instance.playSfx(SoundEffect.clicPrincipal);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ModelDetailScreen(
                                  // On passe la liste complète des modèles (triés)
                                  modelsList: _sortedModels,
                                  // On passe l'index du modèle sur lequel on a cliqué
                                  initialIndex: index,
                                  // On passe toujours l'info si le modèle est spotté ou non
                                  isSpotted: isSpotted,
                                  brand: widget.brand,
                                ))); // <-- J'ai bien refermé toutes les parenthèses
                              },
                              child: Card(
                                elevation: 2, margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if(imageUrl != null && imageUrl.isNotEmpty)
                                      CachedNetworkImage(
                                        cacheManager: CustomCacheManager(),
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        fadeInDuration: const Duration(milliseconds: 200),
                                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                                        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                        imageBuilder: (context, imageProvider) => Container(
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                              colorFilter: applyGrayscale 
                                                ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                                : null,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(Icons.image_not_supported, color: Colors.grey),
                                    Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment(0.0, 0.2), end: Alignment.bottomCenter))),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(model['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text(model['production_years'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isSpotted)
                                      Positioned(top: 5, right: 5, child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}