// Fichier: lib/collection_screen.dart (Avec Cache Manager Forcé)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:spot_my_car/brand_models_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/services/auth_service.dart'; // <-- AJOUTE CETTE LIGNE
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/services/audio_service.dart';


class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}
 
class _CollectionScreenState extends State<CollectionScreen>
    with AutomaticKeepAliveClientMixin {
      
  List<dynamic> _allBrands = [];
  Map<String, int> _spottedCounts = {};
  Map<String, int> _totalModelsPerBrand = {};
  bool _isSigningOut = false;

  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeDataAndListenForSpotted();
  }

  void _initializeDataAndListenForSpotted() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final dataManager = Provider.of<DataManager>(context, listen: false);

    _allBrands = dataManager.brands;
    
    for (var brand in _allBrands) {
      final brandId = brand['id'];
      _totalModelsPerBrand[brandId] = dataManager.modelsByBrand[brandId]?.length ?? 0;
    }

    FirebaseFirestore.instance
        .collection('spotted_cars')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      _calculateSpottedCounts(snapshot.docs);
    });
  }

  void _calculateSpottedCounts(List<QueryDocumentSnapshot> docs) {
    final newCounts = <String, int>{};
    for (var brand in _allBrands) {
      final brandId = brand['id'];
      final count = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data.containsKey('brandId') && data['brandId'] == brandId;
      }).map((doc) => (doc.data() as Map<String, dynamic>)['modelId']).toSet().length;
      newCounts[brandId] = count;
    }
    if (mounted) setState(() => _spottedCounts = newCounts);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: const Center(child: Text("Veuillez vous connecter pour voir votre collection.")),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,        actions: [
          IconButton(
            tooltip: "Se déconnecter",
            icon: Icon(
              Icons.logout,
              color: _isSigningOut ? Colors.white.withOpacity(0.5) : Colors.white,
            ),
      onPressed: _isSigningOut
          ? null
          : () async {
              AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
              setState(() => _isSigningOut = true);
              try {
                await AuthService.signOut(); 
                if (mounted) { 
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de la déconnexion: ${e.toString()}")),
                  );
                  // On remet le bouton à son état initial en cas d'erreur
                  setState(() => _isSigningOut = false);
                }
              }
            },
          )
        ],
      ),
      body: GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kIsWeb ? 6 : 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.0,
              ),
              itemCount: _allBrands.length,
              itemBuilder: (context, index) {
                final brand = _allBrands[index];
                final brandId = brand['id'];
                final spottedCount = _spottedCounts[brandId] ?? 0;
                final totalModels = _totalModelsPerBrand[brandId] ?? 1;
                final bool isCompleted =
                    totalModels > 0 && spottedCount >= totalModels;
                final logoUrl = brand['logoUrl'] as String?;
                return GestureDetector(
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BrandModelsScreen(
                          brand: brand, 
                          showAsGrayscaleCollection: true
                        )
                      ) // <-- Voici la parenthèse manquante
                    );
                  },
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    color: Colors.white,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (logoUrl != null && logoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: CachedNetworkImage(
                              // ==========================================================
                              // === 2. ON FORCE L'UTILISATION DU CACHE PERSONNALISÉ =====
                              // ==========================================================
                              cacheManager: CustomCacheManager(),
                              imageUrl: logoUrl,
                              fit: BoxFit.contain,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey
                              ),
                            ),
                          ),
                        if (!isCompleted)
                          Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Colors.grey.withOpacity(1.0),
                                  backgroundBlendMode: BlendMode.saturation)),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2.0),
                            width: double.infinity,
                            color: isCompleted
                                ? Colors.amber[800]
                                : Colors.black.withOpacity(0.6),
                            child: Text(
                                "$spottedCount / $totalModels",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}