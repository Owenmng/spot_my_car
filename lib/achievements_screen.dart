// Fichier: lib/achievements_screen.dart (Version Finale Corrigée)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/audio_service.dart';


class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  // ==========================================================
  // === 1. ON AJOUTE BuildContext context EN PARAMÈTRE ========
  // ==========================================================
  Widget _buildAchievementTile(BuildContext context, Achievement achievement) {
    final AchievementLevel levelToShow = achievement.displayLevel;
    final bool isFullyCompleted = achievement.isFullyCompleted;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isFullyCompleted ? Colors.green.shade700 : Colors.amber.shade700,
              width: 5,
            ),
          ),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 'context' est maintenant connu ici, donc plus d'erreur !
                Icon(achievement.icon, size: 32, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        levelToShow.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                       if (!isFullyCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Chip(
                            avatar: Icon(Icons.star, color: Colors.amber.shade800, size: 16),
                            label: Text('+${levelToShow.xpReward} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            shape: StadiumBorder(side: BorderSide(color: Colors.amber.withOpacity(0.5))),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStarRating(achievement.unlockedLevel, achievement.levels.length),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              levelToShow.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (!isFullyCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${achievement.currentProgress} / ${levelToShow.target}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "Défi terminé !",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(int unlockedLevel, int maxLevel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (index) {
        return Icon(
          index < unlockedLevel ? Icons.star : Icons.star_border,
          color: Colors.amber.shade800,
          size: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

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
        title: const Text('Mes Succès'),
        // On utilise le thème pour l'AppBar, c'est plus propre
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: currentUser.uid).snapshots(),
        builder: (context, carSnapshot) {
          if (carSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (carSnapshot.hasError) {
            return Center(child: Text('Erreur: ${carSnapshot.error}'));
          }
          final spottedCars = (carSnapshot.data?.docs ?? []).map((doc) => doc.data() as Map<String, dynamic>).toList();

          return FutureBuilder<List<dynamic>>(
            future: _loadAllBrands(),
            builder: (context, brandsSnapshot) {
              if (!brandsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final achievementService = AchievementService(allBrands: brandsSnapshot.data!, spottedCars: spottedCars);
              final achievements = achievementService.checkAchievements();

              if (achievements.isEmpty) {
                 return const Center(child: Text("Aucun succès à afficher."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    // ==========================================================
                    // === 2. ON PASSE LE context LORS DE L'APPEL ==============
                    // ==========================================================
                    child: _buildAchievementTile(context, achievements[index]),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<dynamic>> _loadAllBrands() async {
    final String response = await rootBundle.loadString('assets/data/brands.json');
    return (json.decode(response))['brands'];
  }
}