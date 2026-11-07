import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // Import pour la détection de plateforme
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/services/audio_service.dart';


class BrandSelection extends StatefulWidget {
  const BrandSelection({super.key});
  @override
  State<BrandSelection> createState() => _BrandSelectionState();
}

class _BrandSelectionState extends State<BrandSelection> {
  List<dynamic> _allBrands = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  // Le ValueNotifier pour une recherche réactive sans reconstruire tout l'écran
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _loadBrandData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose(); // Important de disposer le notifier
    super.dispose();
  }

  Future<void> _loadBrandData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/brands.json');
      final data = await json.decode(response);
      if (mounted) {
        setState(() {
          _allBrands = data['brands'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur de chargement du catalogue: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: const Text('Choisir une marque'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                // Met à jour la valeur du notifier à chaque lettre tapée
                _searchQueryNotifier.value = query;
              },
              decoration: InputDecoration(
                labelText: 'Rechercher une marque...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                // Le bouton "effacer" est maintenant dynamique grâce au ValueListenableBuilder
                suffixIcon: ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, value, child) {
                    return value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchQueryNotifier.value = '';
                            })
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, searchQuery, child) {
                      // La logique de filtrage se trouve maintenant ici
                      final filteredBrands = _allBrands.where((brand) {
                        return brand['name']
                            .toString()
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase());
                      }).toList();

                      if (filteredBrands.isEmpty) {
                        return const Center(child: Text("Aucune marque trouvée."));
                      }

                      // La grille se reconstruit avec les données filtrées
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        // Le gridDelegate adaptatif qui répond à ta demande
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kIsWeb ? 6 : 3, // 6 sur web, 3 sur mobile
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: filteredBrands.length,
                        itemBuilder: (context, index) {
                          final brand = filteredBrands[index];
                          final logoUrl = brand['logoUrl'] as String?;

                          return InkWell(
                            onTap: () {
                              AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                              Navigator.pop(context, brand);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: logoUrl != null && logoUrl.isNotEmpty
                                          ? Image.network(
                                              logoUrl,
                                              fit: BoxFit.contain,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                if (progress == null) return child;
                                                return const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2));
                                              },
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(Icons.image_not_supported),
                                            )
                                          : const Icon(Icons.image_not_supported),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      brand['name'],
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 