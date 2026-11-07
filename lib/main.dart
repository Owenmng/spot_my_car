import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/auth_gate.dart';
import 'package:spot_my_car/firebase_options.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/connectivity_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/theme_notifier.dart';
import 'package:spot_my_car/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  FlutterError.onError = (details) {
    if (details.exception.toString().contains('permission-denied')) return;
    FlutterError.presentError(details);
  };

  await initializeDateFormatting('fr_FR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    unawaited(FirebaseAppCheck.instance.activate().catchError((Object e) {
      debugPrint('App Check: $e');
    }));
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    ignoreUndefinedProperties: true,
  );

  final themeNotifier = await ThemeNotifier.create();
  unawaited(DataManager.instance.loadAllData());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider.value(value: DataManager.instance),
        ChangeNotifierProvider.value(value: AudioService.instance),
        ChangeNotifierProvider.value(value: themeNotifier),
      ],
      child: const SpotMyCarApp(),
    ),
  );
}

class SpotMyCarApp extends StatelessWidget {
  const SpotMyCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>().currentThemeData;

    return MaterialApp(
      title: 'SpotMyCar',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const _OfflineBanner(),
        ],
      ),
      home: const AuthGate(),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    final top = MediaQuery.paddingOf(context).top;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      top: online ? -80 : top + 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: AppColors.panelHi,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Hors ligne — tes spots se synchroniseront', style: AppText.body(13, color: Colors.white, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
