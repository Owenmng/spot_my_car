import 'package:spot_my_car/theme/app_theme.dart';
// Fichier: lib/settings_screen.dart (Version Finale, Corrigée et Cohérente)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/profile_setup_screen.dart';
import 'package:spot_my_car/contact_support_screen.dart';
import 'package:spot_my_car/info_page_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:spot_my_car/services/auth_service.dart';
import 'package:spot_my_car/theme_selection_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:provider/provider.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;

    Widget _buildAudioSwitchTile({
      required BuildContext context,
      required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 40.0, right: 16.0),
        leading: Icon(icon, color: Theme.of(context).primaryColor, size: 22),

        title: Text(
          title,
          // La modification est ici :
          style: const TextStyle( 
            fontWeight: FontWeight.w600, 
            fontSize: 15,
            color: AppColors.ink, // Texte en gris foncé
          ),
        ),

        trailing: Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: (newValue) {
              AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
              onChanged(newValue); // On exécute l'action d'origine
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

  Widget _buildLegalCard({required IconData icon, required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
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
        title: const Text('Paramètres'),
        actions: [
          // ==========================================================
          // === LE BOUTON DE DÉCONNEXION FINAL ET CORRIGÉ EST ICI ===
          // ==========================================================
          IconButton(
            tooltip: "Se déconnecter",
            icon: Icon(
              Icons.logout,
              color: _isSigningOut ? Colors.white.withValues(alpha: 0.5) : Colors.white,
            ),
            onPressed: _isSigningOut
                ? null
                : () async {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    setState(() => _isSigningOut = true);
                    try {
                      // 1. On attend la fin de la déconnexion
                      await AuthService.signOut(); 
                      
                      // 2. On navigue seulement après
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur: ${e.toString()}")),
                        );
                        setState(() => _isSigningOut = false);
                      }
                    }
                  },
          )
        ],
      ),
      backgroundColor: AppColors.paperDeep,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Mon Compte'),
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Modifier le profil',
                  subtitle: 'Pseudo, marque préférée ...',
                  onTap: () async {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSetupScreen(initialUserData: userDoc.data())));
                    }
                  },
                  ),
                _buildSettingsTile(
                  context,
                  icon: Icons.palette_outlined, // Une icône pour le thème
                  title: 'Thème de l\'application',
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ThemeSelectionScreen()),
                    );
                  },
                ),
                
                Theme(
                  // On copie le thème actuel mais on rend la couleur du séparateur transparente
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Consumer<AudioService>(
                    builder: (context, audioService, child) {
                      return ExpansionTile(
                        leading: Icon(Icons.volume_up_outlined, color: Theme.of(context).primaryColor),
                        title: const Text('Paramètres audio', style: TextStyle(fontWeight: FontWeight.w600)),
                        iconColor: Colors.black, 
                        collapsedIconColor: Colors.black,
                        onExpansionChanged: (_) => AudioService.instance.playSfx(SoundEffect.clicLeger), // <-- SON AJOUTÉ
                        subtitle: Text(
                          'Musique et effets sonores',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                        // Voici ce qui s'affiche quand on déplie le menu
                        children: <Widget>[
                          _buildAudioSwitchTile(
                            context: context,
                            icon: Icons.music_note_outlined,
                            title: 'Musique principale',
                            value: audioService.isMusicEnabled,
                            onChanged: (isEnabled) {
                              audioService.toggleMusic(isEnabled);
                            },
                          ),
                          _buildAudioSwitchTile(
                            context: context,
                            icon: Icons.graphic_eq_outlined,
                            title: 'Effets sonores',
                            value: audioService.isSfxEnabled,
                            onChanged: (isEnabled) {
                              audioService.toggleSfx(isEnabled);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),

                _buildSettingsTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Changer le mot de passe',
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    _sendPasswordResetEmail(context, currentUser.email!);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Support et Informations'),
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Contacter le support',
                  subtitle: 'Pour toute question ou problème',
                  onTap: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactSupportScreen()));
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'À propos de l\'application',
                  onTap: () async {
                    final packageInfo = await PackageInfo.fromPlatform();
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
                        title: 'À propos de SpotMyCar',
                        content: Column(
                          children: [
                            Image.asset('assets/logo.png', height: 80),
                            const SizedBox(height: 16),
                            const Text('SpotMyCar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(
                              'Version ${packageInfo.version}',
                              style: TextStyle(fontSize: 16, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'L\'application de référence pour tous les passionnés d\'automobile. Collectionnez les voitures que vous croisez, complétez votre garage et mesurez-vous à la communauté.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 32),
                            Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  const ListTile(
                                    leading: Icon(Icons.code),
                                    title: Text('Développeur'),
                                    subtitle: Text('Owen MENGUAL'),
                                  ),
                                  const Divider(height: 1, indent: 16),
                                  const ListTile(
                                    leading: Icon(Icons.copyright),
                                    title: Text('Copyright'),
                                    subtitle: Text('© 2025 SpotMyCar\nTous droits réservés.'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )));
                    }
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.gavel_outlined,
                  title: 'Conditions d\'utilisation',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
                      title: 'Conditions d\'Utilisation',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dernière mise à jour : Septembre 2025',
                            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.inkSoft),
                          ),
                          const Divider(height: 32),
                          _buildLegalCard(
                            icon: Icons.check_circle_outline,
                            title: '1. Acceptation des conditions',
                            content: 'En téléchargeant, installant ou utilisant l\'application mobile SpotMyCar, vous acceptez d\'être lié par les présentes Conditions d\'Utilisation. Si vous n\'acceptez pas ces Conditions, n\'utilisez pas le Service.',
                          ),
                          _buildLegalCard(
                            icon: Icons.rule_folder_outlined,
                            title: '2. Utilisation du Service',
                            content: 'Le Service est destiné à un usage personnel et non commercial. Vous vous engagez à ne pas soumettre de contenu illégal, offensant ou inapproprié. Les données des véhicules sont fournies à titre indicatif ; nous ne garantissons pas leur exactitude à 100%.',
                          ),
                          _buildLegalCard(
                            icon: Icons.security_outlined,
                            title: '3. Confidentialité et Données',
                            content: 'Nous respectons votre vie privée. Votre adresse email est utilisée uniquement pour l\'authentification. Les données de localisation de vos spots ne sont utilisées qu\'avec votre consentement explicite et ne sont pas partagées avec des tiers.',
                          ),
                          _buildLegalCard(
                            icon: Icons.warning_amber_rounded,
                            title: '4. Limitation de responsabilité',
                            content: 'Le Service est fourni "en l\'état". SpotMyCar décline toute garantie et ne sera pas responsable des dommages directs ou indirects résultant de l\'utilisation ou de l\'incapacité à utiliser le Service.',
                          ),
                        ],
                      ),
                    )));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
                    Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile( // On utilise un ListTile directement
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text(
                'Supprimer mon compte',
                // La modification est ici :
                style: TextStyle(
                  color: Colors.red, 
                  fontWeight: FontWeight.bold, // On met le texte en gras
                ),
              ),
              // On ajoute la couleur rouge à la flèche
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red), 
              onTap: () {
                AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
                _showDeleteAccountDialog(context, currentUser);
              },
            ),
          ),
        ],
      ),
    );
  }
// ----- VERSION FINALE AVEC LIEN TEXTE -----

  Future<void> _sendPasswordResetEmail(BuildContext context, String email) async {
    final TextEditingController emailController = TextEditingController(text: email);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isEditingEmail = false;

    final String? emailToSend = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Réinitialiser le mot de passe'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Un email sera envoyé à l'adresse suivante :"),
                    const SizedBox(height: 16),
                    
                    // Si on n'est pas en mode édition, on affiche l'email
                    if (!isEditingEmail)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          emailController.text,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    
                    // AnimatedSize permet une transition douce quand le champ de texte apparaît/disparaît
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isEditingEmail
                        // --- VUE "SAISIE" ---
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Nouvelle adresse :", style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Entrez votre adresse mail...',
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return 'Email invalide.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          )
                        // --- VUE "CACHÉE" (juste un espace vide) ---
                        : const SizedBox.shrink(),
                    ),
                    
                    // Affiche le lien pour changer SEULEMENT si on n'est pas déjà en train d'éditer
                    if (!isEditingEmail)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap
                        ),
                        child: const Text('Problème avec cette adresse ?'),
                        onPressed: () {
                          AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                          setStateDialog(() {
                            // On passe en mode édition et on sélectionne le texte
                            isEditingEmail = true;
                            emailController.selection = TextSelection(baseOffset: 0, extentOffset: emailController.text.length);
                          });
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
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(emailController.text.trim());
                    }
                  },
                  child: const Text('Envoyer'),
                ),
              ],
            );
          },
        );
      },
    );

    // On n'envoie l'email que si l'utilisateur a confirmé (emailToSend n'est pas null)
    if (emailToSend != null && emailToSend.isNotEmpty && mounted) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: emailToSend);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email envoyé à $emailToSend !'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible d\'envoyer l\'email.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, User user) {
    final bool isSocialSignIn = user.providerData.any((userInfo) => userInfo.providerId != 'password');
    if (isSocialSignIn) {
      showDialog(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte'),
        content: const Text('Cette action est irréversible et supprimera toutes vos données. Êtes-vous sûr de vouloir continuer ?'),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              Navigator.pop(dialogContext);
            }, 
            child: const Text('Annuler')
          ),
          TextButton(
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
              _deleteUserAccount(dialogContext, context, user);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ));
      return;
    }
    final passwordController = TextEditingController();
    showDialog(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Supprimer ce compte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Cette action est irréversible. Pour confirmer, veuillez entrer votre mot de passe.'),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
            Navigator.pop(dialogContext);
          }, 
          child: const Text('Annuler')
        ),
        TextButton(
          onPressed: () async {
            AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
            if (passwordController.text.isEmpty) return;
            try {
              final cred = EmailAuthProvider.credential(email: user.email!, password: passwordController.text);
              await user.reauthenticateWithCredential(cred);
              _deleteUserAccount(dialogContext, context, user);
            } on FirebaseAuthException catch (e) {
              String errorMessage = 'Mot de passe incorrect ou erreur.';
              if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                errorMessage = 'Le mot de passe est incorrect.';
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
            }
          },
          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
  
  Future<void> _deleteUserAccount(BuildContext dialogContext, BuildContext mainPageContext, User user) async {
    final scaffoldMessenger = ScaffoldMessenger.of(mainPageContext);
    try {
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final batch = firestore.batch();
      final userDocRef = firestore.collection("users").doc(uid);
      batch.delete(userDocRef);
      final spotsQuery = firestore.collection("spotted_cars").where("userId", isEqualTo: uid);
      final spotDocs = await spotsQuery.get();
      for (var doc in spotDocs.docs) {
        batch.delete(doc.reference);
        batch.delete(firestore.collection('spot_photos').doc(doc.id));
      }
      await batch.commit();
      try {
        await storage.ref('profile_pictures/$uid').delete();
      } catch (e) { /* ignore */ }
      try {
        final spotPhotos = await storage.ref('user_spots/$uid').listAll();
        for (var photoRef in spotPhotos.items) {
          await photoRef.delete();
        }
      } catch (e) { /* ignore */ }
      await user.delete();
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      if (mainPageContext.mounted) {
        Navigator.of(mainPageContext).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()), 
          (route) => false,
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Compte supprimé avec succès.'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Une erreur est survenue lors de la suppression.'), backgroundColor: Colors.red));
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).primaryColor),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: (onTap != null) ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: () {
        // On ajoute le son par défaut pour toutes les tuiles
        if (onTap != null) {
          AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
          onTap();
        }
      },
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 16, endIndent: 16);
}