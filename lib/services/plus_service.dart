import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';

/// Spot My Car+ : abonnement Google Play (mensuel ou annuel).
///
/// L'achat se fait côté Play, puis le serveur vérifie le jeton auprès de
/// Google et écrit `plus.until` dans le profil : c'est la seule source de vérité.
class PlusService extends ChangeNotifier {
  PlusService._();
  static final instance = PlusService._();

  static const monthlyId = 'spotmycar_plus_mensuel';
  static const yearlyId = 'spotmycar_plus_annuel';
  static const ids = {monthlyId, yearlyId};

  DateTime? _until;
  StreamSubscription? _userSub;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> products = {};
  bool storeReady = false;
  bool busy = false;
  String? lastError;
  bool _started = false;

  /// Le paywall n'apparaît que si la fonctionnalité est allumée dans la console.
  bool get enabled => RemoteConfig.instance.feature('premium');

  /// Membre actif (le serveur gère l'expiration ; on garde 1 jour de marge hors ligne).
  bool get isPlus => _until != null && _until!.add(const Duration(days: 1)).isAfter(DateTime.now());
  DateTime? get until => _until;

  void start() {
    if (_started) return;
    _started = true;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      _until = null;
      notifyListeners();
      if (user == null) return;
      _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
        final plus = snap.data()?['plus'];
        final t = plus is Map ? plus['until'] : null;
        final next = t is Timestamp ? t.toDate() : null;
        if (next != _until) {
          _until = next;
          notifyListeners();
        }
      }, onError: (_) {});
    });
    if (!kIsWeb) {
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (e) {
        lastError = '$e';
        busy = false;
        notifyListeners();
      });
    }
  }

  Future<void> loadProducts() async {
    if (kIsWeb) return;
    try {
      storeReady = await InAppPurchase.instance.isAvailable();
      if (!storeReady) {
        notifyListeners();
        return;
      }
      final res = await InAppPurchase.instance.queryProductDetails(ids);
      for (final p in res.productDetails) {
        products[p.id] = p;
      }
    } catch (e) {
      lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> buy(String productId) async {
    final p = products[productId];
    if (p == null) {
      lastError = 'unavailable';
      notifyListeners();
      return;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (e) {
      busy = false;
      lastError = '$e';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (kIsWeb) return;
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
    Future.delayed(const Duration(seconds: 6), () {
      if (busy) {
        busy = false;
        notifyListeners();
      }
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!ids.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          busy = true;
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          busy = false;
          lastError = p.status == PurchaseStatus.error ? (p.error?.message ?? 'error') : null;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final res = await BackendService.instance.call('plus.verify', {
              'productId': p.productID,
              'purchaseToken': p.verificationData.serverVerificationData,
            });
            final until = DateTime.tryParse('${res['until'] ?? ''}');
            if (until != null) _until = until;
          } catch (e) {
            lastError = '$e';
          }
          busy = false;
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }
}
