import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/add_car_screen.dart';
import 'package:spot_my_car/car_catalog_screen.dart';
import 'package:spot_my_car/collection_screen.dart';
import 'package:spot_my_car/community_screen.dart';
import 'package:spot_my_car/services/duel_service.dart';
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
            title: const Text('Quitter Spot My Car ?'),
            content: const Text('Ta collection reste au garage, tu pourras reprendre où tu en étais.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rester')),
            ],
          ),
        );
        if (quit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(
          index: _index,
          children: [
            GarageScreen(onAddSpot: _spot),
            const CollectionScreen(),
            const CarCatalogScreen(),
            const CommunityScreen(),
            const ProfileScreen(),
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
      padding: EdgeInsets.fromLTRB(10, 6, 10, bottom + 8),
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
                  width: 52,
                  height: 48,
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
            _PaddockItem(selected: index == 3, onTap: () => onSelect(3)),
            item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
          ],
        ),
      ),
    );
  }
}

/// Onglet Paddock avec pastille quand un défi attend une réponse.
class _PaddockItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _PaddockItem({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        haptic: false,
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: StreamBuilder<List<Duel>>(
            stream: DuelService.instance.watch(),
            builder: (context, snap) {
              final me = DuelService.instance.myUid;
              final pending = (snap.data ?? const []).where((d) => (d.isPending && d.opponentId == me) || (d.winner == me && d.claimed[me] != true) || d.needsMyQuiz(me)).length;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(selected ? Icons.emoji_events_rounded : Icons.emoji_events_outlined, color: selected ? AppColors.ink : AppColors.inkMuted, size: 24),
                      if (pending > 0)
                        Positioned(
                          right: -6,
                          top: -3,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0xFFFFD447), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.panel, width: 1.5)),
                            child: Text('$pending', style: AppText.mono(8.5, color: Colors.black)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Paddock', maxLines: 1, style: AppText.body(11, color: selected ? AppColors.ink : AppColors.inkMuted, weight: selected ? FontWeight.w800 : FontWeight.w600)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
