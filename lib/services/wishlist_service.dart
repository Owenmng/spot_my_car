import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// « Dans le viseur » : les modèles que le joueur rêve de croiser.
/// Les spotter rapporte un bonus et les retire de la liste.
class WishlistService {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  static const bonusXp = 30;
  static const maxTargets = 12;

  DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Stream<List<String>> watch() {
    final ref = _ref;
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map((s) => ((s.data()?['wishlist'] as List?) ?? const []).whereType<String>().toList());
  }

  /// Ajoute ou retire ; renvoie false si la liste est pleine.
  Future<bool> toggle(String modelId, {required bool add, int current = 0}) async {
    final ref = _ref;
    if (ref == null) return false;
    if (add && current >= maxTargets) return false;
    await ref.set({'wishlist': add ? FieldValue.arrayUnion([modelId]) : FieldValue.arrayRemove([modelId])}, SetOptions(merge: true));
    return true;
  }
}
