import 'package:flutter/material.dart';
import 'package:spot_my_car/community/duels_tab.dart';
import 'package:spot_my_car/community/friends_tab.dart';
import 'package:spot_my_car/community/leaderboard_tab.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Le paddock : amis, duels et classement mondial.
class CommunityScreen extends StatefulWidget {
  final int initialTab;
  const CommunityScreen({super.key, this.initialTab = 0});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) AudioService.instance.playSfx(SoundEffect.clicLeger);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void goToDuels() => _tabs.animateTo(1);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paddock'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
              child: StreamBuilder<List<Duel>>(
                stream: DuelService.instance.watch(),
                builder: (context, snap) {
                  final pending = (snap.data ?? []).where((d) => d.isPending).length;
                  return TabBar(
                    controller: _tabs,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9)),
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor: AppColors.inkSoft,
                    labelStyle: AppText.body(14, weight: FontWeight.w800),
                    unselectedLabelStyle: AppText.body(14, weight: FontWeight.w600),
                    tabs: [
                      const Tab(text: 'Amis'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Duels'),
                            if (pending > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFFFD447), borderRadius: BorderRadius.circular(99)),
                                child: Text('$pending', style: AppText.mono(11, color: Colors.black)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(text: 'Mondial'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          FriendsTab(onChallenged: goToDuels),
          const DuelsTab(),
          const LeaderboardTab(),
        ],
      ),
    );
  }
}
