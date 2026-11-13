import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:spot_my_car/forgot_password_screen.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/screens/delete_account_screen.dart';
import 'package:spot_my_car/screens/music_screen.dart';
import 'package:spot_my_car/screens/plate_lookup_screen.dart';
import 'package:spot_my_car/screens/system_screens.dart';
import 'package:spot_my_car/screens/tutorial_screen.dart';
import 'package:spot_my_car/screens/verify_email_screen.dart';
import 'package:spot_my_car/services/rate_service.dart';

/// Version web uniquement : affiche un écran isolé (?demo=...) pour les captures de contrôle.
Widget demoScreen(String name, ThemeData theme) {
  Widget body;
  switch (name) {
    case 'verify':
      body = const VerifyEmailScreen();
      break;
    case 'forgot':
      body = const ForgotPasswordScreen(initialEmail: 'max@exemple.fr');
      break;
    case 'delete':
      body = const DeleteAccountScreen();
      break;
    case 'plate':
      body = const PlateLookupScreen(initialPlate: 'GB-532-FR');
      break;
    case 'plate_fni':
      body = const PlateLookupScreen(initialPlate: '4521 KL 75');
      break;
    case 'music':
      body = const MusicScreen();
      break;
    case 'maintenance':
      body = const MaintenanceScreen();
      break;
    case 'rate':
      body = Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => RateService.debugShow(context));
        return const Scaffold();
      });
      break;
    default:
      body = TutorialScreen(pseudo: 'Max', debugPage: int.tryParse(name.replaceAll('tuto', '')) ?? 0);
  }
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: I18n.instance.locale,
    supportedLocales: I18n.instance.supportedLocales,
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: body,
  );
}
