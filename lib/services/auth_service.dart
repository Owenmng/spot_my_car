// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import explicite
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<void> signOut() async {
    try {
      // 1. Fermez d'abord tous les listeners Firestore
      await FirebaseFirestore.instance.disableNetwork();
      
      // 2. Déconnexion Firebase
      await FirebaseAuth.instance.signOut();
      
      // 3. Déconnexion Google (mobile seulement)
      if (!kIsWeb) await _googleSignIn.signOut();
      
      // 4. Réactivez le réseau après un délai
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseFirestore.instance.enableNetwork();
    } catch (e) {
      rethrow;
    }
  }
}