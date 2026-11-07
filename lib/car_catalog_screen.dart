// Fichier: lib/car_catalog_screen.dart (Version Finale Corrigée)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/brand_detail_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/services/auth_service.dart';

// ==========================================================
// === 1. CONVERSION EN STATEFULWIDGET ======================
// ==========================================================
class CarCatalogScreen extends StatefulWidget {
  const CarCatalogScreen({super.key});

  @override
  State<CarCatalogScreen> createState() => _CarCatalogScreenState();
}

class _CarCatalogScreenState extends State<CarCatalogScreen> {
  // ==========================================================
  // === 2. LA VARIABLE D'ÉTAT EST DÉPLACÉE ICI ==============
  // ==========================================================
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final dataManager = Provider.of<DataManager>(context);
    final List<dynamic> brands = dataManager.brands;
    // La variable _isSigningOut n'est plus déclarée ici.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue des Marques'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Le bouton de déconnexion fonctionne maintenant car setState et mounted existent.
          IconButton(
            tooltip: "Se déconnecter",
            icon: Icon(
              Icons.logout,
              color: _isSigningOut ? Colors.white.withOpacity(0.5) : Colors.white,
            ),
            onPressed: _isSigningOut
                ? null
                : () async {
                    // On utilise setState, qui est disponible dans un State object
                    setState(() => _isSigningOut = true);
                    try {
                      await AuthService.signOut(); 
                      // 'mounted' est également disponible ici
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
                        setState(() => _isSigningOut = false);
                      }
                    }
                  },
          ),
        ],
      ),
      body: brands.isEmpty
          ? const Center(child: Text("Le catalogue est vide ou n'a pas pu être chargé."))
          : GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kIsWeb ? 6 : 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.0,
              ),
              itemCount: brands.length,
              itemBuilder: (context, index) {
                final brand = brands[index];
                final logoUrl = brand['logoUrl'] as String?;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                BrandDetailScreen(brand: brand)));
                  },
                  child: Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: logoUrl != null && logoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    cacheManager: CustomCacheManager(),
                                    imageUrl: logoUrl,
                                    fit: BoxFit.contain,
                                    fadeInDuration: const Duration(milliseconds: 200),
                                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 24),
                                  )
                                : const Icon(Icons.question_mark, size: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brand['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}