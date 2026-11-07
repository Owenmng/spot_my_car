// Fichier: lib/community_screen.dart (Version Finale et Fiable pour le Son)

import 'package:flutter/material.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/community/friends_tab.dart';
import 'package:spot_my_car/community/leaderboard_tab.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  int _previousTabIndex = 0; // On va stocker l'index précédent ici

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // On ajoute un listener qui se déclenche à chaque changement (tap ou swipe)
    _tabController.addListener(() {
      // On joue le son SEULEMENT si l'index a réellement changé
      if (_tabController.index != _previousTabIndex) {
        AudioService.instance.playSfx(SoundEffect.transitionPage);
        // On met à jour l'index précédent pour la prochaine comparaison
        setState(() {
          _previousTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger);
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Ma Communauté'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          // On passe notre controller
          controller: _tabController,
          // onTAP n'est plus nécessaire ici, le listener s'occupe de tout
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          tabs: const [
            Tab(text: 'Mes Amis'),
            Tab(text: 'Classement'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FriendsTab(),
          LeaderboardTab(),
        ],
      ),
    );
  }
}