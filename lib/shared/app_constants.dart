class AppConstants {
  /// Boîte qui reçoit les messages du support (relayés gratuitement par FormSubmit en secours).
  static const String supportEmail = 'owen.mengual@gmail.com';
  static const String supportRelay = 'https://formsubmit.co/ajax/$supportEmail';
  static const String termsOfServiceUrl = 'https://car-spotter-app-779f2.web.app/confidentialite/';
  static const String privacyUrl = 'https://car-spotter-app-779f2.web.app/confidentialite/';

  /// Serveur gratuit Spot My Car (Google Apps Script, compte noreply.spotmycar@gmail.com).
  static const String serverUrl = 'https://script.google.com/macros/s/AKfycbyhZgprpk3RiE6TYZw-VYop71P22PWWUxMOBeh4sl9KUPY6rESIYSZ51vc88wBqnbQguw/exec';

  /// Fiche Google Play.
  static const String packageName = 'com.owenmengual.spotmycar';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';
  static const String playStoreMarket = 'market://details?id=$packageName';

  /// Bloc de pub récompensée AdMob « Coffre x2 » (compte AdMob d'Owen).
  static const String rewardedAdUnitId = 'ca-app-pub-1863774498742699/8377342481';

  /// Bloc de TEST Google : utilisé pour les comptes admin, pour ne jamais cliquer sur ses propres pubs.
  static const String rewardedAdUnitTestId = 'ca-app-pub-3940256099942544/5224354917';
}
