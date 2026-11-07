// Fichier: lib/map_screen.dart (Version Finale, TEMPS RÉEL avec StreamBuilder)

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:spot_my_car/services/auth_service.dart'; // Adaptez le chemin selon votre structure
import 'package:spot_my_car/auth_gate.dart'; // <-- LA LIGNE MANQUANTE
import 'package:spot_my_car/services/audio_service.dart';


// Le modèle SpotPoint ne change pas
class SpotPoint {
  final String id;
  final LatLng point;
  final Map<String, dynamic> carData;
  SpotPoint({required this.id, required this.point, required this.carData});
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}
 
class _MapScreenState extends State<MapScreen>
  with AutomaticKeepAliveClientMixin {
  bool _isSigningOut = false;
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  bool _isRotationEnabled = false;
  static const LatLng _defaultCenter = LatLng(46.603354, 1.888334);
  static const double _defaultZoom = 5.2;

  @override
  void dispose() {
    // Annulez explicitement le StreamBuilder
    _mapController.dispose();
    super.dispose();
  }

  int _buildInteractionFlags() {
    // Les flags de base, toujours activés
    int flags = InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom;
    
    // Si le mode rotation est activé, on ajoute le flag de rotation
    if (_isRotationEnabled) {
      flags |= InteractiveFlag.rotate; // L'opérateur |= ajoute le flag à la liste existante
    }
    
    return flags;
  }

  Widget _buildSpotImage(Map<String, dynamic> carData) {
    final userPhotoUrl = carData['userPhotoUrl'] as String?;
    final modelImageUrl = carData['modelImageUrl'] as String?;
    final brandId = carData['brandId'] as String?;
    final isCatalogued = carData['isCatalogued'] as bool? ?? false;

    // Cas 1 : Photo de l'utilisateur (inchangé)
    if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
      return Image.network(
        userPhotoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (c, e, s) =>
            const Icon(Icons.sync_problem, size: 40, color: Colors.grey),
      );
    }
    // Cas 2 : Image du modèle (inchangé)
    else if (isCatalogued && modelImageUrl != null && modelImageUrl.isNotEmpty) {
      return Image.network(
        modelImageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (c, e, s) =>
            const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      );
    }
    // ==========================================================
    // === LA CORRECTION EST ICI ================================
    // ==========================================================
    // Cas 3 : Logo de la marque
    else if (isCatalogued && brandId != null && brandId.isNotEmpty) {
      // On reconstruit l'URL publique du logo.
      // Cette méthode suppose que le nom du fichier du logo est `[brandId].png`
      const projectId = "car-spotter-app-779f2";
      final logoUrl =
          "https://firebasestorage.googleapis.com/v0/b/$projectId.appspot.com/o/logos%2F$brandId.png?alt=media";

      return Image.network(
        logoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (c, e, s) =>
            const Icon(Icons.directions_car, size: 50, color: Colors.grey),
      );
    }
    // ==========================================================
    // Cas 4 : Icône par défaut
    else {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
      );
    }
  }

  void _showSpotInfo(BuildContext context, SpotPoint spot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final brandName = spot.carData['brandName'] ?? 'Marque Inconnue';
        final modelName = spot.carData['modelName'] ?? 'Modèle Inconnu';
        final plate = spot.carData['plate'] ?? 'N/A';
        final location = spot.carData['locationName'] as String?;
        final timestamp = spot.carData['spottedAt'] as Timestamp?;

        final String date;
        if (timestamp != null) {
          date = DateFormat("'Le' dd/MM/yyyy", 'fr_FR').format(timestamp.toDate());
        } else {
          date = 'Date inconnue';
        }

        return GestureDetector(
          onTap: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            Navigator.of(context).pop();
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpottedCarDetailScreen(
                      carId: spot.id, carData: spot.carData),
                ));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 150,
            child: Row(
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildSpotImage(spot.carData),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$brandName $modelName',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(plate,
                          style: const TextStyle(
                              fontSize: 14, fontFamily: 'monospace')),
                      const SizedBox(height: 8),
                      if (location != null && location.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(location,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      if (timestamp != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(date,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                      const Spacer(),
                      const Text("Appuyez pour voir les détails...",
                          style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // --- NOUVEAU : On récupère l'utilisateur ---
    final user = FirebaseAuth.instance.currentUser;

    // --- NOUVEAU : On ajoute la garde de sécurité ---
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte des Spots')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si l'utilisateur existe, on retourne le Scaffold normal (ton ancien code)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des Spots'),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('spotted_cars')
            .where('userId', isEqualTo: user.uid) // On est sûr que user.uid existe
            .where('locationCoords', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text("Erreur de chargement de la carte."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildMapWidget([]);
          }
          final spotPoints = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final coordsData = data['locationCoords'];
            if (coordsData is GeoPoint) {
              return SpotPoint(
                id: doc.id,
                point: LatLng(coordsData.latitude, coordsData.longitude),
                carData: data,
              );
            } else {
              return null;
            }
          }).where((spot) => spot != null)
            .cast<SpotPoint>()
            .toList();
          return _buildMapWidget(spotPoints);
        },
      ),
    );
  }

  Widget _buildMapWidget(List<SpotPoint> spotPoints) {
    final List<Marker> markers = spotPoints.map((spot) {
      return Marker(
        width: 30.0,
        height: 30.0,
        point: spot.point,
        child: GestureDetector(
          onTap: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            _showSpotInfo(context, spot);
          },
          child:
              Icon(Icons.location_pin, size: 30, color: Theme.of(context).primaryColor),
        ),
      );
    }).toList();

      return Stack(
        children: [
          // La carte elle-même
          Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy;
                final zoomChange = delta > 0 ? -0.2 : 0.2;
                final newZoom =
                    (_mapController.camera.zoom + zoomChange).clamp(2.0, 18.0);
                _mapController.move(_mapController.camera.center, newZoom);
              }
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(46.603354, 1.888334),
                initialZoom: 5.2,
                maxZoom: 18.0,
                interactionOptions: InteractionOptions(
                  flags: _buildInteractionFlags(),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.spot_my_car',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    // On ajoute l'action de zoomer avec un son
                    onClusterTap: (cluster) => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).primaryColor,
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                    markers: markers,
                  ),
                ),
              ],
            ),
          ),

          // Les boutons de zoom, en haut à DROITE
          Positioned(
            top: 16.0,
            right: 16.0,
            child: Column(
              children: <Widget>[
                FloatingActionButton(
                  heroTag: "zoom_in_button",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    final newZoom =
                        (_mapController.camera.zoom + 1).clamp(2.0, 18.0);
                    _mapController.move(_mapController.camera.center, newZoom);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoom_out_button",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    final newZoom =
                        (_mapController.camera.zoom - 1).clamp(2.0, 18.0);
                    _mapController.move(_mapController.camera.center, newZoom);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          Positioned(
          bottom: 16.0,
          right: 16.0,
          // On utilise une Column pour empiler les boutons verticalement
          child: Column(
            children: [
              // Le bouton de rotation est maintenant ici (en haut de la colonne)
              FloatingActionButton(
                heroTag: "rotate_button",
                mini: true, // On le garde en "mini" comme tu l'as demandé
                backgroundColor: _isRotationEnabled ? Theme.of(context).primaryColor : Colors.white,
                foregroundColor: _isRotationEnabled ? Colors.white : Theme.of(context).primaryColor,
                onPressed: () {
                  AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                  setState(() {
                    _isRotationEnabled = !_isRotationEnabled;
                    if (!_isRotationEnabled) {
                      _mapController.rotate(0);
                    }
                  });
                },
                child: Icon(_isRotationEnabled ? Icons.explore : Icons.explore_off),
              ),
              const SizedBox(height: 8), // Espace entre les deux boutons

              // Le bouton de recentrage est ici (en bas de la colonne)
              FloatingActionButton(
                heroTag: "recenter_button",
                // On le met en "mini" aussi pour que ce soit cohérent visuellement
                mini: true, 
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                onPressed: () {
                  AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                  _mapController.moveAndRotate(_defaultCenter, _defaultZoom, 0);
                },
                child: const Icon(Icons.map_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
    }