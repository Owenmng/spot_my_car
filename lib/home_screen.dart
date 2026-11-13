import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/screens/system_screens.dart';
import 'package:spot_my_car/screens/tutorial_screen.dart';
import 'package:spot_my_car/services/rate_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/add_car_screen.dart';
import 'package:spot_my_car/car_catalog_screen.dart';
import 'package:spot_my_car/collection_screen.dart';
import 'package:spot_my_car/garage_screen.dart';
import 'package:spot_my_car/profile_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/connectivity_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/loading_animation_widget.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _musicStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataManager>().loadAllData();
      _arrival();
    });
  }

  /// Arrivée sur l'accueil : présence, tutoriel la première fois, sinon demande de note.
  Future<void> _arrival() async {
    unawaited(RemoteConfig.instance.touchPresence());
    final rc = RemoteConfig.instance;
    if (rc.feature('tutorial') && !await TutorialScreen.isDone()) {
      String? pseudo;
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          pseudo = d.data()?['pseudo'] as String?;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await Navigator.push(context, PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => TutorialScreen(pseudo: pseudo),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));
      return;
    }
    if (mounted) await RateService.maybeAsk(context);
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    setState(() => _index = i);
  }

  Future<void> _spot() async {
    if (!context.read<ConnectivityService>().isOnline) {
      showAppSnack(context, tr('Il faut du réseau pour ajouter une voiture.'), icon: Icons.cloud_off_rounded);
      return;
    }
    AudioService.instance.playSfx(SoundEffect.clicPrincipal);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCarScreen(), fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataManager>();
    if (!data.isDataLoaded) {
      return LoadingAnimationWidget(loadingMessage: tr('On sort les voitures du garage…'));
    }
    if (!_musicStarted) {
      _musicStarted = true;
      Future.delayed(const Duration(milliseconds: 800), AudioService.instance.startMusic);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index != 0) {
          _select(0);
          return;
        }
        final quit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.garage_rounded, color: Theme.of(ctx).colorScheme.primary, size: 32),
            title: Text(tr('Quitter Spot My Car ?')),
            content: Text(tr('Ta collection reste au garage, tu pourras reprendre où tu en étais.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Quitter'))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Rester'))),
            ],
          ),
        );
        if (quit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                GarageScreen(onAddSpot: _spot),
                const CollectionScreen(),
                const CarCatalogScreen(),
                const ProfileScreen(),
              ],
            ),
            const Positioned(top: 0, left: 0, right: 0, child: AnnouncementBanner()),
          ],
        ),
        bottomNavigationBar: _NavBar(index: _index, onSelect: _select, onSpot: _spot),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSpot;

  const _NavBar({required this.index, required this.onSelect, required this.onSpot});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;

    Widget item(int i, IconData icon, IconData active, String label) {
      final selected = index == i;
      return Expanded(
        child: Pressable(
          haptic: false,
          onTap: () => onSelect(i),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(selected ? active : icon, key: ValueKey(selected), color: selected ? AppColors.ink : AppColors.inkMuted, size: 24),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: AppText.body(11, color: selected ? AppColors.ink : AppColors.inkMuted, weight: selected ? FontWeight.w800 : FontWeight.w600),
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.paper,
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottom + 8),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            item(0, Icons.garage_outlined, Icons.garage_rounded, tr('Garage')),
            item(1, Icons.shield_outlined, Icons.shield_rounded, tr('Collection')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Pressable(
                onTap: onSpot,
                pressedScale: 0.9,
                child: Container(
                  width: 58,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Icon(Icons.photo_camera_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26),
                ),
              ),
            ),
            item(2, Icons.menu_book_outlined, Icons.menu_book_rounded, tr('Catalogue')),
            item(3, Icons.person_outline_rounded, Icons.person_rounded, tr('Profil')),
          ],
        ),
      ),
    );
  }
}

