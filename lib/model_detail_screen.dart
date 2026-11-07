import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart' show PhotoCredit;
// Fichier: lib/model_detail_screen.dart (Version VRAIMENT, VRAIMENT Finale et Corrigée - 100% Complète)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:spot_my_car/widgets/car_image_card.dart';
import 'package:spot_my_car/services/audio_service.dart';

// La map des icônes ne change pas.
const Map<String, IconData> specIcons = {
  'Puissance': Icons.flash_on_outlined,
  '0-100 km/h': Icons.timer_outlined,
  'Vitesse Max': Icons.speed_outlined,
  'Carburant': Icons.local_gas_station_outlined,
  'Consommation': Icons.opacity_outlined,
  'Poids': Icons.scale_outlined,
  'Dimensions (L/l/h)': Icons.straighten_outlined,
  'Prix de lancement': Icons.euro_symbol_outlined,
};

class ModelDetailScreen extends StatefulWidget {
  final List<dynamic> modelsList;
  final int initialIndex;
  final bool isSpotted;
  final Map<String, dynamic> brand;

  const ModelDetailScreen({
    super.key, 
    required this.modelsList, 
    required this.initialIndex, 
    required this.isSpotted,
    required this.brand,
  });

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  late int _currentIndex;
  late Map<String, dynamic> _currentModel;
  
  String _formatConsumption(String value) {
    if (value.contains('L/100km')) {
      return value.replaceAll('L/100km', ' L / 100 km');
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentModel = widget.modelsList[_currentIndex];
  }
  
  String? _formatDimensions(String? dimsInMm) {
    if (dimsInMm == null || dimsInMm.isEmpty) return null;
    List<String> parts = dimsInMm.split(' x ');
    if (parts.length != 3) return dimsInMm;
    try {
      double lengthM = (double.parse(parts[0].trim())) / 1000.0;
      double widthM = (double.parse(parts[1].trim())) / 1000.0;
      double heightM = (double.parse(parts[2].trim())) / 1000.0;
      String lengthStr = lengthM.toStringAsFixed(3).replaceAll('.', ',');
      String widthStr = widthM.toStringAsFixed(3).replaceAll('.', ',');
      String heightStr = heightM.toStringAsFixed(3).replaceAll('.', ',');
      return '$lengthStr / $widthStr / $heightStr m';
    } catch (e) { return dimsInMm; }
  }

  String? _formatPrice(dynamic priceRaw) {
    if (priceRaw == null) return null;
    try {
      final priceInt = int.parse(priceRaw.toString());
      final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
      return formatter.format(priceInt);
    } catch (e) { return "${priceRaw.toString()} €"; }
  }

  void _goToNext() {
    if (_currentIndex < widget.modelsList.length - 1) {
      AudioService.instance.playSfx(SoundEffect.transitionPage); // <-- SON AJOUTÉ
      setState(() { _currentIndex++; _currentModel = widget.modelsList[_currentIndex]; });
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      AudioService.instance.playSfx(SoundEffect.transitionPage); // <-- SON AJOUTÉ
      setState(() { _currentIndex--; _currentModel = widget.modelsList[_currentIndex]; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final imageFileName = _currentModel['imageUrl'] as String?;
    final Map<String, String?> dataToShow = {
      'Puissance': _currentModel['puissance_ch'] != null ? '${_currentModel['puissance_ch']} ch' : null,
      'Vitesse Max': _currentModel['vitesse_max_kmh'] != null ? '${_currentModel['vitesse_max_kmh']} km/h' : null,
      '0-100 km/h': _currentModel['zero_a_cent_s'] != null ? '${_currentModel['zero_a_cent_s']} s' : null,
      'Poids': _currentModel['poids_kg'] != null ? '${_currentModel['poids_kg']} kg' : null,
      'Carburant': _currentModel['type_carburant']?.toString(),
      'Consommation': _currentModel['consommation_mixte'] != null 
          ? _formatConsumption(_currentModel['consommation_mixte'].toString()) 
          : null,
      'Prix de lancement': _formatPrice(_currentModel['prix_lancement_eur']),
    };

    Widget navigationBar = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        children: [
          // Le bouton "Précédent"
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _currentIndex > 0 ? Colors.black54 : Colors.grey[300]),
            onPressed: _currentIndex > 0 ? _goToPrevious : null,
          ),
          
          // La barre de progression interactive
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0), // Point un peu plus gros pour être facile à saisir
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0), // Halo de feedback au toucher
                
                // === COULEURS BLEU FONCÉ ===
                activeTrackColor: Theme.of(context).primaryColor,     // Partie remplie de la barre
                inactiveTrackColor: Colors.black26,              // Partie vide de la barre
                thumbColor: Theme.of(context).primaryColor,            // Couleur du point
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2), // Couleur du halo
              ),
              child: Slider(
                value: _currentIndex.toDouble(),
                min: 0,
                // On s'assure que max est au moins 0 pour éviter les erreurs si la liste est vide ou n'a qu'un seul élément
                max: (widget.modelsList.length - 1).toDouble().clamp(0.0, double.infinity),
                // divisions permet au slider de se "clipser" sur chaque modèle
                divisions: (widget.modelsList.length - 1) > 0 ? (widget.modelsList.length - 1) : null,

                // === LA LOGIQUE INTERACTIVE EST ICI ===
                onChanged: (double value) {
                  setState(() {
                    // On met à jour l'index et le modèle actuel
                    _currentIndex = value.round();
                    _currentModel = widget.modelsList[_currentIndex];
                  });
                },
                // On ajoute le son quand l'utilisateur a fini de bouger le slider
                onChangeEnd: (double value) {
                  AudioService.instance.playSfx(SoundEffect.transitionPage); // <-- SON AJOUTÉ
                },
              ),
            ),
          ),
          
          // Le bouton "Suivant"
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: _currentIndex < widget.modelsList.length - 1 ? Colors.black54 : Colors.grey[300]),
            onPressed: _currentIndex < widget.modelsList.length - 1 ? _goToNext : null,
          ),
        ],
      ),
    );
    
    // Si on est sur le web, on utilise le design avec le grand header
    if (kIsWeb) {
      return Scaffold(
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -500) _goToNext();
            else if (details.primaryVelocity! > 500) _goToPrevious();
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                // On ajoute le bouton de retour manuellement pour y mettre un son
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    Navigator.of(context).pop();
                  },
                ),
                expandedHeight: 300, pinned: true, foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(_currentModel['name'] ?? 'Modèle inconnu', style: const TextStyle(shadows: [Shadow(blurRadius: 2, color: Colors.black87)])),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CarImage(urls: [imageFileName], brandName: widget.brand['name'] as String?, modelName: _currentModel['name'] as String?),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    navigationBar,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.brand['name']} ${_currentModel['name']}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (_currentModel['production_years'] != null)
                             Text('Production de ${_currentModel['production_years']}', style: TextStyle(fontSize: 16, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                          if (_currentModel['imageCredit'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: PhotoCredit(model: Map<String, dynamic>.from(_currentModel))),
                          const SizedBox(height: 28),
                          const Text("Fiche Technique", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                            ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                // On affiche toutes les autres specs comme avant
                                ...dataToShow.entries
                                  .where((entry) => entry.value != null && entry.value!.isNotEmpty)
                                  .map((entry) {
                                    return ListTile(
                                      leading: Icon(
                                        specIcons[entry.key] ?? Icons.info_outline,
                                        color: Colors.grey[600],
                                      ),
                                      title: Text(entry.key, style: const TextStyle(fontSize: 16)),
                                      trailing: Text(
                                        entry.value!,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    );
                                  }),

                                // On crée maintenant les 3 lignes pour les dimensions
                                Builder(
                                  builder: (context) {
                                    final dimsRaw = _currentModel['dimensions_lwh_mm']?.toString();
                                    if (dimsRaw == null || !dimsRaw.contains('x')) {
                                      return const SizedBox.shrink();
                                    }
                                    final parts = dimsRaw.split('x').map((e) => e.trim()).toList();
                                    if (parts.length != 3) {
                                      return const SizedBox.shrink();
                                    }
                                    final lengthM = (double.tryParse(parts[0]) ?? 0) / 1000.0;
                                    final widthM = (double.tryParse(parts[1]) ?? 0) / 1000.0;
                                    final heightM = (double.tryParse(parts[2]) ?? 0) / 1000.0;
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.north_east, color: Colors.grey[600]),
                                          title: const Text("Longueur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${lengthM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.east, color: Colors.grey[600]),
                                          title: const Text("Largeur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${widthM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.north, color: Colors.grey[600]),
                                          title: const Text("Hauteur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${heightM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),

                          const SizedBox(height: 28),
                            const Text("Mes Spots pour ce modèle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: currentUser.uid).where('modelId', isEqualTo: _currentModel['id']).orderBy('spottedAt', descending: true).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return const Card(color: Color.fromARGB(255, 235, 240, 255), child: ListTile(leading: Icon(Icons.search_off), title: Text("Pas encore spotté !"), subtitle: Text("Pars à sa recherche pour l'ajouter à ta collection.")));
                                }
                                final spottedList = snapshot.data!.docs;
                                return ListView.separated(
                                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                  itemCount: spottedList.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final spot = spottedList[index].data() as Map<String, dynamic>;
                                    final plate = spot['plate'] ?? 'N/A';
                                    final timestamp = spot['spottedAt'] as Timestamp?;
                                    final date = timestamp != null ? DateFormat('le dd/MM/yyyy à HH:mm', 'fr_FR').format(timestamp.toDate()) : 'Date inconnue';
                                    return ListTile(
                                      leading: Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor),
                                      title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      subtitle: Text("Spottée $date"),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    } 
    // Sinon (sur mobile), on garde le nouveau design "Showroom"
    // Sinon (sur mobile), on garde le nouveau design "Showroom"
    else {
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
          title: Text(_currentModel['name'] ?? 'Détails du modèle'), 
          backgroundColor: Theme.of(context).primaryColor, 
          foregroundColor: Colors.white
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -500) _goToNext();
            else if (details.primaryVelocity! > 500) _goToPrevious();
          },
          child: Column(
            children: [
               SizedBox(
                height: 250, // On remet la hauteur à 250 pour être identique
                width: double.infinity, // On force la largeur maximale
                child: CarImageCard(
                  imageUrl: imageFileName,
                  fit: BoxFit.cover, // On force le mode 'cover'
                  borderRadius: BorderRadius.circular(12),
                ),
              ),             
              navigationBar,
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${widget.brand['name']} ${_currentModel['name']}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),                    
                    const SizedBox(height: 4),
                    if (_currentModel['production_years'] != null) Text('Production de ${_currentModel['production_years']}', style: TextStyle(fontSize: 16, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                    const SizedBox(height: 20),
                    const Text("Fiche Technique", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                            ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                // On affiche toutes les autres specs comme avant
                                ...dataToShow.entries
                                  .where((entry) => entry.value != null && entry.value!.isNotEmpty)
                                  .map((entry) {
                                    return ListTile(
                                      leading: Icon(
                                        specIcons[entry.key] ?? Icons.info_outline,
                                        color: Colors.grey[600],
                                      ),
                                      title: Text(entry.key, style: const TextStyle(fontSize: 16)),
                                      trailing: Text(
                                        entry.value!,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    );
                                  }),

                                // On crée maintenant les 3 lignes pour les dimensions
                                Builder(
                                  builder: (context) {
                                    final dimsRaw = _currentModel['dimensions_lwh_mm']?.toString();
                                    if (dimsRaw == null || !dimsRaw.contains('x')) {
                                      return const SizedBox.shrink();
                                    }
                                    final parts = dimsRaw.split('x').map((e) => e.trim()).toList();
                                    if (parts.length != 3) {
                                      return const SizedBox.shrink();
                                    }
                                    final lengthM = (double.tryParse(parts[0]) ?? 0) / 1000.0;
                                    final widthM = (double.tryParse(parts[1]) ?? 0) / 1000.0;
                                    final heightM = (double.tryParse(parts[2]) ?? 0) / 1000.0;
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.north_east, color: Colors.grey[600]),
                                          title: const Text("Longueur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${lengthM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.east, color: Colors.grey[600]),
                                          title: const Text("Largeur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${widthM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.north, color: Colors.grey[600]),
                                          title: const Text("Hauteur", style: TextStyle(fontSize: 16)),
                                          trailing: Text("${heightM.toStringAsFixed(2).replaceAll('.', ',')} m", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),

                            if (_currentModel['imageCredit'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: PhotoCredit(model: Map<String, dynamic>.from(_currentModel))),
                          const SizedBox(height: 28),
                            const Text("Mes Spots pour ce modèle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: currentUser.uid).where('modelId', isEqualTo: _currentModel['id']).orderBy('spottedAt', descending: true).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return const Card(color: Color.fromARGB(255, 235, 240, 255), child: ListTile(leading: Icon(Icons.search_off), title: Text("Pas encore spotté !"), subtitle: Text("Pars à sa recherche pour l'ajouter à ta collection.")));
                                }
                                final spottedList = snapshot.data!.docs;
                                return ListView.separated(
                                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                  itemCount: spottedList.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final spot = spottedList[index].data() as Map<String, dynamic>;
                                    final plate = spot['plate'] ?? 'N/A';
                                    final timestamp = spot['spottedAt'] as Timestamp?;
                                    final date = timestamp != null ? DateFormat('le dd/MM/yyyy à HH:mm', 'fr_FR').format(timestamp.toDate()) : 'Date inconnue';
                                    return ListTile(
                                      leading: Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor),
                                      title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      subtitle: Text("Spottée $date"),
                                    );
                                  },
                                );
                              },
                            ),
                  ])),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}