import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:spot_my_car/services/audio_service.dart';


class BrandSelectionScreen extends StatefulWidget {
  const BrandSelectionScreen({super.key});

  @override
  _BrandSelectionScreenState createState() => _BrandSelectionScreenState();
}

class _BrandSelectionScreenState extends State<BrandSelectionScreen> {
  List<dynamic> _allBrands = [];
  List<dynamic> _filteredBrands = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _searchController.addListener(() {
      _filterBrands(_searchController.text);
    });
  }

  Future<void> _loadBrands() async {
    final response = await rootBundle.loadString('assets/data/brands.json');
    final data = json.decode(response);
    if (mounted) {
      setState(() {
        _allBrands = data['brands'];
        _filteredBrands = _allBrands;
      });
    }
  }

  void _filterBrands(String query) {
    if (query.isEmpty) {
      setState(() => _filteredBrands = _allBrands);
      return;
    }
    setState(() {
      _filteredBrands = _allBrands.where((brand) {
        final brandName = brand['name'].toString().toLowerCase();
        return brandName.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une marque...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
// ----- NOUVEAU BLOC -----
          Expanded(
            child: ListView.builder(
              // On ajoute +1 à la longueur pour notre option "Autre"
              itemCount: _filteredBrands.length + 1,
              itemBuilder: (context, index) {

                // Si c'est le premier élément de la liste (index 0), on affiche notre carte spéciale
                if (index == 0) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor),
                      title: Text(
                        "Autre marque...", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                      ),
                      subtitle: const Text("La marque que vous cherchez n'est pas dans la liste ?"),
                      onTap: () {
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        // On retourne une map spéciale qui sera reconnue par l'écran précédent
                        Navigator.of(context).pop({'id': 'other', 'name': 'Autre'});
                      },
                    ),
                  );
                }

                final brand = _filteredBrands[index - 1];
                return ListTile(
                  title: Text(brand['name']),
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    Navigator.of(context).pop(brand);
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