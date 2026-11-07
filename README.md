# SpotMyCar

Repère une voiture dans la rue, prends-la en photo : l'IA reconnaît la marque, le modèle, la génération et la plaque, et la voiture rejoint ta collection sous forme de carte (Commune → Légendaire).

## Ce qu'il faut côté Firebase (projet `car-spotter-app-779f2`)

1. **Forfait Blaze** : obligatoire pour le bucket Storage (photos du catalogue, logos, photos des joueurs) et les Cloud Functions (classement). Mettre une alerte de budget à 1 €.
2. **AI Logic** → API Gemini Developer activée (reconnaissance des voitures). Pendant les tests en APK installé à la main, laisser App Check *non appliqué* pour AI Logic.
3. **Règles** : publier `firestore.rules` et `storage.rules` (console ou `firebase deploy --only firestore:rules,storage`).

## Compiler

- Chaque push sur `main` ou `refonte` lance GitHub Actions (`.github/workflows/build.yml`) : analyse + APK téléchargeable dans l'onglet *Actions* → *Artifacts*.
- En local : `flutter pub get` puis `flutter build apk --release` (signature release si `android/key.properties` est présent, sinon signature debug).

## Structure

- `lib/theme/` : couleurs, typo, thème (accent au choix dans *Apparence*).
- `lib/services/vehicle_recognition_service.dart` : reconnaissance Gemini + rapprochement avec le catalogue.
- `lib/services/spot_service.dart` : enregistrement d'un spot, XP, succès.
- `lib/widgets/` : carte de collection, plaque, images avec repli, kit UI.
- `assets/data/` : catalogue (marques + ~2 900 modèles).
