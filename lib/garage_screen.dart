// Fichier: lib/garage_screen.dart (Version avec Recherche et Filtres Dynamiques)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/add_car_screen.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/connectivity_service.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/services/auth_service.dart'; // <-- AJOUTE CETTE LIGNE
import 'package:spot_my_car/widgets/car_image_card.dart'; // <-- AJOUTE CETTE LIGNE
import 'package:spot_my_car/services/audio_service.dart';


class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});
  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final _searchController = TextEditingController();
  bool _isSigningOut = false;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  List<Map<String, dynamic>> _pendingSpots = [];
  String? _selectedBrandFilter;
  String? _selectedColorFilter;
  String? _selectedDateFilter;
  List<QueryDocumentSnapshot> _firebaseDocsCache = [];

  @override
  void initState() {
    super.initState();
    
    _loadPendingSpots();
  }

  Future<void> _loadPendingSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pendingSpotsJson = prefs.getStringList('pending_spots') ?? [];
    if (mounted) {
      setState(() {
        _pendingSpots = pendingSpotsJson
            .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>)
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterPanel(List<QueryDocumentSnapshot> allDocs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Très important pour que le clavier ne pose pas de problème
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Ce builder permet aux filtres d'avoir leur propre état
        // sans reconstruire la page GarageScreen derrière.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Logique pour extraire les marques et couleurs uniques
            final List<String> availableBrands = allDocs
                .map((doc) =>
                    (doc.data() as Map<String, dynamic>)['brandName'] as String?)
                .where((brand) => brand != null)
                .cast<String>()
                .toSet()
                .toList()
              ..sort();
            
            final List<String> availableColors = allDocs
                .map((doc) =>
                    (doc.data() as Map<String, dynamic>)['color'] as String?)
                .where((color) => color != null)
                .cast<String>()
                .toSet()
                .toList()
              ..sort();

            // >>>>> DÉBUT DES MODIFICATIONS PRINCIPALES <<<<<
            return SingleChildScrollView(
              child: Padding(
                // Padding dynamique pour ne pas être caché par le clavier
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                ),
                // On utilise une Column pour une structure verticale claire
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ligne du titre et du bouton "Réinitialiser"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filtrer les spots',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                            // setModalState met à jour l'intérieur du panel
                            setModalState(() {
                              _selectedBrandFilter = null;
                              _selectedColorFilter = null;
                              _selectedDateFilter = null;
                            });
                          },
                          child: const Text('Réinitialiser'),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filtre par Marque
                    DropdownButtonFormField<String>(
                      value: _selectedBrandFilter,
                      onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                      hint: const Text('Toutes les marques'),
                      decoration: const InputDecoration(
                          labelText: 'Marque', border: OutlineInputBorder()),
                      items: availableBrands
                          .map((brand) =>
                              DropdownMenuItem(value: brand, child: Text(brand)))
                          .toList(),
                      onChanged: (value) {
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        setModalState(() => _selectedBrandFilter = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Filtre par Couleur
                    DropdownButtonFormField<String>(
                      value: _selectedColorFilter,
                      onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                      hint: const Text('Toutes les couleurs'),
                      decoration: const InputDecoration(
                          labelText: 'Couleur', border: OutlineInputBorder()),
                      items: availableColors
                          .map((color) =>
                              DropdownMenuItem(value: color, child: Text(color)))
                          .toList(),
                      onChanged: (value) {
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        setModalState(() => _selectedColorFilter = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Titre pour le filtre de date
                    const Text('Date du spot :',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 12),

                    // Le Wrap est parfait ici pour les boutons de date
                   Row(
                      children: ['Aujourd\'hui', 'Cette semaine', 'Ce mois-ci'].map((label) {
                        final value = label.split(' ')[0].toLowerCase();
                        final isSelected = _selectedDateFilter == value;

                        return Flexible(
                          fit: FlexFit.tight,
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: ChoiceChip(
                              labelPadding: EdgeInsets.zero,
                              
                              label: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  // Si vraiment ça ne passe pas, c'est ici qu'on mettrait un fontSize: 13
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                                setModalState(() {
                                  _selectedDateFilter = selected ? value : null;
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: Theme.of(context).primaryColor,

                              // >>>>> LA MODIFICATION FINALE EST ICI <<<<<
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent // On peut rendre la bordure transparente quand c'est sélectionné pour un look plus clean
                                      : Colors.grey[300]!,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Bouton pour appliquer les filtres et fermer le panel
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                          // On notifie l'écran principal que les filtres ont changé
                          setState(() {});
                          // Puis on ferme le panel
                          // Puis on ferme le panel
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          )
                        ),
                        child: const Text('Appliquer les filtres'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCar(String carId, String carName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la voiture'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer la $carName de votre garage ?'),
        actions: [
          TextButton(
              onPressed: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                Navigator.of(context).pop(false);
              },
              child: const Text('Annuler')),
          TextButton(
              onPressed: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                Navigator.of(context).pop(true);
              },
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final docRef =
          FirebaseFirestore.instance.collection('spotted_cars').doc(carId);
      final docSnapshot = await docRef.get();
      final carData = docSnapshot.data();
      if (carData != null && carData['userPhotoUrl'] != null) {
        try {
          await FirebaseStorage.instance
              .refFromURL(carData['userPhotoUrl'])
              .delete();
        } catch (e) {
          print("Erreur de suppression photo: $e");
        }
      }
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voiture supprimée.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _cleanModelName(String modelName) {
    final parenthesisIndex = modelName.indexOf('(');
    if (parenthesisIndex != -1) {
      return modelName.substring(0, parenthesisIndex).trim();
    }
    return modelName;
  }

  @override
  Widget build(BuildContext context) {
    // --- NOUVEAU : On récupère l'utilisateur ---
    final currentUser = FirebaseAuth.instance.currentUser;

    // --- NOUVEAU : On ajoute la garde de sécurité ---
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Garage')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si l'utilisateur existe, on retourne le Scaffold normal (ton ancien code)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Garage'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Se déconnecter",
            icon: Icon(
              Icons.logout,
              color: _isSigningOut ? Colors.white.withOpacity(0.5) : Colors.white,
            ),
      onPressed: _isSigningOut
          ? null
          : () async {
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (query) => _searchQueryNotifier.value = query,
                    decoration: InputDecoration(
                      hintText: 'Rechercher',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ValueListenableBuilder<String>(
                        valueListenable: _searchQueryNotifier,
                        builder: (context, value, child) {
                          if (value.isNotEmpty) {
                            return IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchQueryNotifier.value = '';
                              },
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    if (_firebaseDocsCache.isNotEmpty) {
                      _showFilterPanel(_firebaseDocsCache);
                    }
                  },
                  icon: const Icon(Icons.filter_list),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
                  if (user == null) {
                    // Retourne un stream vide si déconnecté
                    return Stream<QuerySnapshot>.empty();
                  }
                  return FirebaseFirestore.instance
                      .collection('spotted_cars')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('spottedAt', descending: true)
                      .snapshots();
                }),
                builder: (context, snapshot) {
                _firebaseDocsCache = snapshot.data?.docs ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _pendingSpots.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                final firebaseDocs = snapshot.data?.docs ?? [];
                final allItems = [..._pendingSpots, ...firebaseDocs];
                if (allItems.isEmpty) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                              "Ton garage est vide. Ajoute ta première voiture spottée !",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey))));
                }
                return ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, searchQuery, child) {
                    final filteredItems = allItems.where((item) {
                      final car = item is Map<String, dynamic>
                          ? item
                          : (item as DocumentSnapshot).data() as Map<String, dynamic>;
                      
                      bool matchesSearch = true;
                      if (searchQuery.isNotEmpty) {
                        final searchLower = searchQuery.toLowerCase();
                        final plate = (car['plate'] as String?)?.toLowerCase() ?? '';
                        final brandName = (car['brandName'] as String?)?.toLowerCase() ?? '';
                        final modelName = (car['modelName'] as String?)?.toLowerCase() ?? '';
                        matchesSearch = plate.contains(searchLower) ||
                            brandName.contains(searchLower) ||
                            modelName.contains(searchLower);
                      }
                      if (!matchesSearch) return false;
                      bool matchesBrand = true;
                      if (_selectedBrandFilter != null) {
                        matchesBrand = (car['brandName'] as String?) == _selectedBrandFilter;
                      }
                      if (!matchesBrand) return false;
                      bool matchesColor = true;
                      if (_selectedColorFilter != null) {
                        matchesColor = (car['color'] as String?) == _selectedColorFilter;
                      }
                      if (!matchesColor) return false;
                      bool matchesDate = true;
                      if (_selectedDateFilter != null) {
                        final spottedAtTimestamp = car['spottedAt'] as Timestamp?;
                        if (spottedAtTimestamp == null) {
                          matchesDate = false;
                        } else {
                          final spottedDate = spottedAtTimestamp.toDate();
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          if (_selectedDateFilter == 'aujourd\'hui') {
                            matchesDate = isSameDay(spottedDate, today);
                          } else if (_selectedDateFilter == 'cette') {
                            final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
                            matchesDate = spottedDate.isAfter(startOfWeek) || isSameDay(spottedDate, startOfWeek);
                          } else if (_selectedDateFilter == 'ce') {
                            matchesDate = spottedDate.year == now.year && spottedDate.month == now.month;
                          }
                        }
                      }
                      if (!matchesDate) return false;
                      return true;
                    }).toList();
                    if (filteredItems.isEmpty) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                  "Aucun résultat ne correspond à tes critères.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey))));
                    }
                    return ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final bool isPending = item is Map<String, dynamic> && item['isPending'] == true;
                        final Map<String, dynamic> carData;
                        final String carId;
                        if (isPending) {
                          carData = item;
                          carId = 'pending_${item['plate']}';
                        } else {
                          final carDocument = item as DocumentSnapshot;
                          carData = carDocument.data() as Map<String, dynamic>;
                          carId = carDocument.id;
                        }
                        final plate = carData['plate'] ?? 'N/A';
                        final brandName = carData['brandName'] ?? 'Marque inconnue';
                        final modelName = _cleanModelName(carData['modelName'] ?? 'Modèle inconnu');
                        
                        // ==========================================================
                        // === LA LOGIQUE MANQUANTE EST ICI =========================
                        // ==========================================================
                        final userPhotoUrl = carData['userPhotoUrl'] as String?;
                        final modelImageUrl = carData['modelImageUrl'] as String?;
                        final brandId = carData['brandId'] as String?;
                        final isCatalogued = carData['isCatalogued'] as bool? ?? false;

                        // 1. On détermine quelle URL et quel fit utiliser
                        String? imageUrl;
                        BoxFit imageFit = BoxFit.cover; 

                        if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
                          imageUrl = userPhotoUrl;
                        } else if (isCatalogued && modelImageUrl != null && modelImageUrl.isNotEmpty) {
                          imageUrl = modelImageUrl;
                          imageFit = BoxFit.contain;
                        } else if (isCatalogued && brandId != null && brandId.isNotEmpty) {
                          const projectId = "car-spotter-app-779f2";
                          imageUrl = "https://firebasestorage.googleapis.com/v0/b/$projectId.appspot.com/o/logos%2F$brandId.png?alt=media";
                          imageFit = BoxFit.contain;
                        }
                        // ==========================================================
                        
                        return Opacity(
                          opacity: isPending ? 0.6 : 1.0,
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            // ==========================================================
                            child: InkWell( // On utilise InkWell pour garder l'effet de clic
                              onTap: isPending ? null : () {
                                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SpottedCarDetailScreen(carId: carId, carData: carData)));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    // --- L'IMAGE ---
                                    SizedBox(
                                      width: 110,
                                      height: 90,
                                      child: Hero(
                                        tag: 'carImage_$carId',
                                        child: CarImageCard(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                      ),
                                    ),
                                    
                                    // --- ESPACE ET TEXTE ---
                                    Expanded(
                                      child: Padding(
                                        // === LA CORRECTION EST ICI : AJOUTER UN PADDING À GAUCHE ===
                                        padding: const EdgeInsets.only(left: 25.0), 
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center, // Garder le centrage vertical
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                    child: Text('$brandName $modelName',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                                if (isPending)
                                                  const Tooltip(
                                                    message: "En attente de synchronisation",
                                                    child: Icon(Icons.cloud_off, size: 18, color: Colors.orange),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(plate,
                                                style: const TextStyle(
                                                    fontSize: 16, color: Colors.black87, fontFamily: 'monospace')),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // --- LA POUBELLE ---
                                    IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: isPending ? null : () {
                                          AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                                          _deleteCar(carId, '$brandName $modelName');
                                        }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<ConnectivityService>(
        builder: (context, connectivityService, child) {
          final bool isOnline = connectivityService.isOnline;
          return FloatingActionButton(
            onPressed: isOnline
                ? () async {
                    Provider.of<AudioService>(context, listen: false).playSfx(SoundEffect.clicPrincipal);
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddCarScreen()),
                    );
                    if (result != null) {
                      _loadPendingSpots();
                    }
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Une connexion internet est requise pour ajouter une voiture."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
            backgroundColor:
                isOnline ? Theme.of(context).primaryColor : Colors.grey[400],
            tooltip: isOnline ? 'Ajouter une voiture' : 'Connexion requise',
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.directions_car_filled_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 27.0, right: 33.0),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // Petite fonction helper pour la comparaison de date
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}