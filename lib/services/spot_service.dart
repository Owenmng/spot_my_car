
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/photo_store.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/services/wanted_service.dart';
import 'package:spot_my_car/services/wishlist_service.dart';
import 'package:spot_my_car/services/duel_service.dart';

class SpotDraft {
  Map<String, dynamic>? brand;
  Map<String, dynamic>? model;
  String customBrand = '';
  String customModel = '';
  String plate = '';
  String countryCode = 'FR';
  String? color;
  String? locationName;
  double? latitude;
  double? longitude;
  String note = '';
  Uint8List? photo;
  String? aiGuess;
  double? aiConfidence;

  bool get isCustomBrand => brand == null || brand!['id'] == 'other';
  bool get isCustomModel => model == null || model!['id'] == 'other';
  bool get isCatalogued => !isCustomBrand && !isCustomModel;

  String get brandName => isCustomBrand ? customBrand.trim() : (brand!['name'] as String);
  String get modelName => isCustomModel ? customModel.trim() : (model!['name'] as String);

  Rarity get rarity => rarityFor(brand: isCustomBrand ? null : brand, model: isCatalogued ? model : null);
  int get xp => isCatalogued ? rarity.xp : 0;
}

class SpotSaveResult {
  final String carId;
  final int xpGained;
  final int oldXp;
  final int newXp;
  final Level oldLevel;
  final Level? newLevel;
  final List<AchievementLevel> newAchievements;
  final List<Achievement> achievementsAfter;
  final bool photoFailed;
  final bool targetHit;
  final bool wantedHit;

  /// XP de base retirée par l'anti-triche (même modèle répété, limite du jour), et pourquoi.
  final int xpPenalty;
  final String? penaltyReason;

  const SpotSaveResult({
    this.xpPenalty = 0,
    this.penaltyReason,
    this.targetHit = false,
    this.wantedHit = false,
    required this.carId,
    required this.xpGained,
    required this.oldXp,
    required this.newXp,
    required this.oldLevel,
    required this.newLevel,
    required this.newAchievements,
    required this.achievementsAfter,
    required this.photoFailed,
  });
}

class DuplicatePlateException implements Exception {
  @override
  String toString() => tr('Cette plaque est déjà dans ton garage.');
}

/// Même photo (ou quasi identique) qu'un spot déjà dans le garage.
class DuplicatePhotoException implements Exception {
  @override
  String toString() => tr('Cette photo est déjà dans ton garage.');
}

/// Même modèle, même couleur, au même endroit il y a peu : sûrement la même voiture.
/// L'appli demande confirmation avant d'enregistrer.
class SimilarSpotException implements Exception {
  final String carName;
  final int minutesAgo;
  SimilarSpotException(this.carName, this.minutesAgo);
}

/// Empreinte visuelle d'une photo (dHash 64 bits) : deux copies de la même photo,
/// même recompressées, recadrées légèrement ou en capture d'écran, donnent presque la même empreinte.
String? photoFingerprint(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.grayscale(img.copyResize(img.bakeOrientation(decoded), width: 9, height: 8, interpolation: img.Interpolation.average));
  var bits = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final a = small.getPixel(x, y).r;
      final b = small.getPixel(x + 1, y).r;
      bits = (bits << 1) | (a > b ? BigInt.one : BigInt.zero);
    }
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

int _hamming(String a, String b) {
  var x = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var n = 0;
  while (x > BigInt.zero) {
    if (x & BigInt.one == BigInt.one) n++;
    x = x >> 1;
  }
  return n;
}

String _plateKey(String? p) => (p ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

double _km(GeoPoint a, double lat, double lng) {
  const r = 6371.0;
  final dLat = (lat - a.latitude) * math.pi / 180;
  final dLng = (lng - a.longitude) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.latitude * math.pi / 180) * math.cos(lat * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

class SpotService {
  SpotService._();
  static final instance = SpotService._();

  final _db = FirebaseFirestore.instance;

  /// Limite de spots qui rapportent de l'XP de base par jour.
  static const dailyXpSpots = 40;

  Future<SpotSaveResult> save(SpotDraft d, {bool confirmedDifferent = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Tu dois être connecté.');

    final plate = d.plate.trim().toUpperCase();
    final userRef = _db.collection('users').doc(user.uid);

    final mySpots = await _db.collection('spotted_cars').where('userId', isEqualTo: user.uid).get();

    // 1. Même plaque (espaces et tirets ignorés).
    final pk = _plateKey(plate);
    if (pk.isNotEmpty && mySpots.docs.any((doc) => _plateKey(doc.data()['plate']?.toString()) == pk)) {
      throw DuplicatePlateException();
    }

    // 2. Même photo, même recompressée ou recadrée.
    String? fingerprint;
    if (d.photo != null) {
      try {
        fingerprint = await compute(photoFingerprint, d.photo!);
      } catch (_) {}
      if (fingerprint != null) {
        for (final doc in mySpots.docs) {
          final other = doc.data()['photoHash'];
          if (other is String && other.length == 16 && _hamming(other, fingerprint) <= 5) throw DuplicatePhotoException();
        }
      }
    }

    // 3. Même modèle, même couleur, au même endroit depuis moins de 3 h : on demande confirmation.
    final now = DateTime.now();
    final key = '${d.brandName}|${d.modelName}'.toLowerCase();
    bool sameModel(Map<String, dynamic> c) =>
        (d.model?['id'] != null && c['modelId'] == d.model!['id']) ||
        '${c['brandName']}|${c['modelName']}'.toLowerCase() == key;
    DateTime? when(Map<String, dynamic> c) => c['spottedAt'] is Timestamp ? (c['spottedAt'] as Timestamp).toDate() : null;
    if (!confirmedDifferent) {
      for (final doc in mySpots.docs) {
        final c = doc.data();
        final t = when(c);
        if (t == null || now.difference(t).inMinutes > 180 || !sameModel(c)) continue;
        final colorOk = d.color == null || c['color'] == null || c['color'] == d.color;
        final geo = c['locationCoords'];
        final near = geo is! GeoPoint || d.latitude == null || d.longitude == null || _km(geo, d.latitude!, d.longitude!) <= 1.0;
        if (colorOk && near) throw SimilarSpotException('${d.brandName} ${d.modelName}'.trim(), now.difference(t).inMinutes);
      }
    }

    // 4. XP dégressive : même modèle en 24 h (50 %, puis 20 %), et limite de spots par jour.
    final last24 = mySpots.docs.map((e) => e.data()).where((c) {
      final t = when(c);
      return t != null && now.difference(t).inHours < 24;
    }).toList();
    final repeats = last24.where(sameModel).length;
    final today = last24.where((c) {
      final t = when(c)!;
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).length;
    var baseXp = d.xp;
    String? penaltyReason;
    if (today >= dailyXpSpots) {
      baseXp = 0;
      penaltyReason = tr('Limite de {0} spots par jour atteinte : pas d\'XP de base', [dailyXpSpots]);
    } else if (repeats >= 2) {
      baseXp = (d.xp * 0.2).round();
      penaltyReason = tr('Déjà spottée plusieurs fois aujourd\'hui : XP réduite');
    } else if (repeats == 1) {
      baseXp = (d.xp * 0.5).round();
      penaltyReason = tr('Même modèle déjà spotté aujourd\'hui : XP divisée par deux');
    }
    final xpPenalty = d.xp - baseXp;

    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};
    final oldXp = (userData['totalXp'] as num?)?.toInt() ?? 0;
    final claims = Map<String, dynamic>.from(userData['claimedAchievements'] as Map? ?? {});

    final data = DataManager.instance;
    if (!data.isDataLoaded) await data.loadAllData();
    final spotsBefore = mySpots.docs.map((doc) => doc.data()).toList();
    final achievementsBefore = AchievementService(allBrands: data.brands, spottedCars: spotsBefore).checkAchievements(calculateProgress: true);

    final carRef = _db.collection('spotted_cars').doc();

    final car = <String, dynamic>{};
    if (d.isCatalogued) {
      car.addAll(d.model!);
      car.remove('name');
      car.remove('tags');
      car.addAll({
        'brandId': d.brand!['id'],
        'brandName': d.brand!['name'],
        'modelId': d.model!['id'],
        'modelName': d.model!['name'],
        'modelImageUrl': d.model!['imageUrl'],
        'isCatalogued': true,
      });
    } else {
      car.addAll({
        'brandName': d.brandName,
        'modelName': d.modelName,
        'brandId': d.isCustomBrand ? null : d.brand!['id'],
        'modelId': null,
        'modelImageUrl': null,
        'isCatalogued': false,
      });
    }

    car.addAll({
      'userId': user.uid,
      'plate': plate,
      'spottedAt': Timestamp.now(),
      'color': d.color,
      'plateCountryCode': d.countryCode,
      'locationName': d.locationName,
      'locationCoords': (d.latitude != null && d.longitude != null) ? GeoPoint(d.latitude!, d.longitude!) : null,
      'rarity': d.isCatalogued ? d.rarity.name : null,
      'xp': baseXp,
      if (fingerprint != null) 'photoHash': fingerprint,
      if (d.note.trim().isNotEmpty) 'note': d.note.trim(),
      if (d.aiGuess != null) 'aiGuess': d.aiGuess,
      if (d.aiConfidence != null) 'aiConfidence': double.parse(d.aiConfidence!.toStringAsFixed(2)),
    });

    var photoFailed = false;
    Uint8List? photo;
    if (d.photo != null) {
      try {
        photo = await PhotoStore.compress(d.photo!);
        car['hasPhoto'] = true;
      } catch (e) {
        debugPrint('Photo compression failed: $e');
        photoFailed = true;
      }
    }
    car['userPhotoUrl'] = null;

    final spotsAfter = [...spotsBefore, car];
    final achievementsAfter = AchievementService(allBrands: data.brands, spottedCars: spotsAfter).checkAchievements(calculateProgress: true);

    final unlocked = <AchievementLevel>[];
    var achievementXp = 0;
    for (final after in achievementsAfter) {
      final before = achievementsBefore.where((b) => b.id == after.id);
      final claimed = (claims[after.id] as num?)?.toInt() ?? (before.isEmpty ? 0 : before.first.unlockedLevel);
      if (after.unlockedLevel > claimed) {
        for (var i = claimed; i < after.unlockedLevel && i < after.levels.length; i++) {
          unlocked.add(after.levels[i]);
          achievementXp += after.levels[i].xpReward;
        }
        claims[after.id] = after.unlockedLevel;
      }
    }

    final wishlist = ((userData['wishlist'] as List?) ?? const []).whereType<String>().toList();
    final targetId = d.model?['id'] as String?;
    final targetHit = targetId != null && wishlist.contains(targetId);
    final wantedHit = RemoteConfig.instance.feature('wanted') && !d.isCustomBrand && d.brand!['id'] == Wanted.brandIdFor() && !Wanted.claimed(userData);
    final gained = baseXp + achievementXp + (targetHit ? WishlistService.bonusXp : 0) + (wantedHit ? Wanted.bounty : 0);
    final batch = _db.batch();
    batch.set(carRef, car);
    if (photo != null) {
      batch.set(PhotoStore.ref(carRef.id), {
        'userId': user.uid,
        'data': Blob(photo),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      userRef,
      {
        'totalXp': FieldValue.increment(gained),
        'xpByWeek': {weekKey(): FieldValue.increment(gained)},
        'stats': {
          'totalSpots': FieldValue.increment(1),
          'uniqueBrands': spotsAfter.map((c) => c['brandId']).whereType<String>().toSet().length,
          'uniqueModels': spotsAfter.map((c) => c['modelId']).whereType<String>().toSet().length,
        },
        'claimedAchievements': claims,
        'lastSpotAt': FieldValue.serverTimestamp(),
        if (targetHit) 'wishlist': FieldValue.arrayRemove([targetId]),
        if (wantedHit) 'wantedClaims': {weekKey(): true},
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    final oldLevel = levelForXp(oldXp);
    final newLevel = levelForXp(oldXp + gained);

    return SpotSaveResult(
      carId: carRef.id,
      xpGained: gained,
      oldXp: oldXp,
      newXp: oldXp + gained,
      oldLevel: oldLevel,
      newLevel: newLevel.level > oldLevel.level ? newLevel : null,
      newAchievements: unlocked,
      achievementsAfter: achievementsAfter,
      photoFailed: photoFailed,
      targetHit: targetHit,
      wantedHit: wantedHit,
      xpPenalty: xpPenalty,
      penaltyReason: penaltyReason,
    );
  }

  Future<void> sendRecognitionFeedback({required String? aiGuess, required String chosen}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || aiGuess == null || aiGuess == chosen) return;
    try {
      await _db.collection('recognition_feedback').add({
        'userId': user.uid,
        'aiGuess': aiGuess,
        'chosen': chosen,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
