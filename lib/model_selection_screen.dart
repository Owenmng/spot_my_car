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
    _filteredModels = widget.models;
    _searchController.addListener(() {
      _filterModels(_searchController.text);
    });
  }

  void _filterModels(String query) {
    if (query.isEmpty) {
      setState(() => _filteredModels = widget.models);
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
            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
            Navigator.of(context).pop();
          },
        ),
        title: Text('Choisir un modèle ${widget.brandName}'),
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
                hintText: 'Rechercher un modèle...',
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
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        // On retourne une map spéciale qui sera reconnue par l'écran précédent
                        Navigator.of(context).pop({'id': 'other', 'name': 'Autre'});
                      },
                    ),
                  );
                }

                final model = _filteredModels[index - 1];
                return ListTile(
                  title: Text(model['name']),
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
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