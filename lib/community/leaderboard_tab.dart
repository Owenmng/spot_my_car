import 'package:spot_my_car/l10n/i18n.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
              ? EmptyState(icon: Icons.cloud_off_rounded, title: tr('Classement indisponible'), message: tr('Vérifie ta connexion et réessaie.'))
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
                EmptyState(icon: Icons.leaderboard_outlined, title: tr('Personne au classement'), message: tr('Spotte une voiture pour ouvrir le bal.'))
              else ...[
                if (myIndex >= 0) ...[
                  RankSummary(ranked: players, score: (p) => p.xp, me: me, weekly: false),
                  const SizedBox(height: 12),
                ] else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                    child: Text(tr('Tu n’es pas encore dans le top 100. Chaque spot rare te rapproche du classement.'), style: AppText.body(13.5, color: AppColors.inkSoft)),
                  ),
                RankTable(ranked: players, score: (p) => p.xp, me: me, weekly: false),
              ],
            ],
          ),
        );
      },
    );
  }
}
