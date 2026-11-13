import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spot_my_car/services/plus_service.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/shared/app_constants.dart';

/// Pubs récompensées (AdMob) : toujours au choix du joueur, jamais imposées,
/// et jamais pour les membres Spot My Car+.
class AdsService {
  AdsService._();
  static final instance = AdsService._();

  bool _initialized = false;
  RewardedAd? _ad;
  bool _loading = false;

  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && RemoteConfig.instance.feature('rewardedAds') && !PlusService.instance.isPlus;

  /// Consentement RGPD (formulaire Google UMP) puis initialisation du SDK.
  Future<bool> _init() async {
    if (_initialized) return true;
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!consent.isCompleted) consent.complete();
        });
      },
      (_) {
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    _initialized = true;
    return true;
  }

  /// Précharge une vidéo pour qu'elle démarre sans attente.
  Future<void> preload() async {
    if (!available || _ad != null || _loading) return;
    _loading = true;
    try {
      if (!await _init()) return;
      final done = Completer<void>();
      RewardedAd.load(
        adUnitId: (kDebugMode || RemoteConfig.instance.isAdmin) ? AppConstants.rewardedAdUnitTestId : AppConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            done.complete();
          },
          onAdFailedToLoad: (_) => done.complete(),
        ),
      );
      await done.future.timeout(const Duration(seconds: 25), onTimeout: () {});
    } catch (_) {
    } finally {
      _loading = false;
    }
  }

  /// Affiche la vidéo ; renvoie true si le joueur l'a regardée jusqu'au bout.
  Future<bool> showRewarded() async {
    if (!available) return false;
    if (_ad == null) await preload();
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    unawaited(preload());
    return earned;
  }

  /// Lien de révocation RGPD : rouvre le formulaire de choix de confidentialité.
  Future<void> openPrivacyOptions() async {
    if (kIsWeb) return;
    await _init();
    ConsentForm.showPrivacyOptionsForm((_) {});
  }
}
