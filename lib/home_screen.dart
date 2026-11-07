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
    });
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    setState(() => _index = i);
  }

  Future<void> _spot() async {
    if (!context.read<ConnectivityService>().isOnline) {
      showAppSnack(context, 'Il faut du réseau pour ajouter une voiture.', icon: Icons.cloud_off_rounded);
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
      return const LoadingAnimationWidget(loadingMessage: 'On sort les voitures du garage…');
    }
    if (!_musicStarted) {
      _musicStarted = true;
      Future.delayed(const Duration(milliseconds: 800), AudioService.instance.startMusic);
    }

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _index,
        children: [
          GarageScreen(onAddSpot: _spot),
          const CollectionScreen(),
          const CarCatalogScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _NavBar(index: _index, onSelect: _select, onSpot: _spot),
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
            item(0, Icons.garage_outlined, Icons.garage_rounded, 'Garage'),
            item(1, Icons.shield_outlined, Icons.shield_rounded, 'Collection'),
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
            item(2, Icons.menu_book_outlined, Icons.menu_book_rounded, 'Catalogue'),
            item(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
          ],
        ),
      ),
    );
  }
}
