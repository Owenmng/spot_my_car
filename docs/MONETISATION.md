# Gagner de l'argent avec Spot My Car

## État au 14/11/2026
- ✅ Interrupteurs `premium` et `rewardedAds` ALLUMÉS (console › Pilotage de l'appli).
- ✅ Pro offert : bouton « Devenir membre » sur un compte admin = Pro à vie gratuit (« Gratuit pour toi, patron »).
- ✅ Console › Utilisateurs › fiche joueur : +1 mois / +1 an / À vie / Retirer.
- ✅ API Google Play Android Developer activée sur le projet Cloud ; noreply.spotmycar@gmail.com invité dans la Play Console (données financières + commandes/abonnements).
- ✅ noreply a rejoint la Play Console (2 étapes activées), scope androidpublisher ajouté et autorisé, serveur version 7.
- ⏳ Google met jusqu'à 24-36 h à propager les droits Play du compte noreply (l'API répond 401 en attendant) : pendant ce temps un achat est activé 7 jours à titre provisoire (UNVERIFIED).
- ✅ IBAN ajouté (en attente de validation par Google).
- ✅ 14/11 : build 1.1.0 (26) signé avec la clé d'envoi (android/app/spotmycar-release-key.keystore, mot de passe dans android/key.properties sur le PC d'Owen) et publié en test interne : https://play.google.com/apps/internaltest/4700529544740792873
- ✅ Abonnements actifs : spotmycar_plus_mensuel (forfait « mensuel », 2,99 €) et spotmycar_plus_annuel (forfait « annuel », 19,99 €), prix convertis dans 178 pays.


Tout est déjà codé dans la 1.1 et **éteint par défaut** : deux interrupteurs dans la console admin
(« Pilotage de l'appli ») : `Spot My Car+ (abonnement)` et `Pubs récompensées`.

## Le modèle

| Source | Prix | Ce que le joueur gagne |
|---|---|---|
| **Spot My Car+** mensuel | 2,99 € / mois | Coffre du jour ×2, primes d'avis de recherche ×2, 2 ambiances et 5 couleurs exclusives, badge PLUS doré, zéro pub |
| **Spot My Car+** annuel | 19,99 € / an (≈ 2 mois offerts) | Pareil |
| **Pub récompensée** (AdMob) | gratuite pour le joueur | Doubler le coffre du jour en regardant une courte vidéo, au choix, jamais imposée |

Google garde 15 % des abonnements. AdMob reverse environ 5 à 20 € pour 1 000 vidéos vues en France.

## À faire une seule fois (c'est gratuit)

### 1. Abonnements Google Play
✅ 13/11/2026 : profil de paiement marchand activé (profil existant « Owen Mengual », nom public « Spot My Car », contact owen.mengual@gmail.com, relevé « SPOT MY CAR »).
⏳ Owen : ajouter le compte bancaire (Play Console › Gérer le compte › Profil de paiement › Ajouter un mode de paiement). Ce compte sert aussi pour AdMob.

Étapes :
1. Play Console › **Paramètres › Profil de paiement** : créer le profil marchand (nom, adresse, IBAN).
2. Envoyer un build 1.1 sur la piste **Test interne**. Le test fermé n'est pas touché. Play n'autorise la création des abonnements qu'une fois qu'un build contenant la facturation a été envoyé.
3. Play Console › **Monétiser › Produits › Abonnements** : créer
   - `spotmycar_plus_mensuel` avec un forfait de base mensuel à renouvellement automatique, 2,99 € ;
   - `spotmycar_plus_annuel` avec un forfait de base annuel à renouvellement automatique, 19,99 €.
4. Play Console › **Utilisateurs et autorisations** : inviter `noreply.spotmycar@gmail.com` avec « Afficher les données financières » et « Gérer les commandes et les abonnements ».
5. Console Google Cloud (projet `car-spotter-app-779f2`) : activer l'API **Google Play Android Developer API**.
6. Claude ajoute le scope `androidpublisher` au serveur et le republie. Une fenêtre d'autorisation Google s'ouvre : cliquer « Autoriser ».

### 2. AdMob ✅ fait le 13/11/2026
- Compte AdMob créé sur owen.mengual@gmail.com (rattaché à l'éditeur AdSense pub-1863774498742699).
- Appli « Spot My Car » (Android) : `ca-app-pub-1863774498742699~4951288709`
- Bloc avec récompense « Coffre x2 » : `ca-app-pub-1863774498742699/8377342481`
- Les comptes admin et les builds de debug utilisent le bloc de test Google (pas de clics sur ses propres pubs).
- Reste : relier l'appli à sa fiche Play une fois publiée (AdMob › Applications › Paramètres de l'appli) pour lancer l'examen.

Étapes d'origine :
1. admob.google.com : créer le compte avec le compte Google de la Play Console.
2. Ajouter l'appli (Android, publiée sur Play), puis créer un bloc d'annonces **Avec récompense**.
3. **Confidentialité et messages** : activer le message RGPD (obligatoire en Europe ; l'appli l'affiche toute seule).
4. Donner à Claude l'**ID d'application** (`ca-app-pub-…~…`) et l'**ID du bloc** (`ca-app-pub-…/…`). Il remplace les ID de test dans `AndroidManifest.xml` et `app_constants.dart`.

### 3. Fiche Play
- **Contenu de l'appli › Annonces** : « Oui, mon appli contient des annonces ».
- **Sécurité des données** : ajouter ce que collecte le SDK AdMob (identifiants d'appareil, diagnostics) et les achats.
- Claude met à jour la politique de confidentialité (AdMob et Google Play Billing).

### 4. Allumer
Console admin › Pilotage de l'appli : allumer `Spot My Car+` puis `Pubs récompensées`. C'est instantané, sans mise à jour de l'appli.

## Comment ça marche (technique)
- L'appli achète via `in_app_purchase`. Le serveur (`plus.verify`) vérifie le jeton auprès de Google, écrit `plus.until` dans `users/{uid}`, et les règles Firestore empêchent l'appli de l'écrire elle-même.
- Un même achat ne peut activer qu'un seul compte (collection `plus_tokens`).
- Pubs : `google_mobile_ads` avec le consentement UMP. Elles ne s'affichent jamais aux membres Plus et ne sont jamais imposées.
