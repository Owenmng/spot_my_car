
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:spot_my_car/models/level_model.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/achievement_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/photo_store.dart';
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

  const SpotSaveResult({
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
  String toString() => 'Cette plaque est déjà dans ton garage.';
}

class SpotService {
  SpotService._();
  static final instance = SpotService._();

  final _db = FirebaseFirestore.instance;

  Future<SpotSaveResult> save(SpotDraft d) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Tu dois être connecté.');

    final plate = d.plate.trim().toUpperCase();
    final userRef = _db.collection('users').doc(user.uid);

    final mySpots = await _db.collection('spotted_cars').where('userId', isEqualTo: user.uid).get();
    if (plate.isNotEmpty && mySpots.docs.any((doc) => (doc.data()['plate'] as String?)?.toUpperCase() == plate)) {
      throw DuplicatePlateException();
    }

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
      'xp': d.xp,
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

    final gained = d.xp + achievementXp;
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
