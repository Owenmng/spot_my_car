// lib/main.dart (Version avec App Check Debug/Release)

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spot_my_car/services/connectivity_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // On ajoute kDebugMode
import 'package:flutter/services.dart';
import 'package:spot_my_car/services/theme_notifier.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('permission-denied')) {
      return;
    }
    FlutterError.presentError(details);
  };

  await initializeDateFormatting('fr_FR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // =========================================================
  // === BLOC D'ACTIVATION D'APP CHECK (DEBUG + RELEASE) ===
  // =========================================================
  if (!kIsWeb) {
      // Activation simple. Flutter choisira automatiquement le bon fournisseur
      // (Debug en mode debug, Play Integrity en mode release).
      await FirebaseAppCheck.instance.activate();
      print("Firebase App Check activé.");
    }
  // =========================================================

  if (kIsWeb) {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, 
    ignoreUndefinedProperties: true,
  );

  // On crée les instances des services avant de lancer l'application
  final themeNotifier = await ThemeNotifier.create();
  final audioService = AudioService.instance; // Le singleton est déjà prêt

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConnectivityService()),
        
        // On fournit les instances "singleton" déjà créées avec .value
        ChangeNotifierProvider.value(value: DataManager.instance),
        ChangeNotifierProvider.value(value: audioService),
        ChangeNotifierProvider.value(value: themeNotifier),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // ... le reste de ton fichier reste INCHANGÉ
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return Consumer<ConnectivityService>(
          builder: (context, connectivityService, child) {
            return MaterialApp(
              title: 'SpotMyCar',
              debugShowCheckedModeBanner: false,
              
              theme: themeNotifier.currentThemeData, 
              
              home: Stack(
                children: [
                  const AuthGate(),
                  if (!connectivityService.isOnline)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          color: Colors.black.withOpacity(0.8),
                          padding: EdgeInsets.only(
                            top: 8.0,
                            bottom: 8.0 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Mode hors ligne activé',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}