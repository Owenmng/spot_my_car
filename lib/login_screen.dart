import 'package:spot_my_car/l10n/i18n.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spot_my_car/forgot_password_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/signup_screen.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:spot_my_car/widgets/language_picker.dart';

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
      String errorMessage = tr('Une erreur est survenue.');
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = tr('Email ou mot de passe incorrect.');
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
          rethrow;
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
        'emailCodeRequired': true,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('La connexion avec Google n\'a pas abouti ({0}). Réessaie.', [e is PlatformException ? e.code : e.runtimeType])),
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

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final pad = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: LayoutBuilder(
        builder: (context, box) {
          // Tout tient à l'écran : le haut s'adapte à la hauteur disponible,
          // le défilement n'existe que si le clavier est ouvert.
          final compact = box.maxHeight < 720;
          return SingleChildScrollView(
            physics: keyboard ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [const Color(0xFF0A0A0D), Color.lerp(const Color(0xFF0A0A0D), accent, 0.22)!, Color.lerp(const Color(0xFF0A0A0D), accent, 0.6)!],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                          const Positioned.fill(child: _RoadLines()),
                          Padding(
                            padding: EdgeInsets.fromLTRB(24, pad.top + (compact ? 14 : 28), 24, 34),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    AppLogo(size: compact ? 50 : 58).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tr('SPOT MY CAR'), style: AppText.display(compact ? 22 : 25, color: Colors.white)),
                                        Text(tr('LE CARSPOTTING, EN COLLECTION'), style: AppText.label(9.5, color: Colors.white54)),
                                      ],
                                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.08, end: 0),
                                    const Spacer(),
                                    Material(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      shape: const StadiumBorder(),
                                      child: InkWell(
                                        customBorder: const StadiumBorder(),
                                        onTap: () => showLanguageSheet(context),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          child: ListenableBuilder(
                                            listenable: I18n.instance,
                                            builder: (_, _) => Text('${I18n.instance.language.flag} ${I18n.instance.code.toUpperCase()}', style: AppText.body(13, color: Colors.white, weight: FontWeight.w800)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!keyboard) ...[
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tr('Chaque voiture\ncroisée devient\nune carte.'), style: AppText.display(compact ? 30 : 36, color: Colors.white))
                                          .animate().fadeIn(delay: 120.ms, duration: 450.ms).slideY(begin: 0.15, end: 0),
                                      const SizedBox(height: 8),
                                      Text(tr('Photographie, l’IA reconnaît, ta collection grandit.'), style: AppText.body(compact ? 13.5 : 15, color: Colors.white70))
                                          .animate().fadeIn(delay: 260.ms),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(22, compact ? 18 : 24, 22, (compact ? 10 : 18) + pad.bottom),
                      transform: Matrix4.translationValues(0, -20, 0),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl + 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : signInWithGoogle,
                            icon: Image.asset('assets/google_logo.png', height: 20),
                            label: Text(tr('Continuer avec Google')),
                            style: OutlinedButton.styleFrom(backgroundColor: AppColors.card, minimumSize: Size(64, compact ? 50 : 54)),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(tr('ou avec ton e-mail'), style: AppText.body(12.5, color: AppColors.inkMuted, weight: FontWeight.w600)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          TextField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: tr('E-mail'),
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                              isDense: compact,
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _isPasswordObscured,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => signInWithEmail(),
                            decoration: InputDecoration(
                              labelText: tr('Mot de passe'),
                              isDense: compact,
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                              child: Text(tr('Mot de passe oublié ?')),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : signInWithEmail,
                            style: ElevatedButton.styleFrom(minimumSize: Size(64, compact ? 50 : 54)),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                : Text(tr('Se connecter')),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tr('Nouveau ici ?'), style: AppText.body(14, color: AppColors.inkSoft)),
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                                style: TextButton.styleFrom(foregroundColor: accent, visualDensity: VisualDensity.compact),
                                child: Text(tr('Créer un compte')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().slideY(begin: 0.25, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lignes de route en perspective qui défilent doucement derrière le titre.
class _RoadLines extends StatefulWidget {
  const _RoadLines();

  @override
  State<_RoadLines> createState() => _RoadLinesState();
}

class _RoadLinesState extends State<_RoadLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _RoadPainter(_c.value)),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double t;
  _RoadPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vanish = Offset(size.width * 0.78, size.height * 0.18);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 2;
    canvas.drawLine(vanish, Offset(size.width * 0.2, size.height), edge);
    canvas.drawLine(vanish, Offset(size.width * 1.35, size.height), edge);

    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeCap = StrokeCap.round;
    final bottom = Offset(size.width * 0.78, size.height);
    for (var i = 0; i < 7; i++) {
      final p = ((i / 7) + t) % 1.0;
      final a = p * p;
      final b = ((p + 0.06) * (p + 0.06)).clamp(0.0, 1.0);
      dash.strokeWidth = 1 + 6 * a;
      canvas.drawLine(Offset.lerp(vanish, bottom, a)!, Offset.lerp(vanish, bottom, b)!, dash);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.t != t;
}
