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
import 'package:spot_my_car/screens/plus_screen.dart';
import 'package:spot_my_car/screens/referral_screen.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/widgets/daily_chest.dart';
import 'package:spot_my_car/widgets/garage_hero.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/wanted_card.dart';
import 'package:spot_my_car/widgets/weekly_quests_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    case 'chest':
      body = const DailyChestScreen(streak: 4, demo: true);
      break;
    case 'referral':
      body = const ReferralScreen(demoData: {'friendId': '48213957', 'referralCount': 3});
      break;
    case 'plus':
      body = const PlusScreen(demo: true);
      break;
    case 'hero':
      body = Builder(builder: (context) {
        final models = <Map<String, dynamic>>[];
        for (final b in ['porsche', 'bmw', 'peugeot', 'ferrari', 'renault']) {
          final list = DataManager.instance.modelsByBrand[b] ?? const [];
          if (list.isNotEmpty && list.first is Map) {
            models.add({...Map<String, dynamic>.from(list.first as Map), 'brandId': b, 'isCatalogued': true});
          }
        }
        final cars = [
          for (final m in models)
            {...m, 'brandName': '${m['brandId']}'.toUpperCase(), 'modelName': m['name'], 'modelImageUrl': m['imageUrl'], 'rarity': m['brandId'] == 'ferrari' ? 'legendaire' : (m['brandId'] == 'porsche' ? 'epique' : 'commune'), 'spottedAt': Timestamp.now(), 'locationName': m['brandId'] == 'bmw' ? 'Rennes' : 'Paris'},
        ];
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
            children: [
              GarageHero(xp: 2140, cars: cars, streak: 6, rarityOf: rarityOfSpot, onShare: () {}),
              const SizedBox(height: 12),
              const WantedCard(claimed: false),
              const SizedBox(height: 12),
              WeeklyQuestsCard(cars: cars, user: const {}),
              const SizedBox(height: 12),
              const PlusBanner(),
            ],
          ),
        );
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
