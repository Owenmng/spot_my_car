// Fichier: lib/add_car_screen.dart (Version Finale, Complète avec choix Photo/Caméra sur TOUTES les plateformes)

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/shared/app_data.dart';
import 'package:spot_my_car/achievement_overlay.dart'; 
import 'package:spot_my_car/level_up_overlay.dart'; 
import 'package:spot_my_car/brand_selection_screen.dart'; 
import 'package:spot_my_car/model_selection_screen.dart'; 
import 'package:spot_my_car/plate_input_formatter.dart'; 
import 'package:spot_my_car/shared/plate_formats.dart';
import 'package:spot_my_car/ml_service.dart'; // Adapte le chemin si besoin
import 'package:spot_my_car/services/audio_service.dart';


final List<Map<String, String>> countryData = [
  {'code': 'FR', 'name': 'France', 'flag': '🇫🇷', 'hint': 'AB-123-CD'},
  {'code': 'DE', 'name': 'Allemagne', 'flag': '🇩🇪', 'hint': 'B SK 1234'},
  {'code': 'IT', 'name': 'Italie', 'flag': '🇮🇹', 'hint': 'AB 123 CD'},
  {'code': 'ES', 'name': 'Espagne', 'flag': '🇪🇸', 'hint': '1234 ABC'},
  {'code': 'GB', 'name': 'Royaume-Uni', 'flag': '🇬🇧', 'hint': 'AB12 CDE'},
  {'code': 'BE', 'name': 'Belgique', 'flag': '🇧🇪', 'hint': '1-ABC-234'},
  {'code': 'CH', 'name': 'Suisse', 'flag': '🇨🇭', 'hint': 'VD 123456'},
  {'code': 'LU', 'name': 'Luxembourg', 'flag': '🇱🇺', 'hint': 'AB 1234'},
  {'code': 'AT', 'name': 'Autriche', 'flag': '🇦🇹', 'hint': 'W 123 AB'},
  {'code': 'US', 'name': 'États-Unis', 'flag': '🇺🇸', 'hint': 'ABC 1234'},
  {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦', 'hint': 'ABCD 123'},
  {'code': 'XX', 'name': 'Autre', 'flag': '🌍', 'hint': 'Format libre'},
];
final List<Map<String, dynamic>> carColors = [
  {'name': 'Noir', 'color': Colors.black},{'name': 'Blanc', 'color': Colors.white},
  {'name': 'Gris', 'color': Colors.grey},{'name': 'Argent', 'color': Colors.blueGrey[100]!},
  {'name': 'Rouge', 'color': Colors.red},{'name': 'Bleu', 'color': Colors.blue},
  {'name': 'Vert', 'color': Colors.green},{'name': 'Jaune', 'color': Colors.yellow},
  {'name': 'Orange', 'color': Colors.orange},{'name': 'Violet', 'color': Colors.purple},
  {'name': 'Marron', 'color': Colors.brown},{'name': 'Beige', 'color': Colors.brown[100]!},
];
enum AddCarMode { manual, automatic }

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});
  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  AddCarMode _addMode = AddCarMode.manual;
  bool _isAnalyzing = false;
  final MLService _mlService = MLService();
  Map<String, List<Map<String, dynamic>>>? _analysisResult;
  List<Map<String, dynamic>> _matchedModels = [];
  bool _isCarDetected = false;
  String _analysisMessage = "";  Map<String, dynamic>? _selectedCity; 
  Map<String, dynamic>? _matchedCatalogModel;
  int? _potentialXpGain;
  late Future<List<Map<String, dynamic>>> _cityFuture;
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _locationController = TextEditingController();
  final _otherBrandController = TextEditingController(); 
  final _otherModelController = TextEditingController();
  List<dynamic> _allBrands = [];
  List<dynamic> _availableModels = [];
  Map<String, dynamic>? _selectedBrand;
  Map<String, dynamic>? _selectedModel;
  File? _mobileImageFile;
  Uint8List? _webImageBytes;
  Map<String, String>? _selectedCountry;
  Map<String, dynamic>? _selectedColor;
  bool _isLoading = false;
  final FocusNode _locationFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final List<Level> levels = [
    Level(1, "Novice du Spotting", 0), Level(2, "Débutant", 100), Level(3, "Amateur", 250),
    Level(4, "Passionné", 500), Level(5, "Connaisseur", 1000), Level(6, "Expert", 2000),
    Level(7, "Chasseur d'Élite", 4000), Level(8, "Maître Spotter", 7500),
    Level(9, "Légende de la Route", 12000), Level(10, "Dieu du Spotting", 20000),
  ];
  // Dictionnaire pour traduire les noms de l'IA en noms de notre catalogue
  final Map<String, String> _brandNameTranslations = {
    // Noms complets vs Acronymes
    'bayerische motoren werke': 'bmw',
    'fabbrica italiana automobili torino': 'fiat',
    
    // Noms officiels vs Noms courants
    'mercedes-benz': 'mercedes',
    'aston martin lagonda': 'aston martin',
    'land rover': 'land rover', // Parfois l'IA peut juste retourner "Rover"
    'alfa romeo automobiles': 'alfa romeo',
    
    // Acronymes simples
    'vw': 'volkswagen',

    // Cas spécifiques observés
    'a-barth': 'abarth', // L'IA peut ajouter un tiret
    'jaguar cars': 'jaguar',
    'automobili lamborghini': 'lamborghini',
    'ferrari s.p.a.': 'ferrari',

    // Prévention pour les cas japonais/coréens
    'honda motor company': 'honda',
    'toyota motor corporation': 'toyota',
    'hyundai motor company': 'hyundai',
    'kia motors': 'kia',
    'mazda motor corporation': 'mazda',
    'nissan motor company': 'nissan',
    
    // Groupes vs Marques
    'psa peugeot citroën': 'peugeot', // Ou 'citroen', la recherche gérera les deux
    'stellantis': 'stellantis', // C'est un groupe, mais l'IA peut le retourner
  };
// ----- NOUVEAU BLOC -----
  Future<void> _selectBrand() async {
    if (_allBrands.isEmpty) await _loadBrands();
    
    final selectedBrand = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const BrandSelectionScreen()),
    );

    if (selectedBrand != null && mounted) {
      setState(() {
        _selectedBrand = selectedBrand;
        _selectedModel = null; // On réinitialise toujours le modèle

        // Si la marque est "Autre", on ne charge pas de modèles
        if (selectedBrand['id'] == 'other') {
          _availableModels = []; // On vide la liste des modèles disponibles
          
          // On sélectionne automatiquement "Autre modèle" pour forcer la saisie
          _selectedModel = {'id': 'other', 'name': 'Autre'};

        } else {
          // Sinon, on charge les modèles de la marque sélectionnée
          _loadModelsForBrand(selectedBrand['id']);
        }
      });
    }
  }

  Future<void> _selectModel() async {
    // Sécurité : si aucune marque n'est sélectionnée ou si les modèles ne sont pas chargés, on ne fait rien.
    if (_selectedBrand == null || _availableModels.isEmpty) return;

    final selectedModel = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ModelSelectionScreen( // On va créer cet écran juste après
          brandName: _selectedBrand!['name'],
          models: _availableModels,
        ),
      ),
    );

    if (selectedModel != null && mounted) {
      setState(() {
        _selectedModel = selectedModel;
      });
    }
  }
  
    Widget _buildLocationPicker() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text("Erreur de chargement des villes.");
        }

        final loadedCities = snapshot.data ?? [];

        if (_selectedCountry?['code'] == 'FR') {
          return TypeAheadField<Map<String, dynamic>>(
            controller: _locationController,
            focusNode: _locationFocusNode,
            builder: (context, controller, focusNode) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Lieu du spot (ville du monde)',
                  hintText: 'Commencez à taper...',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
              );
            },
            suggestionsCallback: (pattern) {
              if (pattern.trim().isEmpty || pattern.length < 2) {
                return Future.value([]);
              }
              return Future.value(loadedCities.where((city) {
                final cityName = city['nom'] as String?;
                return cityName != null &&
                    cityName.toLowerCase().contains(pattern.toLowerCase());
              }).take(20).toList());
            },
            itemBuilder: (context, Map<String, dynamic> suggestion) {
              final cityName = suggestion['nom']?.toString() ?? 'Ville inconnue';
              return ListTile(
                leading: const Icon(Icons.location_city, color: Colors.black),
                title: Text(cityName),
                dense: true,
              );
            },
            onSelected: (Map<String, dynamic> selection) {
              final cityName = selection['nom']?.toString() ?? '';
              print("DEBUG: Ville sélectionnée: $cityName");
              _locationController.text = cityName;
              setState(() {
                _selectedCity = selection;
              });
              FocusScope.of(context).unfocus();
            },
            emptyBuilder: (context) => const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Aucune ville trouvée.', style: TextStyle(color: Colors.grey)),
            ),
            decorationBuilder: (context, child) {
              return Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200, // Hauteur maximale
                    minHeight: 50,  // Hauteur minimale pour éviter qu'elle soit trop petite
                  ),
                  child: child,
                ),
              );
            },
          );
        } else {
          return TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Lieu du spot',
              border: OutlineInputBorder(),
            ),
          );
        }
      },
    );
  }

  Widget _buildSuggestionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
      ),
      clipBehavior: Clip.antiAlias, // Pour que l'image respecte les coins arrondis
      child: InkWell(
        onTap: () {
          AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
          onTap();
        },
        splashColor: color.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Colonne pour l'icône et l'image (si disponible)
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          // Placeholder pendant le chargement
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator(strokeWidth: 2, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                          },
                          // Icône d'erreur si l'image ne charge pas
                          errorBuilder: (context, error, stackTrace) => Icon(icon, color: color, size: 30),
                        ),
                      )
                    else
                      Icon(icon, color: color, size: 30),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Colonne pour le texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _cityFuture = _loadAndGetCities(); 
    _selectedCountry = countryData.firstWhere((c) => c['code'] == 'FR');
    _locationFocusNode.addListener(() {
  // Si on perd le focus...
      if (!_locationFocusNode.hasFocus) {
    // ...ET que soit aucune ville n'a été sélectionnée,
    // soit le texte actuel ne correspond PAS à la ville sélectionnée (l'utilisateur a modifié après avoir choisi)
        if (_selectedCity == null || _locationController.text != '${_selectedCity!['nom']}') {
      // Alors on vide le champ et la sélection.
          _locationController.clear();
          setState(() {
            _selectedCity = null;
         });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> _loadAndGetCities() async {
    // On appelle la fonction de chargement de AppData
    await AppData.loadWorldCities();
    print("DEBUG: Nombre de villes chargées: ${AppData.worldCities.length}");
    if (AppData.worldCities.isNotEmpty) {
      print("DEBUG: Première ville: ${AppData.worldCities.first}");
    }
    // Et on retourne la liste qui est maintenant garantie d'être chargée
    return AppData.worldCities;
  }

  @override
  void dispose() {
    _mlService.dispose();
    _plateController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
    _otherBrandController.dispose(); // <-- AJOUTER
    _otherModelController.dispose(); // <-- AJOUTER
    super.dispose();
  }

  void _resetForm({bool keepPlate = false}) {
    String plateText = _plateController.text;
    _formKey.currentState?.reset();
    _locationController.clear();
    if (!keepPlate) _plateController.clear();
    else _plateController.text = plateText;
    setState(() {
      _selectedBrand = null; _selectedModel = null; _selectedColor = null;
      _mobileImageFile = null; _webImageBytes = null; 
      _matchedCatalogModel = null; _potentialXpGain = null;  _selectedCity = null;
      _isAnalyzing = false;
      _analysisResult = null;
      _matchedModels = [];
      _isCarDetected = false;
      _analysisMessage = "";
      
      // On ajoute le nettoyage des variables de l'IA
      _isAnalyzing = false;
    });
  }

  Future<void> _loadBrands() async {
    final response = await rootBundle.loadString('assets/data/brands.json');
    if (mounted) setState(() => _allBrands = (json.decode(response))['brands']);
  }

// ----- NOUVEAU BLOC -----
  Widget _buildAnalysisResult() {
    if (_isAnalyzing || !_isCarDetected) return const SizedBox.shrink();
    
    // Si on a des correspondances dans notre catalogue
    if (_matchedModels.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Nos meilleures propositions :", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._matchedModels.map((match) {
            final brand = match['brand'] as Map<String, dynamic>;
            final model = match['model'] as Map<String, dynamic>;
            return _buildSuggestionCard(
              title: brand['name'],
              subtitle: model['name'],
              imageUrl: model['imageUrl'], // On utilise l'image du modèle !
              icon: Icons.check_circle,
              color: Colors.black,
              onTap: () => _onModelSelectedFromAI(brand, model),
            );
          }),
          const SizedBox(height: 16),
          Center( /* ... Bouton "Saisir manuellement" ... */ )
        ],
      );
    }

    // Sinon, si on a des logos
    final logos = _analysisResult?['logos'] ?? [];
    if (logos.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Marques potentielles (logos) :", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...logos.map((logo) {
             final brandName = logo['name'] as String;
             // On cherche si on a une image pour le logo de la marque
             final brandData = _allBrands.firstWhere(
                (b) => (b['name'] as String).toLowerCase() == brandName.toLowerCase(), 
                orElse: () => null
              );
            return _buildSuggestionCard(
              title: brandName,
              subtitle: "Sélectionner cette marque",
              imageUrl: brandData?['imageUrl'], // Image du logo de la marque !
              icon: Icons.shield_outlined,
              color: Colors.blue,
              onTap: () => _onBrandSelectedFromAI(brandName),
            );
          }),
        ],
      );
    }    
    // En dernier recours, si on n'a rien trouvé, on propose de passer en manuel
// ----- NOUVELLE PROPOSITION DE STYLE -----

    // En dernier recours, si on n'a rien trouvé, on affiche une carte d'information.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50, // Un fond très léger pour délimiter la zone
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const SizedBox(height: 5),
          Text(
            "Véhicule non identifié",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Vous pouvez passer en saisie manuelle pour ajouter le vehicule vous-même.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ----- AJOUTER CES 3 FONCTIONS -----

  // Appelée quand l'utilisateur clique sur un modèle précis (Marque + Modèle)
  void _onModelSelectedFromAI(Map<String, dynamic> brand, Map<String, dynamic> model) {
    setState(() {
      _selectedBrand = brand;
      _selectedModel = model;
      _analysisResult = null; // On nettoie les résultats de l'IA
      _matchedModels = [];
      _addMode = AddCarMode.manual; // On bascule vers le formulaire pré-rempli
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("${brand['name']} ${model['name']} sélectionné !"),
      backgroundColor: Colors.green,
    ));
  }
  
  // Appelée quand l'utilisateur clique sur un logo
  Future<void> _onBrandSelectedFromAI(String brandName) async {
    final foundBrand = _allBrands.firstWhere(
      (b) => (b['name'] as String).toLowerCase() == brandName.toLowerCase(),
      orElse: () => null,
    );

    if (foundBrand != null) {
      await _loadModelsForBrand(foundBrand['id']);
      setState(() {
        _selectedBrand = foundBrand;
        _selectedModel = null; // L'utilisateur doit choisir le modèle
        _analysisResult = null;
        _matchedModels = [];
        _addMode = AddCarMode.manual;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Marque ${foundBrand['name']} sélectionnée. Choisissez le modèle."),
        backgroundColor: Colors.blue,
      ));
    } else {
      _switchToManualMode(); // Si on ne trouve pas la marque, on passe en manuel
    }
  }

  // Helper pour basculer en mode manuel proprement
  void _switchToManualMode() {
    setState(() {
      _analysisResult = null;
      _matchedModels = [];
      _addMode = AddCarMode.manual;
    });
  }

// Fichier: lib/add_car_screen.dart

  Future<void> _analyzeImage() async {
    if (_webImageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _matchedModels = [];
      _isCarDetected = false;
      _analysisMessage = "";
    });

    try {
      final result = await _mlService.analyzeImage(_webImageBytes!);
      
      if (mounted) {
        // ===============================================
        // === BLOC DE PARSING SÉCURISÉ (CORRIGÉ) ===
        // ===============================================
        List<Map<String, dynamic>> _safeCastList(dynamic list) {
          if (list is! List) return [];
          return List<Map<String, dynamic>>.from(
            list.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value)));
              }
              return <String, dynamic>{};
            }).where((item) => item.isNotEmpty) // On retire les maps vides si la conversion échoue
          );
        }

        final logos = _safeCastList(result['logos']);
        final labels = _safeCastList(result['labels']);
        // ===============================================

        const carKeywords = ['car', 'vehicle', 'sports car', 'convertible', 'suv', 'coupe', 'sedan', 'hatchback', 'automotive', 'bumper', 'wheel', 'tire', 'land vehicle', 'limousine'];
        const negativeKeywords = ['drawing', 'cartoon', 'illustration', 'screenshot', 'video game'];
        const competitorKeywords = ['motorcycle', 'train', 'bicycle', 'bus', 'scooter'];
        double carScore = 0.0;
        bool hasNegativeKeyword = false;
        bool hasCompetitorKeyword = false;

        for (var labelMap in labels) {
          final label = (labelMap['name'] as String).toLowerCase();
          final confidence = (labelMap['score'] as double? ?? 0.0);
          if (negativeKeywords.contains(label) && confidence > 0.7) hasNegativeKeyword = true;
          if (competitorKeywords.contains(label) && confidence > 0.75) hasCompetitorKeyword = true;
          if (carKeywords.contains(label)) carScore += confidence;
        }

        if (hasNegativeKeyword) {
          _isCarDetected = false;
          _analysisMessage = "Les images non réelles (dessins, jeux) ne sont pas acceptées.";
          setState(() { _analysisResult = {'logos': [], 'labels': []}; });

        } else if (carScore > 0.8 && !hasCompetitorKeyword) {
          _isCarDetected = true;
          
          Map<String, Map<String, dynamic>> matchesWithScores = {};
          final allClues = [...logos, ...labels];

          Set<Map<String, dynamic>> candidateBrands = {};
          for (final brand in _allBrands) {
            final brandName = (brand['name'] as String).toLowerCase();
            for (final clue in allClues) {
              String clueName = (clue['name'] as String).toLowerCase();
              if (_brandNameTranslations.containsKey(clueName)) {
                clueName = _brandNameTranslations[clueName]!;
              }
              if (clueName.contains(brandName)) {
                candidateBrands.add(brand);
                break;
              }
            }
          }

          for (final brand in candidateBrands) {
            await _loadModelsForBrand(brand['id']);
            for (final modelData in _availableModels) {
              final modelTags = (modelData['tags'] as List<dynamic>?)?.map((t) => t.toString().toLowerCase()).toList() ?? [];
              
              if (modelTags.isEmpty) continue;

              double relevanceScore = 0.0;
              
              for (final clue in labels) {
                final clueName = (clue['name'] as String).toLowerCase();
                if (modelTags.contains(clueName)) {
                  double weight = 1.0;
                  if (clueName.contains('suv') || clueName.contains('coupe') || clueName.contains('sedan') || clueName.contains('sports car')) {
                    weight = 2.0;
                  }
                  if (clueName == 'car' || clueName == 'vehicle') {
                    weight = 0.5;
                  }
                  relevanceScore += (clue['score'] as double? ?? 0.0) * weight;
                }
              }

              if (relevanceScore > 0) {
                final uniqueKey = '${brand['id']}_${modelData['id']}';
                matchesWithScores[uniqueKey] = {
                  'brand': brand, 'model': modelData, 'score': relevanceScore
                };
              }
            }
          }
          
          final sortedMatches = matchesWithScores.values.toList();
          sortedMatches.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
          final topMatches = sortedMatches.take(5).toList();

          if (topMatches.isNotEmpty) {
            _analysisMessage = "Voici nos suggestions les plus probables :";
          } else {
             _analysisMessage = ""; 
          }

          setState(() {
            _analysisResult = { 'logos': logos, 'labels': labels };
            _matchedModels = topMatches;
          });
        
        } else if (carScore > 0.5) {
          _isCarDetected = true;
          _analysisMessage = "Nous ne sommes pas sûrs que ce soit une voiture. Vous pouvez continuer ou changer de photo.";
          setState(() { _analysisResult = {'logos': [], 'labels': []}; });
        } else {
          _isCarDetected = false;
          _analysisMessage = "Cette photo ne semble pas contenir de voiture.";
          setState(() { _analysisResult = {'logos': [], 'labels': []}; });
        }
      }
    } catch (e, stackTrace) {
      print("Erreur CRITIQUE dans _analyzeImage (Flutter): $e");
      print(stackTrace);
      if(mounted) {
        setState(() {
          _analysisMessage = "Une erreur est survenue lors de l'affichage des résultats.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }
    
  Future<void> _loadModelsForBrand(String brandId) async {
    final path = 'assets/data/models_by_brand/$brandId.json';
    try {
      final response = await rootBundle.loadString(path);
      if (mounted) setState(() => _availableModels = (json.decode(response))['models']);
    } catch (e) {
      if (mounted) setState(() => _availableModels = []);
    }
  }
  
  Future<void> _addCarToGarage() async {
    if (!_formKey.currentState!.validate()) {
      return; // Si la validation échoue (ex: plaque incomplète), on s'arrête là.
    }
    final isManual = _addMode == AddCarMode.manual;
        if (isManual) {
      if (_selectedBrand == null || _selectedModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner la marque et le modèle.'), backgroundColor: Colors.orange));
        return;
      }
    } else { // Mode Automatique (anciennement "par plaque")
      // Notre nouvelle logique va remplir _selectedBrand et _selectedModel.
      // Donc, la vérification est la même que pour le mode manuel.
      if (_selectedBrand == null || _selectedModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord analyser une photo et confirmer le modèle.'), backgroundColor: Colors.orange));
        return;
      }
    }
    setState(() => _isLoading = true);
    const isOnline = true; // TEMPORAIRE: On force en ligne pour le débogage

    if (isOnline) {
      await _addCarToFirebase();
    } 
  }

  Future<void> _addCarToFirebase() async {
    bool operationSucceeded = false;
    String successMessage = 'Voiture ajoutée à votre collection !';
    Level? newLevelAfterUpdate;
    List<AchievementLevel> newAchievementsToDisplay = [];
    List<Achievement> allAchievementsAfter = [];
    Level oldLevel = levels.first;
    int oldXp = 0;
    int finalXp = 0;

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final plateToCheck = _plateController.text.trim().toUpperCase();
      final firestore = FirebaseFirestore.instance;
      final userDocRef = firestore.collection('users').doc(currentUser.uid);

      final existingCarQuery = await firestore
          .collection('spotted_cars')
          .where('userId', isEqualTo: currentUser.uid)
          .where('plate', isEqualTo: plateToCheck)
          .limit(1)
          .get();
      
      if (existingCarQuery.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cette plaque est déjà dans ton garage !"), backgroundColor: Colors.orange));
        throw Exception("Plaque dupliquée");
      }

      // --- ÉTAPE 1 : "AVANT" ---
      final userDocBeforeUpdate = await userDocRef.get();
      final userDataBefore = userDocBeforeUpdate.data() as Map<String, dynamic>? ?? {};
      oldXp = userDataBefore['totalXp'] ?? 0;
      final currentClaims = userDataBefore['claimedAchievements'] as Map<String, dynamic>? ?? {};
      final allSpottedCarsDocsBefore = await firestore.collection('spotted_cars').where('userId', isEqualTo: currentUser.uid).get();
      final allSpottedCarsBefore = allSpottedCarsDocsBefore.docs.map((doc) => doc.data()).toList();
      final brandsJsonString = await rootBundle.loadString('assets/data/brands.json');
      final allBrandsList = (json.decode(brandsJsonString))['brands'];

      final achievementServiceBefore = AchievementService(allBrands: allBrandsList, spottedCars: allSpottedCarsBefore);
      final allAchievementsBefore = achievementServiceBefore.checkAchievements(calculateProgress: true);

      final newCarDocRef = firestore.collection('spotted_cars').doc();
      Map<String, dynamic> carDataToSave;

      final bool isCustomBrand = _selectedBrand != null && _selectedBrand!['id'] == 'other';
      final bool isCustomModel = _selectedModel != null && _selectedModel!['id'] == 'other';

      // On vérifie si l'un des deux (ou les deux) est une saisie personnalisée
      if (isCustomBrand || isCustomModel) {
        carDataToSave = {
          'brandName': isCustomBrand ? _otherBrandController.text.trim() : _selectedBrand!['name'],
          'modelName': isCustomModel ? _otherModelController.text.trim() : _selectedModel!['name'],
          'isCatalogued': false, // Ne fait pas partie du catalogue officiel
          'brandId': isCustomBrand ? null : _selectedBrand!['id'],
          'modelId': null, // Toujours null pour un modèle personnalisé
          'modelImageUrl': null, // Pas d'image officielle
        };
      } else {
        // Cas normal, véhicule du catalogue
        carDataToSave = {
          ..._selectedModel!,
          'brandId': _selectedBrand!['id'],
          'brandName': _selectedBrand!['name'],
          'modelId': _selectedModel!['id'],
          'modelName': _selectedModel!['name'],
          'modelImageUrl': _selectedModel!['imageUrl'],
          'isCatalogued': true,
        };
        carDataToSave.remove('name');
      }
      carDataToSave.addAll({'userId': currentUser.uid, 'plate': plateToCheck, 'spottedAt': Timestamp.now(), 'color': _selectedColor?['name'], 'plateCountryCode': _selectedCountry!['code'], 'locationName': _selectedCity != null ? '${_selectedCity!['nom']}' : null, 'locationCoords': _selectedCity != null ? GeoPoint(_selectedCity!['latitude'], _selectedCity!['longitude']) : null});
      
      String? userPhotoUrl;
      if (_webImageBytes != null) { userPhotoUrl = await _uploadImage(_webImageBytes!, newCarDocRef.id); }
      carDataToSave['userPhotoUrl'] = userPhotoUrl;

      final bool givesXp = carDataToSave['isCatalogued'] == true;
      int xpFromSpot = 0;
      if (givesXp) {
        int getXpFromRarity(int rarityScore) {
          switch (rarityScore) {
            case 1: return 10;
            case 2: return 25;
            case 3: return 50;
            case 4: return 100;
            case 5: return 250;
            default: return 25;
          }
        }
        xpFromSpot = getXpFromRarity((_selectedBrand!['rarete'] as int?) ?? 2);
        successMessage = 'Voiture ajoutée ! +$xpFromSpot XP';
      } else {
        // Message spécifique si la voiture est hors catalogue
        successMessage = 'Voiture personnalisée ajoutée à votre garage !';
      }

      // --- ÉTAPE 3 : SIMULATION ET TRANSACTION ---
      final List<Map<String, dynamic>> allSpottedCarsAfter = List.from(allSpottedCarsBefore)..add(carDataToSave);
      final achievementServiceAfter = AchievementService(allBrands: allBrandsList, spottedCars: allSpottedCarsAfter);
      allAchievementsAfter = achievementServiceAfter.checkAchievements(calculateProgress: true);

      await firestore.runTransaction((transaction) async {
        transaction.set(newCarDocRef, carDataToSave);
        int xpIncrement = givesXp ? xpFromSpot : 0;
        transaction.update(userDocRef, {'totalXp': FieldValue.increment(xpIncrement), 'stats.totalSpots': FieldValue.increment(1)});
      });

      // --- ÉTAPE 4 : COMPARAISON SUCCÈS ---
      final Map<String, dynamic> updatedClaims = Map.from(currentClaims);
      int totalXpFromAchievements = 0;
      for (var achAfter in allAchievementsAfter) {
        final achBefore = allAchievementsBefore.firstWhere((b) => b.id == achAfter.id);
        final previouslyClaimedLevel = updatedClaims[achAfter.id] ?? 0;
        if (achAfter.unlockedLevel > previouslyClaimedLevel) {
          for (int i = previouslyClaimedLevel; i < achAfter.unlockedLevel; i++) {
            final newLevelData = achAfter.levels[i];
            newAchievementsToDisplay.add(newLevelData);
            totalXpFromAchievements += newLevelData.xpReward;
          }
          updatedClaims[achAfter.id] = achAfter.unlockedLevel;
        }
      }
      
      if (totalXpFromAchievements > 0) {
        await userDocRef.update({'totalXp': FieldValue.increment(totalXpFromAchievements), 'claimedAchievements': updatedClaims});
      }

      // --- CALCUL FINAL DU LEVEL UP ---
      finalXp = oldXp + xpFromSpot + totalXpFromAchievements;
      oldLevel = _getCurrentLevel(oldXp);
      final Level newLevel = _getCurrentLevel(finalXp);
      
      if (newLevel.level > oldLevel.level) {
        newLevelAfterUpdate = newLevel;
      }
      
      operationSucceeded = true;

    } catch (e) {
      if (e.toString() != "Exception: Plaque dupliquée" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (!operationSucceeded && mounted) {
        setState(() => _isLoading = false);
      }
    }

    // --- BLOC D'AFFICHAGE FINAL ---
    if (operationSucceeded) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (newAchievementsToDisplay.isNotEmpty) {
        for (final newAchievement in newAchievementsToDisplay) {
          final parentAchievement = allAchievementsAfter.firstWhere(
            (ach) => ach.levels.any((level) => level.title == newAchievement.title),
            orElse: () => Achievement(id: 'fallback', icon: Icons.star, levels: []),
          );
          if (!mounted) return;
          await showAchievementUnlocked(context, newAchievement, parentAchievement.icon);
        }
      }
      
      if (newLevelAfterUpdate != null) {
        if (!mounted) return;
        await showLevelUp(
          context, 
          oldLevel: oldLevel,
          newLevel: newLevelAfterUpdate!,
          oldXp: oldXp,
          newXp: finalXp,
        );
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    }
  }
  Future<void> _showImageSourceActionSheet() async {
    // La condition `if (kIsWeb)` est supprimée pour activer le choix sur le web.
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie Photos'),
              onTap: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                _getImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil Photo'),
              onTap: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                _getImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1800,
      );

      if (pickedFile != null) {
        _webImageBytes = await pickedFile.readAsBytes();
        if (!kIsWeb) {
          _mobileImageFile = File(pickedFile.path);
        }
        setState(() {
          // Quand on choisit une nouvelle photo, on réinitialise les prédictions
          _analysisResult = null;
          _matchedModels = [];
          _isCarDetected = false;
          _analysisMessage = "";
          _selectedBrand = null;
          _selectedModel = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sélection de l'image: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _uploadImage(Uint8List imageBytes, String carId) async {
    final currentUser = FirebaseAuth.instance.currentUser; if (currentUser == null) return null;
    final storageRef = FirebaseStorage.instance.ref().child('user_spots/${currentUser.uid}/$carId.jpg');
    await storageRef.putData(imageBytes); return await storageRef.getDownloadURL();
  }
  
  Level _getCurrentLevel(int totalXp) {
    Level currentLevel = levels.first;
    for (var level in levels) { if (totalXp >= level.xpRequired) { currentLevel = level; } else { break; } }
    return currentLevel;
  }
// Fichier: lib/add_car_screen.dart

  @override
  Widget build(BuildContext context) {
    // Style pour les titres de section, pour un look cohérent
    final TextStyle sectionTitleStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
      color: Theme.of(context).primaryColor,
      fontWeight: FontWeight.bold,
    );

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
          title: const Text('Ajouter une voiture'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Sélecteur de Mode ---
                  _buildModeSelector(),
                  const SizedBox(height: 24),
                  
                  // --- Sélecteur de Photo ---
                  _buildPhotoPicker(),
                  const SizedBox(height: 24),

                  // --- Affichage du Formulaire principal (Manuel ou Auto) ---
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _addMode == AddCarMode.manual
                      ? _buildManualForm()
                      : _buildAutomaticForm(), // On utilise la nouvelle fonction
                  ),

                  // =======================================================
                  // === DÉTAILS SUPPLÉMENTAIRES (UNIQUEMENT EN MODE MANUEL) ===
                  // =======================================================
                  if (_addMode == AddCarMode.manual) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Détails du spot",
                      style: sectionTitleStyle,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildColorPicker(),
                    const SizedBox(height: 16),
                    _buildLocationPicker(),
                  ],
                  // =======================================================

                  const SizedBox(height: 32),
                  if (_addMode == AddCarMode.manual)
                    ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        // On vérifie d'abord si le formulaire est valide AVANT de jouer le son
                        if (_formKey.currentState!.validate()) {
                          AudioService.instance.playSfx(SoundEffect.succesPrincipal); // <-- SON AJOUTÉ
                          _addCarToGarage();
                        } else {
                          // Optionnel : un son d'erreur si le formulaire n'est pas bon
                          AudioService.instance.playSfx(SoundEffect.clicLeger);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      child: const Text('Ajouter à ma collection'),
                    ),
                ],
              ),
            ),
    );
  }
    
  Widget _buildModeSelector() {
    return Center(
      child: SegmentedButton<AddCarMode>(
        segments: const <ButtonSegment<AddCarMode>>[
          ButtonSegment<AddCarMode>(value: AddCarMode.manual, label: Text('Manuel'), icon: Icon(Icons.edit)),
          ButtonSegment<AddCarMode>(value: AddCarMode.automatic, label: Text('Automatique'), icon: Icon(Icons.auto_awesome_outlined)), // MODIFIÉ ICI
        ],
        selected: <AddCarMode>{_addMode},
        onSelectionChanged: (newSelection) {
          AudioService.instance.playSfx(SoundEffect.transitionPage); // <-- SON AJOUTÉ
          setState(() { _addMode = newSelection.first; _resetForm(); });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.2), // Utilise le thème
          selectedForegroundColor: Theme.of(context).primaryColor, // Utilise le thème
        ),
      ),
    );
  }
  
  Widget _buildManualForm() {
    List<TextInputFormatter> getInputFormatters() {
      final countryCode = _selectedCountry?['code'];
      if (countryCode == null || countryCode == 'XX') {
        // Pas de formatage pour "Autre"
        return [];
      }
      final mask = plateFormats[countryCode];
      if (mask != null) {
        // On applique le masque trouvé
        return [PlateInputFormatter(mask: mask)];
      }
      return [];
    }

    // Fonction qui valide si la plaque est complète pour un pays donné
    String? validatePlate(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Ce champ est requis';
      }

      final countryCode = _selectedCountry?['code'];
      
      // Pour "Autre", on demande juste un minimum de 3 caractères
      if (countryCode == null || countryCode == 'XX') {
        final actualLength = value.replaceAll(RegExp(r'[^A-Z0-9]'), '').length;
        if (actualLength < 3) {
          return 'Minimum 3 caractères alphanumériques.';
        }
        return null; // C'est valide
      }

      final mask = plateFormats[countryCode];
      if (mask != null) {
        // On calcule la longueur ATTENDUE en comptant les lettres et chiffres du masque
        final expectedLength = mask.replaceAll(RegExp(r'[^A#]'), '').length;
        // On calcule la longueur ACTUELLE de ce que l'utilisateur a tapé
        final actualLength = value.replaceAll(RegExp(r'[^A-Z0-9]'), '').length;

        if (actualLength < expectedLength) {
          return 'Le format de la plaque est incomplet.';
        }
      }
      
      return null; // La validation est réussie
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Informations sur le spot", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        const Divider(),
        const SizedBox(height: 16),
        _buildCountryPicker(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: getInputFormatters(),
          decoration: InputDecoration(
            labelText: "Plaque d'immatriculation *",
            hintText: 'Ex: ${_selectedCountry?['hint'] ?? 'Format libre'}',
            border: const OutlineInputBorder(),
          ),
          validator: validatePlate,
        ),
        const SizedBox(height: 16),

        TextFormField(
          // On affiche le nom de la marque si elle est sélectionnée
          controller: TextEditingController(text: _selectedBrand?['name'] ?? ''),
          readOnly: true,
          onTap: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            _selectBrand();
          },
          decoration: const InputDecoration(
            labelText: 'Marque *',
            hintText: 'Appuie pour choisir',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          validator: (value) => _selectedBrand == null ? 'Veuillez sélectionner une marque' : null,
        ),
        if (_selectedBrand != null && _selectedBrand!['id'] == 'other') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherBrandController,
            decoration: const InputDecoration(
              labelText: "Nom de la nouvelle marque *",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Ce champ est requis' : null,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        const SizedBox(height: 16),
// ----- NOUVEAU BLOC -----
        TextFormField(
          controller: TextEditingController(text: _selectedModel?['name'] ?? ''),
          readOnly: true,
          // On ne permet de cliquer que si la marque n'est PAS "Autre"
          onTap: (_selectedBrand != null && _selectedBrand!['id'] != 'other') ? () {
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            _selectModel();
          } : null,
          decoration: InputDecoration(
            labelText: 'Modèle *',
            hintText: _selectedBrand == null ? "Choisissez d'abord une marque" : 'Appuie pour choisir',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            // On grise le champ si la marque est "Autre"
            filled: _selectedBrand == null || _selectedBrand!['id'] == 'other',
            fillColor: Colors.grey[200],
          ),
          validator: (value) => _selectedBrand != null && _selectedModel == null ? 'Veuillez sélectionner un modèle' : null,
        ),
        if (_selectedModel != null && _selectedModel!['id'] == 'other') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherModelController,
            decoration: const InputDecoration(
              labelText: "Nom du nouveau modèle *",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Ce champ est requis' : null,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        if ((_selectedBrand != null && _selectedBrand!['id'] == 'other') || 
            (_selectedModel != null && _selectedModel!['id'] == 'other')) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Les véhicules hors catalogue sont ajoutés à votre garage mais n'impactent pas votre progression.",
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],        
      ],
    );
  }
// Fichier: lib/add_car_screen.dart

  Widget _buildAutomaticForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ÉTAPE 1: L'ACTION PRINCIPALE ---
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Text(
              "Analyser votre photo :", // J'ai enlevé les ":" pour un style plus épuré
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline, // On ajoute le soulignement
                decorationColor:  Colors.black,
                decorationThickness: 2, // Épaisseur du trait
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: _isAnalyzing 
              ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Icon(Icons.search),
            label: Text(_isAnalyzing ? "Analyse en cours..." : "Lancer l'analyse"),
            onPressed: (_isAnalyzing || _webImageBytes == null) ? null : () {
              AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
              _analyzeImage();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Bouton arrondi
            ),
          ),
        ),
        
        // Fichier: lib/add_car_screen.dart
// Dans la fonction _buildAutomaticForm()

        // --- ÉTAPE 2: LES RÉSULTATS (ne se construit qu'après l'analyse) ---
        // La condition if(...) empêche la création du widget (et donc de son espace) tant qu'il n'y a rien à afficher.
        if (_analysisMessage.isNotEmpty || (_analysisResult != null && _isCarDetected)) ...[
          
          // L'espacement est maintenant à l'intérieur de la condition
          const SizedBox(height: 24),

          // AnimatedSwitcher gère l'animation d'apparition en fondu pour toute la section
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Column(
              // On donne une clé pour que l'animation sache que le contenu a changé
              key: const ValueKey('analysis_results_section'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Text("2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Résultats :", // J'ai mis au pluriel, c'est plus juste
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.black,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),                
                const SizedBox(height: 16),
                if (_analysisMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0), // Marge pour l'espacement
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isCarDetected ? Colors.blue.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isCarDetected ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3))
                    ),
                    child: Row(
                      children: [
                        Icon(_isCarDetected ? Icons.info_outline : Icons.error_outline, color: _isCarDetected ? Colors.blue : Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _analysisMessage,
                            style: TextStyle(
                              color: _isCarDetected ? Theme.of(context).textTheme.bodyMedium?.color : Colors.red.shade800,
                              fontWeight: FontWeight.w500
                            ),
                          )
                        ),
                      ],
                    ),
                  ),

                // Les résultats de l'analyse
                if (_isCarDetected) _buildAnalysisResult(),
              ],
            ),
          ),
        ],

        if (_analysisMessage.isEmpty && _analysisResult == null)
          const SizedBox(height: 24),

        const Divider(),
        const SizedBox(height: 12),
        // On recrée la carte cliquable pour une meilleure visibilité
        Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          child: InkWell(
            onTap: () {
              AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
              _switchToManualMode();
            },
            borderRadius: BorderRadius.circular(12.0), // Pour l'effet d'ondulation
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_outlined, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    "Passer en saisie manuelle",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedColor,
      onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
      decoration: const InputDecoration(labelText: 'Couleur', border: OutlineInputBorder()),
      items: carColors.map((color) => DropdownMenuItem<Map<String, dynamic>>(value: color, child: Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: color['color'], shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade400))), const SizedBox(width: 10), Text(color['name']?.toString() ?? 'Couleur inconnue')]))).toList(),
      onChanged: (value) => setState(() => _selectedColor = value),
    );
  }

  Widget _buildCountryPicker() {
    return DropdownButtonFormField<Map<String, String>>(
      value: _selectedCountry, isExpanded: true,
      onTap: () => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
      decoration: const InputDecoration(labelText: 'Pays de la plaque', border: OutlineInputBorder()),
      items: countryData.map((country) => DropdownMenuItem<Map<String, String>>(value: country, child: Row(children: [Text(country['flag']!, style: const TextStyle(fontSize: 20)), const SizedBox(width: 10), Text(country['name']?.toString() ?? 'Pays inconnu')]))).toList(),
      onChanged: (value) { if (value != null) { setState(() { _selectedCountry = value; _plateController.clear(); }); } },
    );
  }

// ----- NOUVELLE VERSION DYNAMIQUE de _buildPhotoPicker -----

  Widget _buildPhotoPicker() {
    Widget imageContent;

    // --- Si une image a été sélectionnée ---
    if (_webImageBytes != null) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.memory(
          _webImageBytes!,
          // On n'a plus besoin de 'fit' car l'AspectRatio va gérer les proportions
        ),
      );
    } else if (_mobileImageFile != null) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.file(
          _mobileImageFile!,
        ),
      );
    } else {
      // --- Si aucune image n'a été sélectionnée (le placeholder) ---
      imageContent = Container(
        height: 200, // On garde une hauteur fixe pour le placeholder
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text('Ajouter une photo (optionnel)', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // On retourne le GestureDetector qui rend la zone cliquable
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
        _showImageSourceActionSheet();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: imageContent, // On affiche directement le contenu
      ),
    );
  }
}