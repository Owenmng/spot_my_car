// Fichier: lib/community/leaderboard_tab.dart (Version Finale, Corrigée)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spot_my_car/services/audio_service.dart';

// Logique de niveau, déplacée en dehors de la classe et rendue publique
final List<Level> leaderboardLevels = [
  Level(1, "Novice du Spotting", 0), Level(2, "Débutant", 100), Level(3, "Amateur", 250),
  Level(4, "Passionné", 500), Level(5, "Connaisseur", 1000), Level(6, "Expert", 2000),
  Level(7, "Chasseur d'Élite", 4000), Level(8, "Maître Spotter", 7500),
  Level(9, "Légende de la Route", 12000), Level(10, "Dieu du Spotting", 20000),
];

Level getLeaderboardCurrentLevel(int totalXp) {
  Level currentLevel = leaderboardLevels.first;
  for (var level in leaderboardLevels) {
    if (totalXp >= level.xpRequired) {
      currentLevel = level;
    } else {
      break;
    }
  }
  return currentLevel;
}


class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('leaderboards').doc('top100').snapshots(),
        builder: (context, leaderboardSnapshot) {
          
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!leaderboardSnapshot.hasData || !userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final leaderboardData = leaderboardSnapshot.data?.data() as Map<String, dynamic>?;
              final top100Entries = (leaderboardData?['entries'] as List<dynamic>?) ?? [];
              
              final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
              final myRank = userData?['rank'] as int?;

              final podium = top100Entries.where((e) => e['rank'] <= 3).toList();
              final listEntries = top100Entries.where((e) => e['rank'] > 3).toList();

              if (leaderboardData == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text("Le classement est en cours de génération. Spotte une voiture pour l'activer !", textAlign: TextAlign.center,),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // Pour l'instant, un simple re-build suffit car les données sont en stream
                  (context as Element).reassemble();
                },
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (podium.isNotEmpty) _buildPodium(context, podium, currentUser.uid),
                    const SizedBox(height: 24),
                    if (listEntries.isNotEmpty)
                      _buildLeaderboardList(context, listEntries, currentUser.uid),
                    const SizedBox(height: 24),
                    if (myRank != null && myRank > 100 && userData != null)
                      _buildMyRankCard(context, myRank, userData),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<dynamic> podium, String myUid) {
    final sortedPodium = List.from(podium)..sort((a, b) => a['rank'].compareTo(b['rank']));
    final first = sortedPodium.firstWhere((p) => p['rank'] == 1, orElse: () => null);
    final second = sortedPodium.firstWhere((p) => p['rank'] == 2, orElse: () => null);
    final third = sortedPodium.firstWhere((p) => p['rank'] == 3, orElse: () => null);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (second != null) _buildPodiumPlace(context, second, myUid, isSecond: true),
          const SizedBox(width: 4),
          if (first != null) _buildPodiumPlace(context, first, myUid, isFirst: true),
          const SizedBox(width: 4),
          if (third != null) _buildPodiumPlace(context, third, myUid),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(BuildContext context, Map<String, dynamic> playerData, String myUid, {bool isFirst = false, bool isSecond = false}) {
    final rank = playerData['rank'];
    final photoUrl = playerData['photoUrl'] as String?;
    final pseudo = playerData['pseudo'] ?? playerData['friendId'];
    final level = playerData['level'] ?? 1;
    // On force la conversion en entier pour éviter les ".0"
    final totalSpots = ((playerData['stats'] as Map<String, dynamic>?)?['totalSpots'] ?? 0).toInt(); 
    final isMe = playerData['uid'] == myUid;

    Color crownColor;
    if (rank == 1) { crownColor = Colors.amber; }
    else if (rank == 2) { crownColor = Colors.grey[400]!; }
    else { crownColor = Colors.brown[400]!; }

    return Expanded(
      flex: isFirst ? 4 : 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.emoji_events, color: crownColor, size: 30),
          const SizedBox(height: 4),
                    // On ajoute un "cadre" en imbriquant deux CircleAvatar
                    CircleAvatar(
                      radius: 22,
                      // La couleur du cadre dépend de si c'est "moi" ou non
                      backgroundColor: isMe ? Theme.of(context).primaryColor : Colors.black,
                      child: CircleAvatar(
                        radius: 20, // Rayon légèrement plus petit pour l'image
                        backgroundImage: (photoUrl != null && photoUrl.startsWith('http'))
                          ? CachedNetworkImageProvider(photoUrl)
                          // Cast en ImageProvider pour assurer la compatibilité
                          : (photoUrl != null && photoUrl.startsWith('assets/'))
                              ? AssetImage(photoUrl) as ImageProvider
                              : const AssetImage('assets/avatars/car_noir.png'),
                      ),
                    ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              pseudo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // On remplace le Text unique par une Column pour avoir deux lignes
          Column(
            children: [
              Text(
                "Niveau $level",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor, // Couleur du thème
                  fontSize: 12,
                ),
              ),
              Text(
                "$totalSpots spots",
                style: TextStyle(color: Colors.grey[600], fontSize: 12), // Couleur grise
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: isFirst ? 100 : (isSecond ? 70 : 50),
            width: double.infinity,
            decoration: BoxDecoration(
              color: crownColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Center(child: Text("$rank", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(BuildContext context, List<dynamic> listEntries, String myUid) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // On revient à ListView.separated
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: listEntries.length,
        // Et on ajoute notre séparateur stylisé
        separatorBuilder: (context, index) => Divider(
          height: 1, // Hauteur totale de 1 pixel
          thickness: 1.5, // Épaisseur de la ligne
          color: Colors.grey[300], // Une couleur grise très claire
          indent: 16, // Marge à gauche pour s'aligner après l'avatar
          endIndent: 16, // Marge à droite
        ),
        itemBuilder: (context, index) {
          final playerData = listEntries[index] as Map<String, dynamic>;
          final isMe = playerData['uid'] == myUid;
          final photoUrl = playerData['photoUrl'] as String?;
          final pseudo = playerData['pseudo'] ?? playerData['friendId'];
          final level = playerData['level'] ?? 1;
          final totalSpots = (playerData['stats'] as Map<String, dynamic>?)?['totalSpots'] ?? 0;

          // Le InkWell a été retiré, on retourne directement le Container
          return Container(
            color: isMe ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
            child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: SizedBox(
                  width: 40,
                  child: Text(
                    "${playerData['rank']}.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                ),
                title: Row(
                  children: [
                    // On ajoute un "cadre" noir en imbriquant deux CircleAvatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.black, // Couleur du cadre
                      child: CircleAvatar(
                        radius: 20, // Rayon légèrement plus petit pour l'image
                        backgroundImage: (photoUrl != null && photoUrl.startsWith('http'))
                          ? CachedNetworkImageProvider(photoUrl)
                          // Cast en ImageProvider pour assurer la compatibilité
                          : (photoUrl != null && photoUrl.startsWith('assets/'))
                              ? AssetImage(photoUrl) as ImageProvider
                              : const AssetImage('assets/avatars/car_noir.png'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Niveau $level",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                    Text(
                      "$totalSpots spots",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
        },
      ),
    );
  }

  Widget _buildMyRankCard(BuildContext context, int myRank, Map<String, dynamic> myData) {
    final pseudo = myData['pseudo'] ?? myData['friendId'];
    final xp = myData['totalXp'];
    final level = getLeaderboardCurrentLevel(xp);
    final totalSpots = (myData['stats'] as Map<String, dynamic>?)?['totalSpots'] ?? 0;
    
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Text(
          "$myRank.",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        title: Text("Votre position : $pseudo", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Niveau ${level.level}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text( 
              "$totalSpots spots",
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}