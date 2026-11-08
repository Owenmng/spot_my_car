import 'package:spot_my_car/l10n/i18n.dart';
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
            Text(tr('Ajouter un ami'), style: AppText.display(24)),
            const SizedBox(height: 6),
            Text(tr('Demande-lui son identifiant : il est affiché en haut de son onglet Amis.'), style: AppText.body(14, color: AppColors.inkSoft)),
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
                final r = await SocialService.instance.sendRequest(ctrl.text).catchError((_) => tr('Erreur réseau, réessaie.'));
                if (ctx.mounted) Navigator.pop(ctx, r);
              },
              child: Text(tr('Envoyer la demande')),
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
              subtitle: Text(tr('Niveau {0} · {1} spots · {2} duels gagnés', [levelForXp(p.xp).level, p.spots, p.duelsWon])),
            ),
            const Divider(),
            ListTile(leading: const Icon(Icons.sports_mma_rounded), title: Text(tr('Lancer un duel')), onTap: () => Navigator.pop(ctx, 'duel')),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
              title: Text(tr('Retirer de mes amis'), style: TextStyle(color: AppColors.danger)),
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
          title: Text(tr('Retirer cet ami ?')),
          content: Text(tr('{0} ne verra plus ta progression dans son classement.', [p.name])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Retirer'), style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (confirm == true) {
        await SocialService.instance.remove(p.uid);
        if (mounted) showAppSnack(context, tr('{0} a été retiré.', [p.name]));
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
                Expanded(child: Text(_weekly ? tr('CETTE SEMAINE') : tr('DEPUIS TOUJOURS'), style: AppText.label(11.5, color: AppColors.inkMuted))),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [ButtonSegment(value: true, label: Text(tr('Semaine'))), ButtonSegment(value: false, label: Text(tr('Total')))],
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
                title: tr('Le paddock est vide'),
                message: tr('Ajoute des amis pour comparer vos garages chaque semaine et vous lancer des duels.'),
                action: ElevatedButton.icon(onPressed: _addFriend, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(tr('Ajouter un ami'))),
              )
            else ...[
              RankSummary(ranked: ranked, score: score, me: _me, weekly: _weekly).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: 12),
              RankTable(
                ranked: ranked,
                score: score,
                me: _me,
                weekly: _weekly,
                onTap: _friendMenu,
                onDuel: (p) async {
                  final ok = await showNewDuelSheet(context, opponent: p);
                  if (ok == true) widget.onChallenged?.call();
                },
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
                Text(tr('MON IDENTIFIANT'), style: AppText.label(10.5, color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: friendId == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: friendId!));
                          HapticFeedback.selectionClick();
                          showAppSnack(context, tr('Identifiant copié'), icon: Icons.copy_rounded);
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
            tooltip: tr('Inviter'),
            onPressed: friendId == null
                ? null
                : () => SharePlus.instance.share(ShareParams(
                      text: tr('On se défie sur Spot My Car ? Ajoute-moi avec mon identifiant : {0} 🏎️', [friendId]),
                    )),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(tooltip: tr('Ajouter un ami'), onPressed: onAdd, icon: const Icon(Icons.person_add_alt_1_rounded)),
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
              Text(tr('DEMANDES REÇUES'), style: AppText.label(11.5, color: AppColors.inkMuted)),
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
                                if (p != null) Text(tr('Niveau {0} · {1} spots', [levelForXp(p.xp).level, p.spots]), style: AppText.body(12.5, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Refuser'),
                            onPressed: () => SocialService.instance.decline(d.id),
                            icon: Icon(Icons.close_rounded, color: AppColors.inkMuted),
                          ),
                          IconButton.filled(
                            tooltip: tr('Accepter'),
                            onPressed: () async {
                              await SocialService.instance.accept(d.id, d.data()['fromUserId'] as String);
                              if (context.mounted) showAppSnack(context, tr('Vous êtes amis !'), icon: Icons.handshake_rounded);
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

/// Carte « ta position » : place, écart avec le pilote devant, avance sur celui derrière.
class RankSummary extends StatelessWidget {
  final List<Player> ranked;
  final int Function(Player) score;
  final String me;
  final bool weekly;
  const RankSummary({super.key, required this.ranked, required this.score, required this.me, required this.weekly});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final i = ranked.indexWhere((p) => p.uid == me);
    if (i < 0 || ranked.isEmpty) return const SizedBox.shrink();
    final mine = score(ranked[i]);
    final ahead = i > 0 ? ranked[i - 1] : null;
    final behind = i < ranked.length - 1 ? ranked[i + 1] : null;
    final gapAhead = ahead == null ? 0 : score(ahead) - mine;
    final lead = behind == null ? 0 : mine - score(behind);
    final progress = ahead == null ? 1.0 : (mine / (score(ahead) == 0 ? 1 : score(ahead))).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('P${i + 1}', style: AppText.mono(44, color: i == 0 ? _gold : AppColors.ink)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('/ ${ranked.length}', style: AppText.mono(15, color: AppColors.inkMuted)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(weekly ? tr('XP CETTE SEMAINE') : tr('XP TOTAL'), style: AppText.label(10, color: AppColors.inkMuted)),
                  Text('$mine', style: AppText.mono(24)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 5, color: i == 0 ? _gold : accent, backgroundColor: AppColors.paperDeep),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(ahead == null ? Icons.flag_rounded : Icons.keyboard_double_arrow_up_rounded, size: 16, color: ahead == null ? _gold : accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ahead == null
                      ? (behind == null ? tr('Seul en piste pour l’instant') : tr('En tête · {0} XP d’avance sur {1}', [lead, behind.name]))
                      : gapAhead == 0
                          ? tr('À égalité avec {0}', [ahead.name])
                          : tr('{0} XP pour dépasser {1}', [gapAhead, ahead.name]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tableau de classement façon « timing » : position, pilote, XP, écart au leader.
class RankTable extends StatelessWidget {
  final List<Player> ranked;
  final int Function(Player) score;
  final String me;
  final bool weekly;
  final int startRank;
  final void Function(Player)? onTap;
  final void Function(Player)? onDuel;

  const RankTable({
    super.key,
    required this.ranked,
    required this.score,
    required this.me,
    required this.weekly,
    this.startRank = 1,
    this.onTap,
    this.onDuel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final leaderScore = ranked.isEmpty ? 0 : score(ranked.first);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                SizedBox(width: 34, child: Text('POS', style: AppText.label(9.5, color: AppColors.inkMuted))),
                Expanded(child: Text('SPOTTER', style: AppText.label(9.5, color: AppColors.inkMuted))),
                SizedBox(width: 64, child: Text(weekly ? tr('XP SEM.') : 'XP', textAlign: TextAlign.right, style: AppText.label(9.5, color: AppColors.inkMuted))),
                SizedBox(width: 58, child: Text(tr('ÉCART'), textAlign: TextAlign.right, style: AppText.label(9.5, color: AppColors.inkMuted))),
                if (onDuel != null) const SizedBox(width: 36),
              ],
            ),
          ),
          for (var i = 0; i < ranked.length; i++) ...[
            Divider(height: 1, color: AppColors.line),
            _row(context, i, ranked[i], accent, leaderScore).animate().fadeIn(delay: (25 * (i % 20)).ms, duration: 220.ms),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, Player p, Color accent, int leaderScore) {
    final rank = startRank + i;
    final isMe = p.uid == me;
    final level = levelForXp(p.xp);
    final stripe = rank == 1 ? _gold : rank == 2 ? _silver : rank == 3 ? _bronze : (isMe ? accent : Colors.transparent);
    final gap = leaderScore - score(p);
    return InkWell(
      onTap: onTap == null || isMe ? null : () => onTap!(p),
      child: Container(
        color: isMe ? accent.withValues(alpha: 0.10) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 14, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 31,
                        child: Text('$rank', style: AppText.mono(15, color: rank <= 3 ? stripe : AppColors.inkSoft)),
                      ),
                      UserAvatar(photoUrl: p.photoUrl, name: p.name, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? tr('{0} · toi', [p.name]) : p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(14, weight: FontWeight.w800),
                            ),
                            Text(tr('Niv. {0} · {1}', [level.level, level.title]), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(11.5, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      SizedBox(width: 64, child: Text('${score(p)}', textAlign: TextAlign.right, style: AppText.mono(14))),
                      SizedBox(
                        width: 58,
                        child: Text(
                          rank == 1 && startRank == 1 ? 'LEADER' : '−$gap',
                          textAlign: TextAlign.right,
                          style: rank == 1 && startRank == 1 ? AppText.label(9.5, color: _gold) : AppText.mono(12, color: AppColors.inkMuted),
                        ),
                      ),
                      if (onDuel != null)
                        SizedBox(
                          width: 36,
                          child: isMe
                              ? null
                              : IconButton(
                                  tooltip: tr('Défier'),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => onDuel!(p),
                                  icon: Icon(Icons.sports_mma_rounded, size: 19, color: accent),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
