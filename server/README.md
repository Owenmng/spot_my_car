# Serveur gratuit de Spot My Car

Tout tourne gratuitement chez Google, sans forfait Blaze.

| Élément | Où | Rôle |
|---|---|---|
| Script « Spot My Car - Serveur » | script.google.com, compte **noreply.spotmycar@gmail.com** | Codes e-mail, mails de l'appli, support, API de la console |
| Console d'administration | https://car-spotter-app-779f2.web.app/admin/ | Utilisateurs, stats, idées, pilotage, e-mails |
| Page d'accueil + confidentialité | https://car-spotter-app-779f2.web.app | Vitrine publique |

URL du serveur (déjà dans l'appli et la console) :
`https://script.google.com/macros/s/AKfycbyhZgprpk3RiE6TYZw-VYop71P22PWWUxMOBeh4sl9KUPY6rESIYSZ51vc88wBqnbQguw/exec`

## Accès
Le compte noreply a les rôles « Administrateur Firebase » et « Consommateur Service Usage » sur le projet
(console Google Cloud › IAM). Aucune clé secrète n'est stockée dans le code.

## Mettre à jour le serveur
1. Modifier les fichiers de `server/apps_script/`.
2. Si les pages web ou `firestore.rules` ont changé : `python3 server/build_sites.py` (régénère `Sites.gs`).
3. Dans l'éditeur Apps Script, remplacer `Code.gs` par la concaténation de
   `Code.gs, Admin.gs, Mail.gs, Deploy.gs, Logo.gs, Sites.gs`, enregistrer.
4. **Déployer › Gérer les déploiements › ✏️ › Version : Nouvelle version › Déployer** (l'URL ne change pas).
5. Pour publier les règles Firestore : lancer `deployRules`. Pour publier le site : lancer `deployHosting`.

## Limites gratuites
- 100 e-mails par jour (compte Gmail grand public) : le quota restant s'affiche dans la console.
- Codes valables 15 minutes, 5 essais, 1 envoi toutes les 45 s et 6 par heure par adresse.
