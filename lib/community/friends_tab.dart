import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spot_my_car/community/duels_tab.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/services/social_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:spot_my_car/widgets/user_avatar.dart';

const _gold = Color(0xFFFFD447);
const _silver = Color(0xFFC9CED6);
const _bronze = Color(0xFFD08A4E);

/// Classement entre amis (total ou semaine), demandes, invitation et défis.
class FriendsTab extends StatefulWidget {
  final VoidCallback? onChallenged;
  const FriendsTab({super.key, this.onChallenged});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> with AutomaticKeepAliveClientMixin {
  bool _weekly = true;
  late final Stream<List<Player>> _circle = SocialService.instance.watchCircle();

  @override
  bool get wantKeepAlive => true;

  String get _me => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _addFriend() async {
    final ctrl = TextEditingController();
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ajouter un ami', style: AppText.display(24)),
            const SizedBox(height: 6),
            Text("Demande-lui son identifiant : il est affiché en haut de son onglet Amis.", style: AppText.body(14, color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: AppText.mono(20),
              decoration: const InputDecoration(hintText: '12345678', prefixIcon: Icon(Icons.tag_rounded)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                final r = await SocialService.instance.sendRequest(ctrl.text).catchError((_) => 'Erreur réseau, réessaie.');
                if (ctx.mounted) Navigator.pop(ctx, r);
              },
              child: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
    if (msg != null && mounted) showAppSnack(context, msg, icon: Icons.person_add_alt_1_rounded);
  }

  Future<void> _friendMenu(Player p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: UserAvatar(photoUrl: p.photoUrl, name: p.name, size: 40),
              title: Text(p.name, style: AppText.body(16, weight: FontWeight.w800)),
              subtitle: Text('Niveau ${levelForXp(p.xp).level} · ${p.spots} spots · ${p.duelsWon} duels gagnés'),
            ),
            const Divider(),
            ListTile(leading: const Icon(Icons.sports_mma_rounded), title: const Text('Lancer un duel'), onTap: () => Navigator.pop(ctx, 'duel')),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
              title: const Text('Retirer de mes amis', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'duel') {
      final ok = await showNewDuelSheet(context, opponent: p);
      if (ok == true) widget.onChallenged?.call();
    } else if (action == 'remove') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Retirer cet ami ?'),
          content: Text('${p.name} ne verra plus ta progression dans son classement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (confirm == true) {
        await SocialService.instance.remove(p.uid);
        if (mounted) showAppSnack(context, '${p.name} a été retiré.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Player>>(
      stream: _circle,
      builder: (context, snap) {
        final players = snap.data ?? [];
        final me = players.where((p) => p.uid == _me).firstOrNull;
        final ranked = players.toList()..sort((a, b) => _weekly ? b.weekXp.compareTo(a.weekXp) : b.xp.compareTo(a.xp));
        int score(Player p) => _weekly ? p.weekXp : p.xp;
        final friendsCount = players.length - 1;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            _InviteCard(friendId: me?.data['friendId'] as String?, onAdd: _addFriend),
            const _Requests(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Text(_weekly ? 'CETTE SEMAINE' : 'DEPUIS TOUJOURS', style: AppText.label(11.5, color: AppColors.inkMuted))),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [ButtonSegment(value: true, label: Text('Semaine')), ButtonSegment(value: false, label: Text('Total'))],
                  selected: {_weekly},
                  onSelectionChanged: (s) => setState(() => _weekly = s.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (snap.connectionState == ConnectionState.waiting && players.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (friendsCount <= 0)
              EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'Le paddock est vide',
                message: 'Ajoute des amis pour comparer vos garages chaque semaine et vous lancer des duels.',
                action: ElevatedButton.icon(onPressed: _addFriend, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Ajouter un ami')),
              )
            else ...[
              RankPodium(players: ranked.take(3).toList(), score: score, me: _me, weekly: _weekly),
              const SizedBox(height: 14),
              for (var i = 0; i < ranked.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RankRow(
                    rank: i + 1,
                    player: ranked[i],
                    score: score(ranked[i]),
                    weekly: _weekly,
                    isMe: ranked[i].uid == _me,
                    onTap: ranked[i].uid == _me ? null : () => _friendMenu(ranked[i]),
                    onDuel: ranked[i].uid == _me
                        ? null
                        : () async {
                            final ok = await showNewDuelSheet(context, opponent: ranked[i]);
                            if (ok == true) widget.onChallenged?.call();
                          },
                  ).animate().fadeIn(delay: (40 * i).ms, duration: 250.ms).slideX(begin: 0.04, end: 0),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String? friendId;
  final VoidCallback onAdd;
  const _InviteCard({required this.friendId, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(colors: [Color.lerp(AppColors.card, accent, 0.18)!, AppColors.card], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MON IDENTIFIANT', style: AppText.label(10.5, color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: friendId == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: friendId!));
                          HapticFeedback.selectionClick();
                          showAppSnack(context, 'Identifiant copié', icon: Icons.copy_rounded);
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(friendId ?? '········', style: AppText.mono(22)),
                      const SizedBox(width: 8),
                      Icon(Icons.copy_rounded, size: 16, color: AppColors.inkMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Inviter',
            onPressed: friendId == null
                ? null
                : () => SharePlus.instance.share(ShareParams(
                      text: 'On se défie sur Spot My Car ? Ajoute-moi avec mon identifiant : $friendId 🏎️',
                    )),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(tooltip: 'Ajouter un ami', onPressed: onAdd, icon: const Icon(Icons.person_add_alt_1_rounded)),
        ],
      ),
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SocialService.instance.watchIncoming(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DEMANDES REÇUES', style: AppText.label(11.5, color: AppColors.inkMuted)),
              const SizedBox(height: 8),
              for (final d in docs)
                FutureBuilder<Player?>(
                  future: SocialService.instance.player(d.data()['fromUserId'] as String),
                  builder: (context, ps) {
                    final p = ps.data;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                      child: Row(
                        children: [
                          UserAvatar(photoUrl: p?.photoUrl, name: p?.name ?? '?', size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p?.name ?? '…', style: AppText.body(15, weight: FontWeight.w800)),
                                if (p != null) Text('Niveau ${levelForXp(p.xp).level} · ${p.spots} spots', style: AppText.body(12.5, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refuser',
                            onPressed: () => SocialService.instance.decline(d.id),
                            icon: Icon(Icons.close_rounded, color: AppColors.inkMuted),
                          ),
                          IconButton.filled(
                            tooltip: 'Accepter',
                            onPressed: () async {
                              await SocialService.instance.accept(d.id, d.data()['fromUserId'] as String);
                              if (context.mounted) showAppSnack(context, 'Vous êtes amis !', icon: Icons.handshake_rounded);
                            },
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class RankPodium extends StatelessWidget {
  final List<Player> players;
  final int Function(Player) score;
  final String me;
  final bool weekly;
  const RankPodium({required this.players, required this.score, required this.me, required this.weekly});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    // Ordre visuel : 2e, 1er, 3e
    final order = [if (players.length > 1) 1, 0, if (players.length > 2) 2];
    const heights = [96.0, 72.0, 56.0];
    const colors = [_gold, _silver, _bronze];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: Column(
              children: [
                if (i == 0) const Icon(Icons.emoji_events_rounded, color: _gold, size: 22).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -3, duration: 900.ms),
                UserAvatar(photoUrl: players[i].photoUrl, name: players[i].name, size: i == 0 ? 64 : 52, ring: colors[i]),
                const SizedBox(height: 6),
                Text(
                  players[i].uid == me ? 'Toi' : players[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(13.5, weight: FontWeight.w800),
                ),
                Text('${score(players[i])} XP', style: AppText.mono(12, color: colors[i])),
                const SizedBox(height: 6),
                Container(
                  height: heights[i],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [colors[i].withValues(alpha: 0.35), colors[i].withValues(alpha: 0.05)],
                    ),
                    border: Border(top: BorderSide(color: colors[i], width: 2)),
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}', style: AppText.display(30, color: colors[i])),
                ).animate().scaleY(begin: 0, alignment: Alignment.bottomCenter, duration: 500.ms, delay: (120 * i).ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
      ],
    );
  }
}

class RankRow extends StatelessWidget {
  final int rank;
  final Player player;
  final int score;
  final bool weekly;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onDuel;

  const RankRow({required this.rank, required this.player, required this.score, required this.weekly, required this.isMe, this.onTap, this.onDuel});

  String _lastSeen() {
    final t = player.lastSpotAt;
    if (t == null) return 'Pas encore de spot';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'A spotté il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'A spotté il y a ${d.inHours} h';
    if (d.inDays < 7) return 'A spotté il y a ${d.inDays} j';
    return 'Au garage depuis un moment';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final level = levelForXp(player.xp);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: isMe ? Color.lerp(AppColors.card, accent, 0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isMe ? accent.withValues(alpha: 0.6) : AppColors.line),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, child: Text('$rank', style: AppText.mono(15, color: rank <= 3 ? [_gold, _silver, _bronze][rank - 1] : AppColors.inkMuted))),
            UserAvatar(photoUrl: player.photoUrl, name: player.name, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isMe ? '${player.name} (toi)' : player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(15, weight: FontWeight.w800)),
                  Text('Niv. ${level.level} ${level.title} · ${_lastSeen()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: AppText.mono(16)),
                Text(weekly ? 'XP sem.' : 'XP', style: AppText.label(9, color: AppColors.inkMuted)),
              ],
            ),
            if (onDuel != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Défier',
                visualDensity: VisualDensity.compact,
                onPressed: onDuel,
                icon: Icon(Icons.sports_mma_rounded, color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
