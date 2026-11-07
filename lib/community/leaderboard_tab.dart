import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/community/friends_tab.dart';
import 'package:spot_my_car/services/social_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Classement mondial : les 100 meilleurs spotters.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> with AutomaticKeepAliveClientMixin {
  late Future<List<Player>> _top = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<Player>> _load() async {
    final snap = await FirebaseFirestore.instance.collection('users').orderBy('totalXp', descending: true).limit(100).get();
    return snap.docs.map((d) => Player(d.id, d.data())).where((p) => p.xp > 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<List<Player>>(
      future: _top,
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? const EmptyState(icon: Icons.cloud_off_rounded, title: 'Classement indisponible', message: 'Vérifie ta connexion et réessaie.')
              : const Center(child: CircularProgressIndicator());
        }
        final players = snap.data!;
        final myIndex = players.indexWhere((p) => p.uid == me);
        return RefreshIndicator(
          onRefresh: () async {
            final f = _load();
            setState(() => _top = f);
            await f;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (players.isEmpty)
                const EmptyState(icon: Icons.leaderboard_outlined, title: 'Personne au classement', message: 'Spotte une voiture pour ouvrir le bal.')
              else ...[
                RankPodium(players: players.take(3).toList(), score: (p) => p.xp, me: me, weekly: false),
                const SizedBox(height: 14),
                if (myIndex < 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                    child: Text('Tu n’es pas encore dans le top 100. Chaque spot rare te rapproche du podium.', style: AppText.body(13.5, color: AppColors.inkSoft)),
                  ),
                for (var i = 3; i < players.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RankRow(rank: i + 1, player: players[i], score: players[i].xp, weekly: false, isMe: players[i].uid == me)
                        .animate()
                        .fadeIn(delay: (20 * (i % 15)).ms, duration: 250.ms),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
