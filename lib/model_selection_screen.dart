import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/shared/natural_sort.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/services/audio_service.dart';


class ModelSelectionScreen extends StatefulWidget {
  final String brandName;
  final List<dynamic> models;

  const ModelSelectionScreen({
    super.key,
    required this.brandName,
    required this.models,
  });

  @override
  _ModelSelectionScreenState createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  List<dynamic> _filteredModels = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredModels = List.of(widget.models)..sort((a, b) => naturalCompare(a['name'].toString(), b['name'].toString()));
    _searchController.addListener(() {
      _filterModels(_searchController.text);
    });
  }

  void _filterModels(String query) {
    if (query.isEmpty) {
      setState(() => _filteredModels = List.of(widget.models)..sort((a, b) => naturalCompare(a['name'].toString(), b['name'].toString())));
      return;
    }
    setState(() {
      _filteredModels = widget.models.where((model) {
        final modelName = model['name'].toString().toLowerCase();
        return modelName.contains(query.toLowerCase());
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
            AudioService.instance.playSfx(SoundEffect.clicLeger);
            Navigator.of(context).pop();
          },
        ),
        title: Text('Choisir un modèle ${widget.brandName}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un modèle...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
// ----- NOUVEAU BLOC -----
          Expanded(
            child: ListView.builder(
              // On ajoute +1 à la longueur pour notre option "Autre"
              itemCount: _filteredModels.length + 1,
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
                        "Autre modèle...", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                      ),
                      subtitle: const Text("Le modèle que vous cherchez n'est pas dans la liste ?"),
                      onTap: () {
                        AudioService.instance.playSfx(SoundEffect.clicLeger);
                        // On retourne une map spéciale qui sera reconnue par l'écran précédent
                        Navigator.of(context).pop({'id': 'other', 'name': 'Autre'});
                      },
                    ),
                  );
                }

                final model = _filteredModels[index - 1];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: SizedBox(
                    width: 72,
                    height: 48,
                    child: CarImage(
                      urls: [model['imageUrl'] as String?],
                      brandName: widget.brandName,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  title: Text(model['name']),
                  subtitle: model['production_years'] == null ? null : Text(model['production_years'].toString()),
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger);
                    Navigator.of(context).pop(model);
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