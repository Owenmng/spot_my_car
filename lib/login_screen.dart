import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spot_my_car/forgot_password_screen.dart';
import 'package:spot_my_car/hover_text.dart';
import 'package:spot_my_car/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // DÉCLARATION DES VARIABLES
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Configuration correcte de GoogleSignIn avec des scopes
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  // Fonction pour se connecter avec Email/Mot de passe (inchangée)
  Future<void> signInWithEmail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Une erreur est survenue.";
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = "Email ou mot de passe incorrect.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fonction pour créer un ID d'ami unique (inchangée)
  Future<String> _createUniqueFriendId(User user) async {
    final db = FirebaseFirestore.instance;
    String friendId = "";
    bool isUnique = false;
    int attempts = 0;
    while (!isUnique && attempts < 10) {
      final randomNumber = (10000000 + Random().nextInt(90000000)).toString();
      final potentialId = randomNumber;
      final userWithSameId = await db
          .collection("users")
          .where("friendId", isEqualTo: potentialId)
          .limit(1)
          .get();
      if (userWithSameId.docs.isEmpty) {
        friendId = potentialId;
        isUnique = true;
      } else {
        attempts++;
      }
    }
    if (!isUnique) {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final randomSuffix = Random().nextInt(100).toString();
      friendId = timestamp + randomSuffix;
    }
    return friendId;
  }

  // >>> FONCTION signInWithGoogle MULTIPLATEFORME CORRIGÉE <<<
  Future<void> signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential? userCredential;
      try {
        await _googleSignIn.signOut();
        await FirebaseAuth.instance.signOut();
      } catch (e) {
      }
        // Détection de la plateforme pour utiliser la bonne méthode de connexion
      if (kIsWeb) {
        // --- LOGIQUE POUR LE WEB ---
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // --- LOGIQUE POUR MOBILE (ANDROID/IOS) CORRIGÉE ---
        try {
          // Déconnexion préalable pour éviter les conflits
          await _googleSignIn.signOut();
          
          // Connexion Google
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            if (mounted) setState(() => _isLoading = false);
            return; // L'utilisateur a annulé la connexion
          }

          // Obtention des tokens d'authentification
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          
          // Vérification que les tokens existent
          if (googleAuth.accessToken == null || googleAuth.idToken == null) {
            throw Exception("Impossible d'obtenir les tokens d'authentification Google");
          }

          // Création des credentials Firebase
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          
          // Connexion à Firebase
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (e) {
          print('Erreur lors de la connexion Google mobile: $e');
          throw e;
        }
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception("Connexion Google échouée, utilisateur non trouvé.");
      }

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        final String friendId = await _createUniqueFriendId(user);
        final displayName = user.displayName ?? '';
        final firstName = displayName.split(" ").isNotEmpty ? displayName.split(" ")[0] : null;
        final lastName = displayName.split(" ").length > 1 ? displayName.split(" ").sublist(1).join(" ") : null;

        await userDocRef.set({
          'email': user.email,
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': user.photoURL,
          'profileCompleted': false,
          'firstName': firstName,
          'lastName': lastName,
          'pseudo': null,
          'dateOfBirth': null,
          'favoriteBrandId': null,
          'friendId': friendId,
          'friendId_lowercase': friendId.toLowerCase(),
          'totalXp': 0,
          'stats': {
            'totalSpots': 0,
            'uniqueBrands': 0,
            'uniqueModels': 0,
            'favoriteBrandName': null,
            'favoriteBrandLogoUrl': null,
          }
        },
        SetOptions(merge: true)); 

      }
    } catch (e) {
      print('Erreur complète Google Sign-In: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Une erreur est survenue lors de la connexion Google: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Widget Build pour l'interface (inchangé)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 35),
                Image.asset('assets/logo.png', height: 135),
                const SizedBox(height: 10),
                const Text('Se Connecter', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('Retrouve ta collection de voitures', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : signInWithGoogle,
                  icon: Image.asset('assets/google_logo.png', height: 18),
                  label: const Text('Continuer avec Google', style: TextStyle(color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300)),
                ),
                const SizedBox(height: 24),
                const Row(children: [
                  Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('OU', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
                  Expanded(child: Divider(color: Colors.grey))
                ]),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _isPasswordObscured,
                  onSubmitted: (_) => signInWithEmail(),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      }),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: HoverUnderlineText(
                        text: 'Mot de passe oublié ?',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())))),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: signInWithEmail,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Connexion', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                const SizedBox(height: 40),
                Center(
                  child: HoverUnderlineText(
                    text: "Pas encore de compte ? S'inscrire",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}