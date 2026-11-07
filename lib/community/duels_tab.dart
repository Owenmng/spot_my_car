import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/daily_challenge.dart';
import 'package:spot_my_car/services/duel_service.dart';
import 'package:spot_my_car/services/social_service.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:spot_my_car/widgets/user_avatar.dart';

const _gold = Color(0xFFFFD447);

/// Feuille « nouveau duel » : mode, thème éventuel, durée.
Future<bool?> showNewDuelSheet(BuildContext context, {Player? opponent}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NewDuelSheet(opponent: opponent),
  );
}

class _NewDuelSheet extends StatefulWidget {
  final Player? opponent;
  const _NewDuelSheet({this.opponent});

  @override
  State<_NewDuelSheet> createState() => _NewDuelSheetState();
}

class _NewDuelSheetState extends State<_NewDuelSheet> {
  DuelMode _mode = DuelMode.xp;
  DailyChallenge _theme = (DailyChallenge.duelThemes.toList()..shuffle()).first;
  int _hours = 24;
  Player? _opponent;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
  }

  Future<void> _send() async {
    final o = _opponent;
    if (o == null) return;
    setState(() => _sending = true);
    try {
      await DuelService.instance.challenge(opponentUid: o.uid, mode: _mode, themeId: _mode == DuelMode.theme ? _theme.id : null, hours: _hours);
      AudioService.instance.playSfx(SoundEffect.notification);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
      if (mounted) showAppSnack(context, 'Défi envoyé à ${o.name} !', icon: Icons.sports_mma_rounded);
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        showAppSnack(context, "Le défi n'est pas parti. Réessaie.", icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final stake = _hours <= 24 ? 100 : _hours <= 72 ? 150 : 250;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouveau duel', style: AppText.display(26)),
              const SizedBox(height: 14),
              if (_opponent == null)
                StreamBuilder<List<Player>>(
                  stream: SocialService.instance.watchCircle(),
                  builder: (context, snap) {
                    final me = FirebaseAuth.instance.currentUser?.uid;
                    final friends = (snap.data ?? []).where((p) => p.uid != me).toList();
                    if (friends.isEmpty) {
                      return Text("Ajoute d'abord un ami dans l'onglet Amis.", style: AppText.body(14, color: AppColors.inkSoft));
                    }
                    return SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in friends)
                            Pressable(
                              onTap: () => setState(() => _opponent = f),
                              child: SizedBox(
                                width: 72,
                                child: Column(
                                  children: [
                                    UserAvatar(photoUrl: f.photoUrl, name: f.name, size: 50),
                                    const SizedBox(height: 6),
                                    Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, weight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              else
                Row(
                  children: [
                    UserAvatar(photoUrl: _opponent!.photoUrl, name: _opponent!.name, size: 40, ring: accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Contre ${_opponent!.name}', style: AppText.body(16, weight: FontWeight.w800))),
                    if (widget.opponent == null) TextButton(onPressed: () => setState(() => _opponent = null), child: const Text('Changer')),
                  ],
                ),
              const SizedBox(height: 18),
              Text('MODE', style: AppText.label(11, color: AppColors.inkMuted)),
              const SizedBox(height: 8),
              for (final m in DuelMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: () => setState(() => _mode = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _mode == m ? accent.withValues(alpha: 0.12) : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: _mode == m ? accent : AppColors.line, width: _mode == m ? 1.6 : 1),
                      ),
                      child: Row(
                        children: [
                          Icon(m.icon, color: _mode == m ? accent : AppColors.inkSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.title, style: AppText.body(15, weight: FontWeight.w800)),
                                Text(m == DuelMode.theme ? '${_theme.title} : ${_theme.hint.toLowerCase()}' : m.rule, style: AppText.body(12.5, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                          if (m == DuelMode.theme && _mode == m)
                            IconButton(
                              tooltip: 'Autre thème',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                final pool = DailyChallenge.duelThemes.where((t) => t.id != _theme.id).toList()..shuffle();
                                setState(() => _theme = pool.first);
                              },
                              icon: const Icon(Icons.casino_outlined),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text('DURÉE', style: AppText.label(11, color: AppColors.inkMuted)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 24, label: Text('24 h')),
                  ButtonSegment(value: 72, label: Text('3 jours')),
                  ButtonSegment(value: 168, label: Text('1 semaine')),
                ],
                selected: {_hours},
                onSelectionChanged: (s) => setState(() => _hours = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: _gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Le vainqueur remporte +$stake XP. Le chrono démarre quand ${_opponent?.name ?? 'ton ami'} accepte.', style: AppText.body(13, color: AppColors.inkSoft))),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _opponent == null || _sending ? null : _send,
                icon: const Icon(Icons.sports_mma_rounded),
                label: Text(_sending ? 'Envoi…' : 'Lancer le défi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste des duels : invitations, duels en cours, palmarès.
class DuelsTab extends StatefulWidget {
  const DuelsTab({super.key});

  @override
  State<DuelsTab> createState() => _DuelsTabState();
}

class _DuelsTabState extends State<DuelsTab> with AutomaticKeepAliveClientMixin {
  late final Stream<List<Duel>> _duels = DuelService.instance.watch();
  final Map<String, Future<Player?>> _players = {};
  Timer? _tick;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _syncMine();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _syncMine() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: uid).get();
    await DuelService.instance.sync(snap.docs.map((d) => d.data()).toList());
  }

  Future<Player?> _player(String uid) => _players.putIfAbsent(uid, () => SocialService.instance.player(uid));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<Duel>>(
      stream: _duels,
      builder: (context, snap) {
        final duels = snap.data ?? [];
        final invites = duels.where((d) => d.isPending && d.opponentId == me).toList();
        final waiting = duels.where((d) => d.isPending && d.challengerId == me).toList();
        final live = duels.where((d) => d.isActive).toList();
        final done = duels.where((d) => d.isFinished || d.status == 'declined').toList();
        final wins = duels.where((d) => d.winner == me).length;
        final losses = duels.where((d) => d.winner != null && d.winner != '' && d.winner != me).length;

        return RefreshIndicator(
          onRefresh: _syncMine,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              _Record(wins: wins, losses: losses, onNew: () => showNewDuelSheet(context)),
              if (snap.connectionState == ConnectionState.waiting && duels.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              if (snap.hasData && duels.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: EmptyState(
                    icon: Icons.sports_mma_rounded,
                    title: 'Aucun duel pour l’instant',
                    message: 'Défie un ami : course aux XP, chasse à la voiture la plus rare, tour des marques ou thème imposé.',
                  ),
                ),
              if (invites.isNotEmpty) ...[
                _label('ON TE DÉFIE'),
                for (final d in invites) _DuelCard(duel: d, me: me, player: _player),
              ],
              if (live.isNotEmpty) ...[
                _label('EN COURS'),
                for (final d in live) _DuelCard(duel: d, me: me, player: _player),
              ],
              if (waiting.isNotEmpty) ...[
                _label('EN ATTENTE DE RÉPONSE'),
                for (final d in waiting) _DuelCard(duel: d, me: me, player: _player),
              ],
              if (done.isNotEmpty) ...[
                _label('TERMINÉS'),
                for (final d in done.take(15)) _DuelCard(duel: d, me: me, player: _player),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(t, style: AppText.label(11.5, color: AppColors.inkMuted)),
      );
}

class _Record extends StatelessWidget {
  final int wins;
  final int losses;
  final VoidCallback onNew;
  const _Record({required this.wins, required this.losses, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(colors: [Color.lerp(AppColors.card, accent, 0.22)!, AppColors.card], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PALMARÈS', style: AppText.label(10.5, color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$wins', style: AppText.display(34, color: AppColors.success)),
                    Text(' V  ', style: AppText.label(12, color: AppColors.inkSoft)),
                    Text('$losses', style: AppText.display(34, color: AppColors.danger)),
                    Text(' D', style: AppText.label(12, color: AppColors.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(onPressed: onNew, icon: const Icon(Icons.add_rounded), label: const Text('Défier')),
        ],
      ),
    );
  }
}

class _DuelCard extends StatelessWidget {
  final Duel duel;
  final String me;
  final Future<Player?> Function(String) player;
  const _DuelCard({required this.duel, required this.me, required this.player});

  String _timeLeft() {
    final end = duel.endAt;
    if (end == null) return '';
    final d = end.difference(DateTime.now());
    if (d.isNegative) return 'Terminé';
    if (d.inHours >= 24) return '${d.inDays} j ${d.inHours % 24} h';
    if (d.inMinutes >= 60) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final otherUid = duel.other(me);
    final mine = duel.scoreOf(me);
    final theirs = duel.scoreOf(otherUid);
    final total = (mine + theirs) == 0 ? 1 : mine + theirs;
    final winner = duel.winner;

    return FutureBuilder<Player?>(
      future: player(otherUid),
      builder: (context, snap) {
        final other = snap.data;
        final name = other?.name ?? '…';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: duel.isActive ? accent.withValues(alpha: 0.5) : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(duel.mode.icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(duel.title.toUpperCase(), style: AppText.label(12, color: AppColors.ink))),
                  if (duel.isActive)
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fadeOut(duration: 700.ms),
                        const SizedBox(width: 6),
                        Text(_timeLeft(), style: AppText.mono(12, color: AppColors.inkSoft)),
                      ],
                    )
                  else
                    Text('+${duel.stake} XP', style: AppText.mono(12, color: _gold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(duel.rule, style: AppText.body(12.5, color: AppColors.inkSoft)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Side(label: 'Toi', score: duel.isPending ? null : duel.scoreLabel(mine), win: winner == me, alignEnd: false),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('VS', style: AppText.display(18, color: AppColors.inkMuted)),
                  ),
                  _Side(label: name, photoUrl: other?.photoUrl, score: duel.isPending ? null : duel.scoreLabel(theirs), win: winner == otherUid, alignEnd: true),
                ],
              ),
              if (!duel.isPending && duel.status != 'declined') ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(flex: ((mine / total) * 1000).round().clamp(1, 1000), child: ColoredBox(color: accent)),
                        Expanded(flex: ((theirs / total) * 1000).round().clamp(1, 1000), child: ColoredBox(color: AppColors.panelHi)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _actions(context, name),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }

  Widget _actions(BuildContext context, String name) {
    final svc = DuelService.instance;
    if (duel.isPending && duel.opponentId == me) {
      final days = duel.hours < 48 ? '24 h' : '${duel.hours ~/ 24} jours';
      return Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: () => svc.decline(duel), child: const Text('Refuser'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () async {
                await svc.accept(duel);
                HapticFeedback.heavyImpact();
                AudioService.instance.playSfx(SoundEffect.notification);
                if (context.mounted) showAppSnack(context, 'C’est parti pour $days !', icon: Icons.flag_rounded);
              },
              child: Text('Accepter ($days)'),
            ),
          ),
        ],
      );
    }
    if (duel.isPending) {
      return Row(
        children: [
          Expanded(child: Text('En attente de $name…', style: AppText.body(13, color: AppColors.inkSoft))),
          TextButton(onPressed: () => svc.cancel(duel), child: const Text('Annuler')),
        ],
      );
    }
    if (duel.status == 'declined') {
      return Row(
        children: [
          Expanded(child: Text('$name a décliné.', style: AppText.body(13, color: AppColors.inkSoft))),
          TextButton(onPressed: () => svc.remove(duel), child: const Text('Effacer')),
        ],
      );
    }
    if (duel.isActive) {
      return Text(
        duel.scoreOf(me) > duel.scoreOf(duel.other(me))
            ? 'Tu mènes. Garde le rythme !'
            : duel.scoreOf(me) == duel.scoreOf(duel.other(me))
                ? 'Égalité parfaite. Le prochain spot fait la différence.'
                : '$name mène. Sors spotter !',
        style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600),
      );
    }
    final w = duel.winner;
    if (w == me) {
      final claimed = duel.claimed[me] == true;
      return Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: _gold),
          const SizedBox(width: 8),
          Expanded(child: Text('Victoire !', style: AppText.body(15, weight: FontWeight.w800, color: _gold))),
          if (!claimed)
            ElevatedButton(
              onPressed: () async {
                final ok = await svc.claim(duel).catchError((_) => false);
                if (ok) {
                  AudioService.instance.playSfx(SoundEffect.succesPrincipal);
                  HapticFeedback.heavyImpact();
                }
                if (context.mounted) showAppSnack(context, ok ? '+${duel.stake} XP encaissés' : 'Déjà encaissé', icon: Icons.emoji_events_rounded);
              },
              child: Text('Encaisser +${duel.stake}'),
            )
          else
            Text('Encaissé', style: AppText.body(13, color: AppColors.inkSoft)),
        ],
      );
    }
    return Text(w == '' ? 'Match nul. Revanche ?' : '$name l’emporte. Revanche ?', style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600));
  }
}

class _Side extends StatelessWidget {
  final String label;
  final String? photoUrl;
  final String? score;
  final bool win;
  final bool alignEnd;
  const _Side({required this.label, this.photoUrl, required this.score, required this.win, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final children = [
      if (alignEnd) UserAvatar(photoUrl: photoUrl, name: label, size: 36, ring: win ? _gold : null),
      if (alignEnd) const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: alignEnd ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700)),
            Text(score ?? '—', style: AppText.display(22, color: win ? _gold : AppColors.ink)),
          ],
        ),
      ),
    ];
    return Expanded(
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: children,
      ),
    );
  }
}
