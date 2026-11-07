import 'package:spot_my_car/services/custom_cache_manager.dart';
// Fichier: lib/community/friends_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/services/audio_service.dart';


class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {

  final List<Level> levels = [
    Level(1, "Novice du Spotting", 0), Level(2, "Débutant", 100), Level(3, "Amateur", 250),
    Level(4, "Passionné", 500), Level(5, "Connaisseur", 1000), Level(6, "Expert", 2000),
    Level(7, "Chasseur d'Élite", 4000), Level(8, "Maître Spotter", 7500),
    Level(9, "Légende de la Route", 12000), Level(10, "Dieu du Spotting", 20000),
  ];

  Level _getCurrentLevel(int totalXp) {
    Level currentLevel = levels.first;
    for (var level in levels) {
      if (totalXp >= level.xpRequired) {
        currentLevel = level;
      } else {
        break;
      }
    }
    return currentLevel;
  }

  final currentUser = FirebaseAuth.instance.currentUser!;

  Future<void> _sendFriendRequest(String friendId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('friendId', isEqualTo: friendId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text("Aucun utilisateur trouvé avec cet ID."),
            backgroundColor: Colors.orange));
        return;
      }
      
      final recipientUserDoc = querySnapshot.docs.first;
      final recipientId = recipientUserDoc.id;

      if (recipientId == currentUser.uid) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text("Tu ne peux pas t'ajouter toi-même !"),
            backgroundColor: Colors.orange));
        return;
      }

      final areAlreadyFriends = await FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid)
          .collection('friends').doc(recipientId)
          .get()
          .then((doc) => doc.exists);

      if (areAlreadyFriends) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text("Vous êtes déjà amis !"),
            backgroundColor: Colors.blue));
        return;
      }

      // Vérification 2 : Ai-je déjà envoyé une demande à cette personne ?
      final pendingRequestSent = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get()
          .then((snapshot) => snapshot.docs.isNotEmpty);

      if (pendingRequestSent) {
         scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text("Tu as déjà envoyé une demande à cet utilisateur."),
            backgroundColor: Colors.blue));
        return;
      }

      // Vérification 3 : Ai-je une demande en attente de cette personne ?
      final pendingRequestReceived = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: recipientId)
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get()
          .then((snapshot) => snapshot.docs.isNotEmpty);
      
      if (pendingRequestReceived) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text("Cet utilisateur t'a déjà envoyé une demande. Va l'accepter !"),
            backgroundColor: Colors.blue));
        return;
      }

      await FirebaseFirestore.instance.collection('friend_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': recipientId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      navigator.pop();
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text("Demande d'ami envoyée !"),
          backgroundColor: Colors.green));

    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text("Une erreur est survenue : $e"),
          backgroundColor: Colors.red));
    }
  }
  
  Future<void> _acceptFriendRequest(String requestId, String fromUserId) async {
    final batch = FirebaseFirestore.instance.batch();

    final requestRef = FirebaseFirestore.instance.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {'status': 'accepted'});

    final currentUserFriendsRef = FirebaseFirestore.instance
        .collection('users').doc(currentUser.uid)
        .collection('friends').doc(fromUserId);
    batch.set(currentUserFriendsRef, {'friendSince': FieldValue.serverTimestamp()});

    final otherUserFriendsRef = FirebaseFirestore.instance
        .collection('users').doc(fromUserId)
        .collection('friends').doc(currentUser.uid);
    batch.set(otherUserFriendsRef, {'friendSince': FieldValue.serverTimestamp()});

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Vous êtes maintenant amis !"),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _declineFriendRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Demande refusée."),
    ));
  }

Widget _buildFriendListItem(String friendUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(friendUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Color.fromARGB(255, 235, 240, 255), radius: 25),
            title: Text("Chargement..."),
          );
        }

        final friendData = snapshot.data?.data() as Map<String, dynamic>?;

        if (friendData == null) {
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.error_outline)),
            title: Text("Utilisateur introuvable"),
          );
        }

        final pseudo = friendData['pseudo'] as String?;
        final friendId = friendData['friendId'] ?? 'ID inconnu';
        final photoUrl = friendData['photoUrl'] as String?;
        final totalXp = friendData['totalXp'] ?? 0;
        final Level friendLevel = _getCurrentLevel(totalXp);
        final stats = friendData['stats'] as Map<String, dynamic>? ?? {};
        final totalSpots = stats['totalSpots'] ?? 0;
        final favoriteBrand = stats['favoriteBrandName'] ?? 'Aucune';

        // Si le pseudo n'est pas défini, on utilise l'ID Ami comme nom principal
        final displayName = (pseudo != null && pseudo.isNotEmpty) ? pseudo : friendId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[200], // Arrière-plan si l'image charge
            backgroundImage: (photoUrl != null && photoUrl.startsWith('http'))
                ? NetworkImage(photoUrl, headers: kImageHeaders)
                : (photoUrl != null && photoUrl.startsWith('assets/'))
                    ? AssetImage(photoUrl) as ImageProvider
                    : const AssetImage('assets/avatars/car_noir.png'),
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friendId, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 4),
              Text("Niveau ${friendLevel.level} · Spots: $totalSpots"),
              Text("Marque préférée : $favoriteBrand"),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
            tooltip: 'Retirer cet ami', // C'est bien pour l'accessibilité
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              _removeFriend(friendUid, displayName);
            },
          ),
        );
      },
    );
  }

    Future<void> _removeFriend(String friendUid, String friendPseudo) async {
    // Confirmation de la suppression
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer un ami'),
        content: Text("Es-tu sûr de vouloir retirer $friendPseudo de ta liste d'amis ?"),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              Navigator.of(context).pop(false);
            }, 
            child: const Text('Annuler')
          ),
          TextButton(
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              Navigator.of(context).pop(true);
            }, 
            child: const Text('Retirer', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Étape 1 : Supprimer l'ami de la sous-collection de l'utilisateur actuel
      final currentUserFriendRef = FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid)
          .collection('friends').doc(friendUid);
      batch.delete(currentUserFriendRef);

      // Étape 2 : Supprimer l'utilisateur actuel de la sous-collection de l'ami
      final otherUserFriendRef = FirebaseFirestore.instance
          .collection('users').doc(friendUid)
          .collection('friends').doc(currentUser.uid);
      batch.delete(otherUserFriendRef);

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Ami retiré."),
        backgroundColor: Colors.green,
      ));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Erreur lors de la suppression de l'ami : $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<DocumentSnapshot>(
        // On va chercher une seule fois les infos de l'utilisateur actuel
        future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentUserData = snapshot.data!.data() as Map<String, dynamic>?;
          final myFriendId = currentUserData?['friendId'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === WIDGET AJOUTÉ ICI ===
                if (myFriendId != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () {
                        AudioService.instance.playSfx(SoundEffect.notification); // <-- SON AJOUTÉ
                        Clipboard.setData(ClipboardData(text: myFriendId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('ID Ami copié dans le presse-papiers !'),
                            backgroundColor: Theme.of(context).primaryColor, // Couleur de l'appli
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Mon ID : $myFriendId",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.copy, size: 16, color: Theme.of(context).primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (myFriendId != null) const SizedBox(height: 16), // Espace après l'ID                
                // Le reste de la page ne change pas
                _buildFriendRequestsSection(),
                const SizedBox(height: 32),
                _buildFriendsListSection(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
          _showAddFriendDialog(context);
        },
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'Ajouter un ami',
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Demandes en attente", Icons.person_add_outlined),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('toUserId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                elevation: 2, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text("Aucune nouvelle demande.", style: TextStyle(color: Colors.grey))),
                ),
              );
            }

            final requests = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final requestData = request.data() as Map<String, dynamic>;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(requestData['fromUserId']).get(),
                  builder: (context, userSnapshot) {
                    
                    // On affiche un loader pendant le chargement des infos de l'expéditeur
                    if (!userSnapshot.hasData) {
                      return const Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(radius: 25),
                          title: Text("Chargement..."),
                        ),
      
                      );
                    }
                    
                    final senderData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final fromPseudo = senderData?['pseudo'] as String?;
                    final fromFriendId = senderData?['friendId'] ?? 'ID Inconnu';
                    final fromPhotoUrl = senderData?['photoUrl'] as String?;
                    
                    // Si le pseudo est vide, on affiche l'ID Ami à la place
                    final displayName = (fromPseudo != null && fromPseudo.isNotEmpty) ? fromPseudo : fromFriendId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundImage: (fromPhotoUrl != null && fromPhotoUrl.startsWith('http'))
                              ? NetworkImage(fromPhotoUrl, headers: kImageHeaders)
                              : (fromPhotoUrl != null && fromPhotoUrl.startsWith('assets/'))
                                  ? AssetImage(fromPhotoUrl) as ImageProvider
                                  : const AssetImage('assets/avatars/car_noir.png'),
                        ),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("veut devenir ton ami"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () {
                                AudioService.instance.playSfx(SoundEffect.succesPrincipal); // <-- SON AJOUTÉ
                                _acceptFriendRequest(request.id, requestData['fromUserId']);
                              },
                              tooltip: 'Accepter',
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                                _declineFriendRequest(request.id);
                              },
                              tooltip: 'Refuser',
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              },
            );
          },
        ),
      ],
    );
  }

Widget _buildFriendsListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Mes Amis", Icons.people_outline),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          // Étape 1: On écoute la sous-collection 'friends' de l'utilisateur actuel
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('friends')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Ta liste d'amis est vide.",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              );
            }

            final friendDocs = snapshot.data!.docs;
            // On extrait les UID des amis
            final friendUids = friendDocs.map((doc) => doc.id).toList();

            return Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friendUids.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  // Pour chaque UID, on va chercher les infos de l'ami
                  return _buildFriendListItem(friendUids[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final TextEditingController idController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Ajouter un ami"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Entre l'ID Ami à 8 chiffres de la personne que tu veux ajouter."),
                const SizedBox(height: 16),
                TextFormField(
                  controller: idController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "ID Ami",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return "L'ID ne peut pas être vide.";
                    if (value.trim().length != 8) return "L'ID doit contenir 8 chiffres.";
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  AudioService.instance.playSfx(SoundEffect.notification); // <-- SON AJOUTÉ
                  _sendFriendRequest(idController.text.trim());
                }
              },
              child: const Text("Envoyer"),
            ),
          ],
        );
      },
    );
  }
}