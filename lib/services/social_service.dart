import 'package:spot_my_car/services/push_service.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spot_my_car/services/duel_service.dart';

/// Un joueur tel qu'on l'affiche dans les classements.
class Player {
  final String uid;
  final Map<String, dynamic> data;
  Player(this.uid, this.data);

  String get name {
    final p = (data['pseudo'] as String?)?.trim();
    if (p != null && p.isNotEmpty) return p;
    return (data['friendId'] as String?) ?? tr('Joueur');
  }

  String? get photoUrl => data['photoUrl'] as String?;
  int get xp => (data['totalXp'] as num?)?.toInt() ?? 0;
  int get weekXp => ((data['xpByWeek'] as Map?)?[weekKey()] as num?)?.toInt() ?? 0;
  Map get stats => (data['stats'] as Map?) ?? const {};
  int get spots => (stats['totalSpots'] as num?)?.toInt() ?? 0;
  int get duelsWon => (stats['duelsWon'] as num?)?.toInt() ?? 0;
  String? get favoriteBrand => stats['favoriteBrandName'] as String?;
  DateTime? get lastSpotAt => (data['lastSpotAt'] as Timestamp?)?.toDate();
}

class SocialService {
  SocialService._();
  static final SocialService instance = SocialService._();

  final _db = FirebaseFirestore.instance;

  /// Moi + mes amis, profils à jour à chaque changement de la liste d'amis.
  Stream<List<Player>> watchCircle() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('friends').snapshots().asyncMap((snap) async {
      final ids = [uid, ...snap.docs.map((d) => d.id)];
      final players = <Player>[];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
        final res = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        players.addAll(res.docs.map((d) => Player(d.id, d.data())));
      }
      return players;
    });
  }

  Future<String> sendRequest(String rawFriendId) async {
    final me = FirebaseAuth.instance.currentUser!;
    final friendId = rawFriendId.replaceAll(RegExp(r'\s'), '');
    if (friendId.isEmpty) return tr('Entre l\'identifiant de ton ami.');
    final found = await _db.collection('users').where('friendId', isEqualTo: friendId).limit(1).get();
    if (found.docs.isEmpty) return tr('Aucun joueur avec cet identifiant.');
    final other = found.docs.first.id;
    if (other == me.uid) return tr('C\'est ton propre identifiant !');
    final already = await _db.collection('users').doc(me.uid).collection('friends').doc(other).get();
    if (already.exists) return tr('Vous êtes déjà amis.');
    final sent = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: me.uid)
        .where('toUserId', isEqualTo: other)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (sent.docs.isNotEmpty) return tr('Demande déjà envoyée, patience.');
    final received = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: other)
        .where('toUserId', isEqualTo: me.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (received.docs.isNotEmpty) {
      await accept(received.docs.first.id, other);
      return tr('Il t’avait déjà invité : vous êtes amis !');
    }
    final ref = await _db.collection('friend_requests').add({
      'fromUserId': me.uid,
      'toUserId': other,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    PushService.notify('friend_request', ref.id);
    return tr('Demande envoyée !');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncoming() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _db.collection('friend_requests').where('toUserId', isEqualTo: uid).where('status', isEqualTo: 'pending').snapshots();
  }

  Future<void> accept(String requestId, String fromUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final batch = _db.batch();
    batch.update(_db.collection('friend_requests').doc(requestId), {'status': 'accepted'});
    batch.set(_db.collection('users').doc(me).collection('friends').doc(fromUid), {'friendSince': FieldValue.serverTimestamp()});
    batch.set(_db.collection('users').doc(fromUid).collection('friends').doc(me), {'friendSince': FieldValue.serverTimestamp()});
    await batch.commit();
    PushService.notify('friend_accept', requestId);
  }

  Future<void> decline(String requestId) => _db.collection('friend_requests').doc(requestId).delete();

  Future<void> remove(String friendUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(me).collection('friends').doc(friendUid));
    batch.delete(_db.collection('users').doc(friendUid).collection('friends').doc(me));
    await batch.commit();
  }

  Future<Player?> player(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    return d.exists ? Player(d.id, d.data()!) : null;
  }
}
