// Fichier : functions/src/index.ts (Version Complète, Corrigée et Harmonisée)

// Imports V2 pour tes fonctions existantes et la nouvelle
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onRequest, onCall} from "firebase-functions/v2/https"; // onCall ajouté ici
import {setGlobalOptions} from "firebase-functions/v2";

// Imports standards
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import * as vision from "@google-cloud/vision";

// Initialisation (INCHANGÉ)
admin.initializeApp();
const db = admin.firestore();
setGlobalOptions({region: "europe-west1", memory: "256MiB"});

// =================================================================
// FONCTION 1 : Leaderboard (INCHANGÉE)
// =================================================================
const levels = [
  {level: 10, xp: 20000}, {level: 9, xp: 12000}, {level: 8, xp: 7500},
  {level: 7, xp: 4000}, {level: 6, xp: 2000}, {level: 5, xp: 1000},
  {level: 4, xp: 500}, {level: 3, xp: 250}, {level: 2, xp: 100}, {level: 1, xp: 0},
];

function calculateLevel(xp: number): number {
  return levels.find((l) => xp >= l.xp)?.level ?? 1;
}

interface LeaderboardEntry {
  rank: number;
  uid: string;
  pseudo: string | null;
  friendId: string;
  photoUrl: string | null;
  totalXp: number;
  level: number;
  stats: any;
}

export const updateLeaderboardOnUserUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();
  const userId = event.params.userId;

  if (beforeData?.totalXp === afterData?.totalXp) {
    functions.logger.info(`XP inchangé pour ${userId}, pas de mise à jour.`);
    return null;
  }

  functions.logger.info(`Changement d'XP détecté pour ${userId}. Recalcul du classement...`);

  try {
    const usersSnapshot = await db.collection("users").orderBy("totalXp", "desc").get();
    const allUsers = usersSnapshot.docs;
    const batch = db.batch();
    const leaderboardTop100: LeaderboardEntry[] = [];

    for (let i = 0; i < allUsers.length; i++) {
      const userDoc = allUsers[i];
      const userData = userDoc.data();
      const rank = i + 1;

      if (userData.rank !== rank) {
        const userRef = db.collection("users").doc(userDoc.id);
        batch.update(userRef, {rank: rank});
      }

      if (rank <= 100) {
        leaderboardTop100.push({
          rank: rank,
          uid: userDoc.id,
          pseudo: userData.pseudo || null,
          friendId: userData.friendId,
          photoUrl: userData.photoUrl || null,
          totalXp: userData.totalXp,
          level: calculateLevel(userData.totalXp),
          stats: userData.stats || {},
        });
      }
    }

    await batch.commit();
    functions.logger.info(`Mise à jour des rangs terminée pour ${allUsers.length} utilisateurs.`);

    const leaderboardRef = db.collection("leaderboards").doc("top100");
    await leaderboardRef.set({
      entries: leaderboardTop100,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info("Document /leaderboards/top100 mis à jour avec succès.");
  } catch (error) {
    functions.logger.error("Erreur lors de la mise à jour du classement:", error);
  }

  return null;
});

// =================================================================
// FONCTION 2 : Scraper (INCHANGÉE)
// =================================================================
export const getVehicleInfoByScraper = onRequest(
    {
      region: "europe-west1",
      memory: "256MiB",
      cors: true,
    },
    async (request, response) => {
      if (!request.headers.authorization || !request.headers.authorization.startsWith("Bearer ")) {
        functions.logger.error("Unauthorized: No Firebase ID token was passed.");
        response.status(403).send("Unauthorized");
        return;
      }

      const idToken = request.headers.authorization.split("Bearer ")[1];
      try {
        await admin.auth().verifyIdToken(idToken);
      } catch (error) {
        functions.logger.error("Unauthorized: Error verifying ID token:", error);
        response.status(403).send("Unauthorized");
        return;
      }

      const {plate, country} = request.body;
      if (!plate || !country) {
        response.status(400).send({error: "Missing plate or country in request body."});
        return;
      }

      functions.logger.info(`Scraping request received for plate: ${plate} in country: ${country}`);

      try {
        const carInfo = {
          make: "Test Make V2",
          model: "Test Model (CORS OK)",
        };
        response.status(200).send(carInfo);
      } catch (error) {
        functions.logger.error("Error during scraping:", error);
        response.status(500).send({error: "An internal error occurred during scraping."});
      }
    }
);

// =================================================================
// FONCTION 3 : NOTRE NOUVELLE FONCTION D'ANALYSE D'IMAGE (SYNTAXE V2 CORRIGÉE)
// =================================================================
const visionClient = new vision.ImageAnnotatorClient();

export const analyzeImageForCar = onCall({
  region: "europe-west1", // Spécifié ici, comme tes autres fonctions V2
  timeoutSeconds: 120,
  memory: "1GiB",
  cors: true, // Ajout du CORS pour être sûr que ça passe depuis l'app
}, async (request) => {
  // En V2, on récupère 'data' et 'auth' depuis l'objet 'request'
  const {data, auth} = request;

  if (!auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Vous devez être connecté pour analyser une image.",
    );
  }

  if (!data.image) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "L'image est manquante.",
    );
  }

  const imageContent = data.image;

  try {
    functions.logger.info("Analyse de l'image avec l'API Cloud Vision...");

    const visionRequest = {
      image: {
        content: imageContent,
      },
      features: [
        {type: "LOGO_DETECTION", maxResults: 5},
        {type: "LABEL_DETECTION", maxResults: 10},
      ],
    };

    const [result] = await visionClient.annotateImage(visionRequest);

    const logos = result.logoAnnotations || [];
    const labels = result.labelAnnotations || [];

    functions.logger.info("Logos trouvés:", logos.map((logo: any) => logo.description));
    functions.logger.info("Labels trouvés:", labels.map((label: any) => label.description));

    const detectedLogos = logos.map((logo: any) => ({
      name: logo.description,
      score: logo.score,
    }));

    const detectedLabels = labels.map((label: any) => ({
      name: label.description,
      score: label.score,
    }));

    return {
      logos: detectedLogos,
      labels: detectedLabels,
    };
  } catch (error) {
    functions.logger.error("Erreur de l'API Vision:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Une erreur est survenue lors de l'analyse de l'image.",
    );
  }
});
