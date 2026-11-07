// Fichier: lib/home_screen.dart (VERSION FINALE CORRIGÉE)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/car_catalog_screen.dart';
import 'package:spot_my_car/collection_screen.dart';
import 'package:spot_my_car/garage_screen.dart';
import 'package:spot_my_car/profile_screen.dart';
import 'package:spot_my_car/map_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/widgets/loading_animation_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Flag pour s'assurer que la musique ne démarre qu'une seule fois
  bool _musicStarted = false;

  @override
  void initState() {
    super.initState();
    // On lance le chargement des données. L'UI se mettra à jour grâce au Consumer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataManager>(context, listen: false).loadAllData();
    });
  }

  void _onItemTapped(int index) {
    // On vérifie si l'onglet cliqué est différent de l'onglet actuel
    if (index != _selectedIndex) {
      // Si c'est le cas, on joue le son ET on met à jour l'état
      Provider.of<AudioService>(context, listen: false).playSfx(SoundEffect.clicLeger);
      
      setState(() {
        _selectedIndex = index;
      });
    }
    // Si l'index est le même, on ne fait rien du tout.
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataManager>(
      builder: (context, dataManager, child) {
        // Si les données sont prêtes...
        if (dataManager.isDataLoaded) {
          
          // ==========================================================
          // === LA NOUVELLE LOGIQUE DE DÉMARRAGE EST ICI ============
          // ==========================================================
          // Si la musique n'a pas encore été lancée...
          if (!_musicStarted) {
            // Délai pour laisser l'UI se stabiliser
            Future.delayed(const Duration(milliseconds: 800), () {
              AudioService.instance.startMusic();
            });
            _musicStarted = true;
          } // ← CORRECTION: Accolade fermante ajoutée
          // ==========================================================
          
          // Et on affiche l'interface principale
          return _buildMainScaffold();

        } else {
          // Sinon, on affiche notre bel écran de chargement
          return const LoadingAnimationWidget(
            loadingMessage: "Chargement du garage ...",
          );
        }
      },
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          GarageScreen(),
          MapScreen(),
          CollectionScreen(),
          CarCatalogScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.garage_outlined), activeIcon: Icon(Icons.garage), label: 'Garage'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Collection'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Catalogue'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8.0,
      ),
    );
  }
}