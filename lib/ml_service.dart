// Fichier: lib/ml_service.dart (Version Finale avec Cloud Function)

import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

class MLService {
  // On configure la connexion à Firebase Functions, en spécifiant notre région.
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  // La fonction principale qui prend une image et retourne les résultats de l'IA.
  Future<Map<String, dynamic>> analyzeImage(Uint8List imageBytes) async {
    try {
      // Les Cloud Functions ne peuvent pas prendre des bytes directement.
      // On doit les encoder en une chaîne de caractères au format base64.
      String base64Image = base64Encode(imageBytes);

      // On prépare l'appel à notre fonction en ligne.
      // Le nom ici 'analyzeImageForCar' doit correspondre EXACTEMENT au nom dans index.ts.
      final HttpsCallable callable = _functions.httpsCallable('analyzeImageForCar');
      
      print("Appel de la Cloud Function 'analyzeImageForCar'...");

      // On envoie la requête avec l'image encodée.
      final response = await callable.call<Map<String, dynamic>>({
        'image': base64Image,
      });

      print("Réponse de la Cloud Function reçue !");
      
      // La réponse contient directement notre objet { logos: [...], labels: [...] }
      // On le retourne à l'application.
      return response.data;

    } on FirebaseFunctionsException catch (e) {
      // Gère les erreurs spécifiques à Firebase (ex: permission refusée)
      print("Erreur de la Cloud Function: ${e.code} - ${e.message}");
      return {}; // Retourne un résultat vide en cas d'erreur
    } catch (e) {
      // Gère toutes les autres erreurs (ex: pas de connexion internet)
      print("Erreur inattendue lors de l'appel de la fonction: $e");
      return {};
    }
  }

  // Il n'y a plus rien à "fermer" ou "libérer", donc dispose est vide.
  void dispose() {}
}