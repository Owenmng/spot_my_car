// Fichier: lib/spotted_car_detail_screen.dart (Version Finale, Corrigée)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spot_my_car/shared/app_data.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:spot_my_car/widgets/car_image_card.dart';
import 'package:spot_my_car/services/audio_service.dart';

const Map<String, IconData> specIcons = {
  'Puissance': Icons.flash_on_outlined,
  '0-100 km/h': Icons.timer_outlined,
  'Vitesse Max': Icons.speed_outlined,
  'Carburant': Icons.local_gas_station_outlined,
  'Consommation': Icons.opacity_outlined,
  'Poids': Icons.scale_outlined,
  'Prix de lancement': Icons.euro_symbol_outlined,
  'Longueur': Icons.north_east,
  'Largeur': Icons.east,
  'Hauteur': Icons.north,
};

class SpottedCarDetailScreen extends StatelessWidget {
  final String carId;
  final Map<String, dynamic> carData;

  const SpottedCarDetailScreen({
    super.key,
    required this.carId,
    required this.carData,
  });

  void _showEditSpotInfoDialog(BuildContext context, Map<String, dynamic> currentData) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _EditSpotDialog(
          currentData: currentData,
          carId: carId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plate = carData['plate'] ?? 'N/A';
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
        title: Text(plate), 
        backgroundColor: Theme.of(context).primaryColor, 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('spotted_cars').doc(carId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text("Impossible de charger les données de la voiture."));
          }

          final updatedCarData = snapshot.data!.data() as Map<String, dynamic>;
          final brandName = updatedCarData['brandName'] ?? 'Marque Inconnue';
          final modelName = _cleanModelName(updatedCarData['modelName'] ?? 'Modèle Inconnu');
          final userPhotoUrl = updatedCarData['userPhotoUrl'] as String?;
          final modelImageUrl = updatedCarData['modelImageUrl'] as String?;
          final brandId = updatedCarData['brandId'] as String?;
          final location = updatedCarData['locationName'] as String?;
          final color = updatedCarData['color'] as String?;
          final isCatalogued = updatedCarData['isCatalogued'] as bool? ?? false;
          final String displayColor = (color == null || color.isEmpty) ? "Non renseignée" : color;
          final String displayLocation = (location == null || location.isEmpty) ? "Non renseigné" : location;

          String? imageUrl;

          if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
            imageUrl = userPhotoUrl;
          } else if (isCatalogued && modelImageUrl != null && modelImageUrl.isNotEmpty) {
            imageUrl = modelImageUrl;
          } else if (isCatalogued && brandId != null && brandId.isNotEmpty) {
            const projectId = "car-spotter-app-779f2";
            imageUrl = "https://firebasestorage.googleapis.com/v0/b/$projectId.appspot.com/o/logos%2F$brandId.png?alt=media";
          }

          return ListView(children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Hero(
                tag: 'carImage_$carId',
                // On utilise notre widget réutilisable ici
                child: CarImageCard(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  placeholder: Container(color: Colors.black87, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
                  errorWidget: Container(color: Colors.black87, child: const Center(child: Icon(Icons.sync_problem, color: Colors.white, size: 50))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Builder(builder: (context) {
                  final bool modelContainsBrand = modelName.toLowerCase().contains(brandName.toLowerCase());
                  final String titleText = modelContainsBrand ? modelName : '$brandName $modelName';
                  return Text(titleText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                }),
                if (updatedCarData['production_years'] != null && updatedCarData['production_years'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Production de ${updatedCarData['production_years']}', style: TextStyle(fontSize: 16, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                  ),
                const Divider(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("Informations du Spot", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Theme.of(context).primaryColor),
                      onPressed: () async {
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        await AppData.loadWorldCities();
                        _showEditSpotInfoDialog(context, updatedCarData);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.color_lens_outlined, "Couleur", displayColor),
                Builder(builder: (context) {
                  final parts = displayLocation.contains(' - ') ? displayLocation.split(' - ') : [displayLocation, ''];
                  final city = parts[0].trim();
                  final country = parts.length > 1 ? parts[1].trim() : '';
                  const cityStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black);
                  const  countryStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 16),
                        const Text("Lieu du spot :", style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LayoutBuilder(builder: (context, constraints) {
                            final textPainter = TextPainter(
                              text: TextSpan(
                                style: cityStyle,
                                children: [
                                  TextSpan(text: city),
                                  if (country.isNotEmpty) TextSpan(text: ', $country', style: countryStyle),
                                ],
                              ),
                              maxLines: 1, textDirection: TextDirection.ltr,
                            )..layout(maxWidth: double.infinity);
                            if (textPainter.size.width > constraints.maxWidth) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(city, style: cityStyle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                                  if (country.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(country, style: countryStyle, textAlign: TextAlign.right),
                                    ),
                                ],
                              );
                            } else {
                              return RichText(textAlign: TextAlign.right, text: textPainter.text!, maxLines: 1, overflow: TextOverflow.ellipsis);
                            }
                          }),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 40),
                const Text("Fiche Technique", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildTechSheet(updatedCarData),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  // ==========================================================
  // === FONCTIONS HELPERS DANS LE BON ORDRE ==================
  // ==========================================================

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Text('$label :', style: const TextStyle(fontSize: 16)),
        const Expanded(
          child: SizedBox(width: 16),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
          softWrap: false,
        ),
      ]),
    );
  }

  Widget _buildTechSheet(Map<String, dynamic> currentCarData) {
    Map<String, dynamic> dataToShow = {};
    if (currentCarData['scrapedData'] != null) {
      dataToShow = currentCarData['scrapedData'];
    } else if (currentCarData['isCatalogued'] == true) {
      dataToShow = {
        if (currentCarData['puissance_ch'] != null) 'Puissance': '${currentCarData['puissance_ch']} ch',
        if (currentCarData['zero_a_cent_s'] != null) '0-100 km/h': '${currentCarData['zero_a_cent_s']} s',
        if (currentCarData['vitesse_max_kmh'] != null) 'Vitesse Max': '${currentCarData['vitesse_max_kmh']} km/h',
        if (currentCarData['type_carburant'] != null) 'Carburant': currentCarData['type_carburant'],
        if (currentCarData['consommation_mixte'] != null) 'Consommation': currentCarData['consommation_mixte'],
        if (currentCarData['poids_kg'] != null) 'Poids': '${currentCarData['poids_kg']} kg',
        if (currentCarData['prix_lancement_eur'] != null) 'Prix de lancement': '${currentCarData['prix_lancement_eur']} €',
      };
    }

    if (dataToShow.isEmpty) {
      return const Text("Aucune information technique disponible.", style: TextStyle(fontStyle: FontStyle.italic));
    }

    final List<Widget> techRows = [];
    
    const hiddenKeys = ['make', 'model', 'brandName', 'modelName', 'brandId', 'modelId', 'userId', 'spottedAt', 'userPhotoUrl', 'plateCountryCode', 'isCatalogued', 'modelImageUrl', 'scrapedData', 'dimensions_lwh_mm'];
    final dataEntries = dataToShow.entries.where((e) => e.value != null && e.value.toString().isNotEmpty && !hiddenKeys.contains(e.key)).toList();

    for (var entry in dataEntries) {
      techRows.add(_buildInfoRow(
        specIcons[entry.key] ?? _getIconForKey(entry.key),
        _formatKey(entry.key),
        _cleanValue(entry.key, entry.value.toString()),
      ));
    }

    final String? dimsInMm = currentCarData['dimensions_lwh_mm']?.toString();
    if (dimsInMm != null && dimsInMm.isNotEmpty) {
      List<String> parts = dimsInMm.split(' x ');
      if (parts.length == 3) {
        try {
          final lengthM = (double.parse(parts[0].trim()) / 1000.0).toStringAsFixed(2).replaceAll('.', ',');
          final widthM = (double.parse(parts[1].trim()) / 1000.0).toStringAsFixed(2).replaceAll('.', ',');
          final heightM = (double.parse(parts[2].trim()) / 1000.0).toStringAsFixed(2).replaceAll('.', ',');
          
          techRows.add(_buildInfoRow(specIcons['Longueur']!, 'Longueur', '$lengthM m'));
          techRows.add(_buildInfoRow(specIcons['Largeur']!, 'Largeur', '$widthM m'));
          techRows.add(_buildInfoRow(specIcons['Hauteur']!, 'Hauteur', '$heightM m'));
        } catch (e) { /* Ignore */ }
      }
    }

    return Column(children: techRows);
  }

  IconData _getIconForKey(String key) {
    if (key.contains('moteur')) return Icons.settings;
    if (key.contains('vitesse')) return Icons.speed;
    if (key.contains('puissance')) return Icons.flash_on;
    if (key.contains('carburant')) return Icons.local_gas_station;
    return Icons.info_outline;
  }

  String _cleanModelName(String modelName) {
    final parenthesisIndex = modelName.indexOf('(');
    if (parenthesisIndex != -1) return modelName.substring(0, parenthesisIndex).trim();
    return modelName;
  }

  String _formatKey(String key) {
    if (key == 'registration' || key == 'plate') return 'Immatriculation';
    if (specIcons.containsKey(key)) return key;
    return key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
  }

  String _formatConsumption(String value) {
    if (value.contains('L/100km')) {
      return value.replaceAll('L/100km', ' L / 100 km');
    }
    return value;
  }

  String _cleanValue(String key, String value) {
    if (key == 'volume_bagages') return value.replaceAll('до ', '');
    if (key == 'Consommation') {
      return _formatConsumption(value);
    }
    return value;
  }
}

// Dialog Class
class _EditSpotDialog extends StatefulWidget {
  final Map<String, dynamic> currentData;
  final String carId;
  const _EditSpotDialog({required this.currentData, required this.carId});
  @override
  State<_EditSpotDialog> createState() => _EditSpotDialogState();
}

class _EditSpotDialogState extends State<_EditSpotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationController;
  late final FocusNode _locationFocusNode;
  Map<String, dynamic>? _selectedColorMap;
  Map<String, dynamic>? _selectedCityMap;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
    _locationFocusNode = FocusNode();
    final currentColorName = widget.currentData['color'] as String?;
    if (currentColorName != null) {
      try {
        _selectedColorMap = carColors.firstWhere((c) => c['name'] == currentColorName);
      } catch (e) { /* ignore */ }
    }
    final String? currentLocation = widget.currentData['locationName'];
    if (currentLocation != null && currentLocation.isNotEmpty) {
      _locationController.text = currentLocation;
      final locationParts = currentLocation.split(' - ');
      final cityName = locationParts[0].trim();
      try {
        _selectedCityMap = AppData.worldCities.firstWhere((city) => city['nom'].toString() == cityName);
      } catch (e) { /* _selectedCityMap reste null */ }
    }
    _locationFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_locationFocusNode.hasFocus && mounted) {
      String expectedText = '';
      if (_selectedCityMap != null) {
        final country = _selectedCityMap!['pays'] as String?;
        expectedText = (country != null && country.isNotEmpty)
            ? '${_selectedCityMap!['nom']} - $country'
            : _selectedCityMap!['nom'].toString();
      }
      if (_locationController.text != expectedText) {
        setState(() {
          _locationController.clear();
          _selectedCityMap = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationFocusNode.removeListener(_onFocusChange);
    _locationController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Modifier le spot"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedColorMap,
                onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                decoration: const InputDecoration(labelText: 'Couleur', border: OutlineInputBorder()),
                items: carColors.map((colorMap) => DropdownMenuItem<Map<String, dynamic>>(value: colorMap, child: Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: colorMap['color'], shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade400))), const SizedBox(width: 10), Text(colorMap['name']) ]))).toList(),
                onChanged: (newValue) {
                  AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                  setState(() => _selectedColorMap = newValue);
                },
              ),
              const SizedBox(height: 16),
              TypeAheadField<Map<String, dynamic>>(
                controller: _locationController,
                focusNode: _locationFocusNode,
                debounceDuration: const Duration(milliseconds: 200),
                builder: (context, controller, focusNode) => TextFormField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: 'Lieu du spot (ville)', hintText: 'Commencez à taper...', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
                suggestionsCallback: (pattern) => pattern.isEmpty ? [] : AppData.worldCities.where((city) => city['nom'].toString().toLowerCase().startsWith(pattern.toLowerCase())).toList(),
                itemBuilder: (context, Map<String, dynamic> suggestion) => ListTile(leading: const Icon(Icons.location_city), title: Text('${suggestion['nom']}')),
                onSelected: (Map<String, dynamic> selection) {
                  AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                  final country = selection['pays'] as String?;
                  final locationText = (country != null && country.isNotEmpty) ? '${selection['nom']} - $country' : selection['nom'].toString();
                  _locationController.text = locationText;
                  setState(() => _selectedCityMap = selection);
                  FocusScope.of(context).unfocus();
                },
                emptyBuilder: (context) => const Padding(padding: EdgeInsets.all(12.0), child: Text('Aucune ville trouvée.', style: TextStyle(color: Colors.grey))),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Annuler"), 
          onPressed: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger);
            Navigator.of(context).pop();
          }
        ),
        ElevatedButton(
          child: const Text("Enregistrer"), 
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              _saveChanges();
            } else {
              AudioService.instance.playSfx(SoundEffect.clicLeger);
            }
          }
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        String? locationNameToSave;
        if (_selectedCityMap != null) {
          final country = _selectedCityMap!['pays'] as String?;
          locationNameToSave = (country != null && country.isNotEmpty) ? '${_selectedCityMap!['nom']} - $country' : _selectedCityMap!['nom'].toString();
        } else if (_locationController.text.isNotEmpty) {
          locationNameToSave = _locationController.text;
        }
        await FirebaseFirestore.instance.collection('spotted_cars').doc(widget.carId).update({
          'color': _selectedColorMap?['name'],
          'locationName': locationNameToSave,
          'locationCoords': _selectedCityMap != null ? GeoPoint(_selectedCityMap!['latitude'], _selectedCityMap!['longitude']) : null,
        });
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations mises à jour !'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la mise à jour: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}