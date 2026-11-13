import 'package:spot_my_car/screens/plus_screen.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/screens/referral_screen.dart';
import 'package:spot_my_car/l10n/i18n.dart';
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
import 'package:spot_my_car/services/auth_service.dart';
import 'package:spot_my_car/theme_selection_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/services/notification_service.dart';
import 'package:spot_my_car/widgets/language_picker.dart';
import 'package:spot_my_car/screens/delete_account_screen.dart';
import 'package:spot_my_car/forgot_password_screen.dart';
import 'package:spot_my_car/screens/music_screen.dart';
import 'package:spot_my_car/screens/tutorial_screen.dart';
import 'package:spot_my_car/screens/plate_lookup_screen.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';


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
        showAppSnack(context, tr('Déconnexion impossible, réessaie.'), icon: Icons.error_outline);
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _openAbout() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
      title: tr('À propos'),
      content: Column(
        children: [
          const AppLogo(size: 84),
          const SizedBox(height: 18),
          Text(tr('SPOT MY CAR'), style: AppText.display(28)),
          Text(tr('Version {0} ({1})', [packageInfo.version, packageInfo.buildNumber]), style: AppText.mono(13, color: AppColors.inkSoft)),
          const SizedBox(height: 20),
          Text(
            tr('Chaque voiture croisée devient une carte de collection. Photographie, laisse l\'IA reconnaître le modèle, complète ton garage et défie tes amis.'),
            textAlign: TextAlign.center,
            style: AppText.body(15, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          _Group(children: [
            _Tile(icon: Icons.code_rounded, title: tr('Conception et développement'), subtitle: tr('Owen Mengual')),
            _Tile(icon: Icons.photo_library_outlined, title: tr('Photos du catalogue'), subtitle: tr('Wikimedia Commons, auteurs crédités sur chaque fiche')),
            _Tile(icon: Icons.copyright_rounded, title: tr('© {0} Spot My Car', [DateTime.now().year]), subtitle: tr('Tous droits réservés')),
          ]),
        ],
      ),
    )));
  }

  void _openTerms() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => InfoPageScreen(
      title: tr('Conditions d\'utilisation'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Dernière mise à jour : novembre 2026'), style: AppText.body(13, color: AppColors.inkSoft).copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          _buildLegalCard(
            icon: Icons.check_circle_outline,
            title: tr('1. Acceptation des conditions'),
            content: tr('En utilisant Spot My Car, tu acceptes les présentes conditions. Si tu ne les acceptes pas, n\'utilise pas le service.'),
          ),
          _buildLegalCard(
            icon: Icons.rule_folder_outlined,
            title: tr('2. Utilisation du service'),
            content: tr('Le service est destiné à un usage personnel. Ne publie pas de contenu illégal ou offensant, et ne photographie pas les personnes. Les fiches techniques sont fournies à titre indicatif.'),
          ),
          _buildLegalCard(
            icon: Icons.security_outlined,
            title: tr('3. Confidentialité et données'),
            content: tr('Ton e-mail sert uniquement à l\'authentification. Les photos de tes spots et leur localisation restent privées : seuls ton pseudo, ton niveau et tes statistiques sont visibles par les autres joueurs. Les photos sont analysées par l\'IA Gemini de Google pour reconnaître le modèle.'),
          ),
          _buildLegalCard(
            icon: Icons.warning_amber_rounded,
            title: tr('4. Limitation de responsabilité'),
            content: tr('Le service est fourni « en l\'état ». Spot My Car ne pourra être tenu responsable des dommages résultant de son utilisation. Reste prudent : ne spotte jamais en conduisant.'),
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
      appBar: AppBar(title: Text(tr('Paramètres'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Header(tr('Compte')),
          _Group(children: [
            if (PlusService.instance.enabled || PlusService.instance.isPlus)
              _Tile(
                icon: Icons.workspace_premium_rounded,
                title: 'Spot My Car+',
                subtitle: PlusService.instance.isPlus ? tr('Membre actif · gérer mon abonnement') : tr('Coffre doublé, thèmes exclusifs, zéro pub'),
                onTap: () => PlusScreen.open(context),
              ),
            _Tile(
              icon: Icons.person_outline_rounded,
              title: tr('Modifier le profil'),
              subtitle: tr('Pseudo, marque préférée, avatar'),
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
                title: tr('Changer le mot de passe'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: currentUser.email))),
              ),
            if (RemoteConfig.instance.feature('referral'))
              _Tile(
                icon: Icons.card_giftcard_rounded,
                title: tr('Parrainage'),
                subtitle: tr('Ton code ami : +{0} XP pour toi et pour eux', [ReferralScreen.reward]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen())),
              ),
          ]),
          _Header(tr('Expérience')),
          _Group(children: [
            _Tile(
              icon: Icons.palette_outlined,
              title: tr('Apparence'),
              subtitle: tr('Sombre, bleu nuit, clair… et ta couleur'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeSelectionScreen())),
            ),
            ListenableBuilder(
              listenable: I18n.instance,
              builder: (context, _) => _Tile(
                icon: Icons.translate_rounded,
                title: tr('Langue'),
                subtitle: '${I18n.instance.language.flag}  ${I18n.instance.language.name}',
                onTap: () => showLanguageSheet(context),
              ),
            ),
            _Tile(
              icon: Icons.music_note_outlined,
              title: tr('Musique d\'ambiance'),
              subtitle: audio.isMusicEnabled ? audio.track.name : tr('Désactivée'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicScreen())),
            ),
            _Tile(
              icon: Icons.graphic_eq_rounded,
              title: tr('Effets sonores'),
              subtitle: tr('Déclencheur, montée en régime, succès'),
              trailing: Switch(value: audio.isSfxEnabled, onChanged: audio.toggleSfx),
            ),
            ListenableBuilder(
              listenable: notifications,
              builder: (context, _) => _Tile(
                icon: Icons.notifications_none_rounded,
                title: tr('Notifications'),
                subtitle: tr('Défi du jour, série en danger, bilan du dimanche'),
                trailing: Switch(value: notifications.enabled, onChanged: notifications.setEnabled),
              ),
            ),
          ]),
          _Header(tr('Aide')),
          _Group(children: [
            _Tile(
              icon: Icons.support_agent_rounded,
              title: tr('Contacter le support'),
              subtitle: tr('Une question, un bug, une idée'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactSupportScreen())),
            ),
            _Tile(
              icon: Icons.school_outlined,
              title: tr('Revoir le tutoriel'),
              subtitle: tr('Les bases de Spot My Car en 30 secondes'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
            ),
            _Tile(
              icon: Icons.pin_outlined,
              title: tr('Assistant plaque'),
              subtitle: tr('Retrouver une voiture à partir de sa plaque'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlateLookupScreen())),
            ),
            if (RemoteConfig.instance.isAdmin)
              _Tile(
                icon: Icons.admin_panel_settings_outlined,
                title: tr('Console d\'administration'),
                subtitle: 'car-spotter-app-779f2.web.app/admin',
                onTap: () => launchUrl(Uri.parse('https://car-spotter-app-779f2.web.app/admin/'), mode: LaunchMode.externalApplication),
              ),
            _Tile(icon: Icons.info_outline_rounded, title: tr('À propos de l\'application'), onTap: _openAbout),
            _Tile(icon: Icons.gavel_rounded, title: tr('Conditions d\'utilisation'), onTap: _openTerms),
          ]),
          const SizedBox(height: 22),
          _Group(children: [
            _Tile(
              icon: Icons.logout_rounded,
              title: _isSigningOut ? tr('Déconnexion…') : tr('Se déconnecter'),
              onTap: _isSigningOut ? null : _signOut,
            ),
            _Tile(
              icon: Icons.delete_forever_outlined,
              title: tr('Supprimer mon compte'),
              danger: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            ),
          ]),
        ],
      ),
    );
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
