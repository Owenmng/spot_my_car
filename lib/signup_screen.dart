// Fichier: lib/signup_screen.dart (Version Finale avec Marque Préférée)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/hover_text.dart';
import 'dart:math';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
  }
  
    Future<String> _createUniqueFriendId(User user) async {
    final db = FirebaseFirestore.instance;
    // On prend le début de l'email comme base pour le nom
    String friendId = "";
    bool isUnique = false;
    int attempts = 0;

    while (!isUnique && attempts < 10) {
      // Génère un nombre entre 10 000 000 et 99 999 999
      final randomNumber = (10000000 + Random().nextInt(90000000)).toString();
      final potentialId = randomNumber;
      
      // La vérification d'unicité ne change pas
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

  Future<void> signUp() async {
    if (!mounted || !_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; });

    try {
      // Étape 1 : Création de l'utilisateur dans Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());
      
      final user = userCredential.user;
      if (user == null) {
        // Si l'utilisateur est null, on arrête
        throw Exception("La création de l'utilisateur a échoué.");
      }

      // Étape 2 : Création de l'ID Ami unique
      final String friendId = await _createUniqueFriendId(user);

      // Étape 3 : Création du document utilisateur complet dans Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        // Infos d'authentification
        'email': user.email,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        
        // Champs pour le profil à compléter
        'photoUrl': null, // L'utilisateur le choisira plus tard
        'profileCompleted': false, // Force la redirection vers ProfileSetupScreen
        'firstName': null,
        'lastName': null,
        'pseudo': null, // On initialise le pseudo à null
        'dateOfBirth': null,        
        // Nouveaux champs pour la partie sociale et le jeu
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
      });

      // Étape 4 : Navigation
      // L'AuthGate s'occupera de la redirection, donc on peut simplement pop.
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Une erreur est survenue.";
      if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop faible.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Un compte existe déjà pour cet email.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } catch (e) {
      // Catcher les autres erreurs potentielles
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Une erreur inattendue est survenue: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form( // On enveloppe la Column dans un Form
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 35),
                      Image.asset('assets/logo.png', height: 135),
                      const SizedBox(height: 10),
                      const Text('Créer un compte',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      const Text('Rejoins la communauté en quelques secondes !',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 40),

                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _isPasswordObscured,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe (6+ caractères)', filled: true, fillColor: Colors.grey[100],
                          suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() { _isPasswordObscured = !_isPasswordObscured; })),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (value) => (value?.length ?? 0) < 6 ? 'Le mot de passe doit faire au moins 6 caractères' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        obscureText: _isConfirmPasswordObscured,
                        onFieldSubmitted: (_) => signUp(),
                        decoration: InputDecoration(
                          labelText: 'Confirmer le mot de passe', filled: true, fillColor: Colors.grey[100],
                          suffixIcon: IconButton(icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() { _isConfirmPasswordObscured = !_isConfirmPasswordObscured; })),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (value) => value != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      
                      const SizedBox(height: 30),
                      _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: signUp,
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text("S'inscrire", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                      const SizedBox(height: 40),
                      Center(
                        child: HoverUnderlineText(
                          text: "Déjà un compte ? Se connecter",
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}