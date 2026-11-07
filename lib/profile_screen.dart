// Fichier: lib/screens/profile_screen.dart (Version Corrigée et 100% Complète)

import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:spot_my_car/services/user_stats_service.dart';
import 'package:spot_my_car/achievements_screen.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/community_screen.dart';
import 'package:spot_my_car/settings_screen.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/services/auth_service.dart';
import 'package:spot_my_car/services/audio_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final List<String> defaultAvatars = [ 'assets/avatars/car_bleu.png', 'assets/avatars/car_violet.png', 'assets/avatars/car_rouge.png', 'assets/avatars/car_vert.png', 'assets/avatars/car_rose.png', 'assets/avatars/car_noir.png', 'assets/avatars/car_orange.png'];
  bool _isSigningOut = false;
  String? _randomAvatarPath;
  final List<Level> levels = [ Level(1, "Novice du Spotting", 0), Level(2, "Débutant", 100), Level(3, "Amateur", 250), Level(4, "Passionné", 500), Level(5, "Connaisseur", 1000), Level(6, "Expert", 2000), Level(7, "Chasseur d'Élite", 4000), Level(8, "Maître Spotter", 7500), Level(9, "Légende de la Route", 12000), Level(10, "Dieu du Spotting", 20000), ];
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() { super.initState(); _randomAvatarPath = defaultAvatars[Random().nextInt(defaultAvatars.length)]; }

  Future<void> _showChangeProfilePictureDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choisir depuis la galerie'),
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    Navigator.of(ctx).pop();
                    _uploadProfilePictureFromGallery();
                  }),
              const Divider(),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: defaultAvatars.map((avatarPath) {
                  return GestureDetector(
                      onTap: () {
                        AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                        Navigator.of(ctx).pop();
                        _updateProfilePictureFromAsset(avatarPath);
                      },
                      child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          backgroundImage: AssetImage(avatarPath)));
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadProfilePictureFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (pickedFile == null) return;
    final imageBytes = await pickedFile.readAsBytes();
    _uploadData(imageBytes);
  }

  Future<void> _updateProfilePictureFromAsset(String assetPath) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .set(
      {
        'photoUrl': assetPath,
      },
      SetOptions(merge: true),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avatar mis à jour !'), backgroundColor: Colors.green));
    }
  }

  Future<void> _uploadData(Uint8List data) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/${currentUser.uid}');
      await storageRef.putData(data, SettableMetadata(contentType: 'image/jpeg'));
      final imageUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(
        {
          'photoUrl': imageUrl,
        },
        SetOptions(merge: true),
      );
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Photo de profil mise à jour !'),
          backgroundColor: Colors.green));
    } catch (e) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }
// ----- NOUVELLE VERSION DE LA FONCTION -----

  Widget _buildStatCard(String label, String value, IconData icon,
      {VoidCallback? onTap, Color? iconColor}) { // <-- 1. On ajoute le paramètre ici
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                Icon(
                  icon, 
                  size: 32, 
                  // 2. On utilise la couleur fournie, ou la couleur du thème par défaut
                  color: iconColor ?? Theme.of(context).primaryColor 
                ),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadFavoriteBrandData(String? brandId) async {
    if (brandId == null) return null;
    try {
      final response = await rootBundle.loadString('assets/data/brands.json');
      final data = json.decode(response);
      final List<dynamic> allBrands = data['brands'];
      return allBrands.firstWhere((b) => b['id'] == brandId, orElse: () => null);
    } catch (e) {
      return null;
    }
  }

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

  double _getlevelProgress(int totalXp, Level currentLevel) {
    if (currentLevel.level >= levels.length) return 1.0;
    final nextLevel = levels[currentLevel.level];
    final xpForCurrentLevel = currentLevel.xpRequired;
    final xpForNextLevel = nextLevel.xpRequired;
    // === LA CORRECTION EST ICI : la déclaration de xpNeededForNextLevel ===
    final xpNeededForNextLevel = xpForNextLevel - xpForCurrentLevel; 
    // ======================================================================
    if (xpNeededForNextLevel == 0) return 1.0;
    final xpInThisLevel = totalXp - xpForCurrentLevel;
    return xpInThisLevel / xpNeededForNextLevel;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (FirebaseAuth.instance.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            tooltip: "Se déconnecter",
            icon: Icon(
              Icons.logout,
              color: _isSigningOut ? AppColors.inkMuted : AppColors.ink,
            ),
            onPressed: _isSigningOut
                ? null
                : () async {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    setState(() => _isSigningOut = true);
                    try {
                      await AuthService.signOut(); 
                      if (mounted) { 
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur lors de la déconnexion: ${e.toString()}")),
                        );
                        setState(() => _isSigningOut = false);
                      }
                    }
                  },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final totalXp = userData['totalXp'] ?? 0;
          final currentLevel = _getCurrentLevel(totalXp);
          final progress = _getlevelProgress(totalXp, currentLevel);
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('friend_requests').where('toUserId', isEqualTo: currentUser.uid).where('status', isEqualTo: 'pending').snapshots(),
            builder: (context, friendRequestSnapshot) {
              final int friendRequestCount = friendRequestSnapshot.data?.docs.length ?? 0;
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: currentUser.uid).snapshots(),
                builder: (context, carSnapshot) {
                  if (carSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final spottedCars = (carSnapshot.data?.docs ?? []).map((doc) => doc.data() as Map<String, dynamic>).toList();
                  final statsService = UserStatsService(spottedCars: spottedCars);
                  final stats = statsService.calculateStats();
                  final displayName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
                  final joinDate = currentUser.metadata.creationTime != null ? DateFormat('dd MMMM yyyy', 'fr_FR').format(currentUser.metadata.creationTime!) : 'N/A';
                  final photoUrl = userData['photoUrl'] as String?;
                  final friendId = userData['friendId'] as String?;
                  ImageProvider? profileImage;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    if (photoUrl.startsWith('http')) {
                      profileImage = NetworkImage(photoUrl);
                    } else if (photoUrl.startsWith('assets/')) {
                      profileImage = AssetImage(photoUrl);
                    }
                  } else if (_randomAvatarPath != null) {
                    profileImage = AssetImage(_randomAvatarPath!);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.settings_outlined, color: Colors.grey[700]),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Paramètres',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (friendId != null)
                                InkWell(
                                  onTap: () {
                                    AudioService.instance.playSfx(SoundEffect.notification); // <-- SON AJOUTÉ
                                    Clipboard.setData(ClipboardData(text: friendId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('ID Ami copié dans le presse-papiers !'),
                                        backgroundColor: Theme.of(context).primaryColor,
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
                                          "Mon ID : $friendId",
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.copy, size: 16, color: Theme.of(context).primaryColor),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  backgroundImage: profileImage,
                                  child: profileImage == null
                                      ? Icon(Icons.person, size: 60, color: Theme.of(context).primaryColor)
                                      : null),
                              GestureDetector(
                                  onTap: () {
                                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                                    _showChangeProfilePictureDialog(context);
                                  },
                                  child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2)),
                                      child: const Icon(Icons.edit, color: Colors.white, size: 18))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                            displayName.isNotEmpty ? displayName : (currentUser.displayName ?? currentUser.email!.split('@')[0]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(currentUser.email ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        Card(
                          
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text("Niveau ${currentLevel.level} - ${currentLevel.title}",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                const SizedBox(height: 12),
                                RevLights(value: progress, dark: false, height: 12),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("$totalXp XP", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                      if (currentLevel.level < levels.length)
                                        Text("${levels[currentLevel.level].xpRequired} XP", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                                    ])
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatCard('Spots', stats.totalSpots.toString(), Icons.directions_car),
                            const SizedBox(width: 12),
                            _buildStatCard('Marques', stats.uniqueBrands.toString(), Icons.stars),
                            const SizedBox(width: 12),
                            _buildStatCard('Modèles', stats.uniqueModels.toString(), Icons.shield),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () {
                              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON CORRIGÉ
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityScreen()));
                            },
                            leading: Icon(Icons.groups_outlined, color: Theme.of(context).primaryColor),
                            title: const Text("Ma Communauté", style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.arrow_forward_ios, size: 16),
                                if (friendRequestCount > 0)
                                  Positioned(
                                    top: -12,
                                    right: -12,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(
                                        friendRequestCount.toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () {
                               AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON CORRIGÉ
                               Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen()));
                            },
                            leading: Icon(Icons.emoji_events_outlined, color: Colors.amber[800]),
                            title: const Text("Mes Succès", style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () {
                              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                            leading: Icon(Icons.settings_outlined, color: Colors.grey[700]),
                            title: const Text("Paramètres", style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text('Informations & Préférences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _loadFavoriteBrandData(userData['favoriteBrandId']),
                          builder: (context, favoriteBrandSnapshot) {
                            final favoriteBrand = favoriteBrandSnapshot.data;
                            final logoUrl = favoriteBrand?['logoUrl'] as String?;
                            return ListTile(
                              leading: const Icon(Icons.favorite_outline, color: Colors.grey),
                              title: const Text('Marque préférée'),
                              trailing: favoriteBrand != null && logoUrl != null && logoUrl.isNotEmpty
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.network(logoUrl, height: 24, errorBuilder: (c, e, s) => const Icon(Icons.error, size: 24)),
                                        const SizedBox(width: 8),
                                        Text(favoriteBrand['name'], style: const TextStyle(fontSize: 16)),
                                      ],
                                    )
                                  : const Text('Non renseignée', style: TextStyle(fontSize: 16)),
                            );
                          },
                        ),
                        ListTile(
                            leading: const Icon(Icons.cake_outlined, color: Colors.grey),
                            title: const Text('Date de naissance'),
                            trailing: Text(userData['dateOfBirth'] ?? 'Non renseigné', style: const TextStyle(fontSize: 16))),
                        ListTile(
                            leading: const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                            title: const Text('Membre depuis'),
                            trailing: Text(joinDate, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}