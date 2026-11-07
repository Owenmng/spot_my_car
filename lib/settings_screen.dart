import 'package:spot_my_car/theme/app_theme.dart';
// Fichier: lib/settings_screen.dart (Version Finale, Corrigée et Cohérente)

import 'package:flutter/material.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
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
import 'package:spot_my_car/services/notification_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;



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

  Future<void> _signOut() async {
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    setState(() => _isSigningOut = true);
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthGate()), (route) => false);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Déconnexion impossible, réessaie.', icon: Icons.error_outline);
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _openAbout() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
      title: 'À propos',
      content: Column(
        children: [
          const AppLogo(size: 84),
          const SizedBox(height: 18),
          Text('SPOT MY CAR', style: AppText.display(28)),
          Text('Version ${packageInfo.version} (${packageInfo.buildNumber})', style: AppText.mono(13, color: AppColors.inkSoft)),
          const SizedBox(height: 20),
          Text(
            "Chaque voiture croisée devient une carte de collection. Photographie, laisse l'IA reconnaître le modèle, complète ton garage et défie tes amis.",
            textAlign: TextAlign.center,
            style: AppText.body(15, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          _Group(children: [
            const _Tile(icon: Icons.code_rounded, title: 'Conception et développement', subtitle: 'Owen Mengual'),
            const _Tile(icon: Icons.photo_library_outlined, title: 'Photos du catalogue', subtitle: 'Wikimedia Commons, auteurs crédités sur chaque fiche'),
            _Tile(icon: Icons.copyright_rounded, title: '© ${DateTime.now().year} Spot My Car', subtitle: 'Tous droits réservés'),
          ]),
        ],
      ),
    )));
  }

  void _openTerms() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
      title: "Conditions d'utilisation",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dernière mise à jour : novembre 2026', style: AppText.body(13, color: AppColors.inkSoft).copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          _buildLegalCard(
            icon: Icons.check_circle_outline,
            title: '1. Acceptation des conditions',
            content: "En utilisant Spot My Car, tu acceptes les présentes conditions. Si tu ne les acceptes pas, n'utilise pas le service.",
          ),
          _buildLegalCard(
            icon: Icons.rule_folder_outlined,
            title: '2. Utilisation du service',
            content: "Le service est destiné à un usage personnel. Ne publie pas de contenu illégal ou offensant, et ne photographie pas les personnes. Les fiches techniques sont fournies à titre indicatif.",
          ),
          _buildLegalCard(
            icon: Icons.security_outlined,
            title: '3. Confidentialité et données',
            content: "Ton e-mail sert uniquement à l'authentification. Les photos de tes spots et leur localisation restent privées : seuls ton pseudo, ton niveau et tes statistiques sont visibles par les autres joueurs. Les photos sont analysées par l'IA Gemini de Google pour reconnaître le modèle.",
          ),
          _buildLegalCard(
            icon: Icons.warning_amber_rounded,
            title: '4. Limitation de responsabilité',
            content: "Le service est fourni « en l'état ». Spot My Car ne pourra être tenu responsable des dommages résultant de son utilisation. Reste prudent : ne spotte jamais en conduisant.",
          ),
        ],
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final audio = context.watch<AudioService>();
    final notifications = NotificationService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          const _Header('Compte'),
          _Group(children: [
            _Tile(
              icon: Icons.person_outline_rounded,
              title: 'Modifier le profil',
              subtitle: 'Pseudo, marque préférée, avatar',
              onTap: () async {
                AudioService.instance.playSfx(SoundEffect.clicLeger);
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSetupScreen(initialUserData: userDoc.data())));
                }
              },
            ),
            if (currentUser.providerData.any((p) => p.providerId == 'password'))
              _Tile(
                icon: Icons.lock_outline_rounded,
                title: 'Changer le mot de passe',
                onTap: () => _sendPasswordResetEmail(context, currentUser.email!),
              ),
          ]),
          const _Header('Expérience'),
          _Group(children: [
            _Tile(
              icon: Icons.palette_outlined,
              title: 'Apparence',
              subtitle: 'Sombre, bleu nuit, clair… et ta couleur',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeSelectionScreen())),
            ),
            _Tile(
              icon: Icons.music_note_outlined,
              title: "Musique d'ambiance",
              subtitle: 'Night drive, très discrète',
              trailing: Switch(value: audio.isMusicEnabled, onChanged: audio.toggleMusic),
            ),
            _Tile(
              icon: Icons.graphic_eq_rounded,
              title: 'Effets sonores',
              subtitle: 'Déclencheur, montée en régime, succès',
              trailing: Switch(value: audio.isSfxEnabled, onChanged: audio.toggleSfx),
            ),
            ListenableBuilder(
              listenable: notifications,
              builder: (context, _) => _Tile(
                icon: Icons.notifications_none_rounded,
                title: 'Rappels',
                subtitle: 'Défi du jour, série en danger, bilan du dimanche',
                trailing: Switch(value: notifications.enabled, onChanged: notifications.setEnabled),
              ),
            ),
          ]),
          const _Header('Aide'),
          _Group(children: [
            _Tile(
              icon: Icons.support_agent_rounded,
              title: 'Contacter le support',
              subtitle: 'Une question, un bug, une idée',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactSupportScreen())),
            ),
            _Tile(icon: Icons.info_outline_rounded, title: "À propos de l'application", onTap: _openAbout),
            _Tile(icon: Icons.gavel_rounded, title: "Conditions d'utilisation", onTap: _openTerms),
          ]),
          const SizedBox(height: 22),
          _Group(children: [
            _Tile(
              icon: Icons.logout_rounded,
              title: _isSigningOut ? 'Déconnexion…' : 'Se déconnecter',
              onTap: _isSigningOut ? null : _signOut,
            ),
            _Tile(
              icon: Icons.delete_forever_outlined,
              title: 'Supprimer mon compte',
              danger: true,
              onTap: () => _showDeleteAccountDialog(context, currentUser),
            ),
          ]),
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
                              Text("Nouvelle adresse :", style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
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
                          AudioService.instance.playSfx(SoundEffect.clicLeger);
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
                    AudioService.instance.playSfx(SoundEffect.clicLeger);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    AudioService.instance.playSfx(SoundEffect.clicLeger);
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
              AudioService.instance.playSfx(SoundEffect.clicPrincipal);
              Navigator.pop(dialogContext);
            }, 
            child: const Text('Annuler')
          ),
          TextButton(
            onPressed: () {
              AudioService.instance.playSfx(SoundEffect.clicPrincipal);
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
            AudioService.instance.playSfx(SoundEffect.clicPrincipal);
            Navigator.pop(dialogContext);
          }, 
          child: const Text('Annuler')
        ),
        TextButton(
          onPressed: () async {
            AudioService.instance.playSfx(SoundEffect.clicPrincipal);
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


  



}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text.toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 58, color: AppColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _Tile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = danger ? AppColors.danger : accent;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AudioService.instance.playSfx(SoundEffect.clicLeger);
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(15, weight: FontWeight.w700, color: danger ? AppColors.danger : AppColors.ink)),
                  if (subtitle != null) Text(subtitle!, style: AppText.body(12.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
            trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
