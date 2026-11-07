// Fichier: lib/auth_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/login_screen.dart';
import 'package:spot_my_car/profile_setup_screen.dart';
import 'package:spot_my_car/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        
        // Si l'utilisateur n'est pas connecté -> OK, on ne touche pas
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // L'utilisateur est connecté. On surveille son document en temps réel.
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).snapshots(),
          builder: (context, userDocSnapshot) {
            
            // Pendant qu'on attend la première donnée du stream -> OK, on ne touche pas
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Si on a une erreur -> OK, on ne touche pas
            if (userDocSnapshot.hasError) {
              return const Scaffold(body: Center(child: Text("Erreur de connexion.")));
            }

            // Si le document n'existe pas ou si le profil n'est pas complet -> OK, on ne touche pas
            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists || userDocSnapshot.data!.get('profileCompleted') != true) {
              return const ProfileSetupScreen();
            }
            
            // ==========================================================
            // 2. MODIFICATION CLÉ
            // Le profil est complet, au lieu d'aller directement au garage,
            // on passe par notre écran de chargement de données.
            // ==========================================================
            return const HomeScreen();
          },
        );
      },
    );
  }
}