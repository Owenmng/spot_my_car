import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette de base de l'appli : papier chaud, encre profonde, une seule couleur d'accent.
class AppColors {
  AppColors._();

  static const paper = Color(0xFFF6F3EE);
  static const paperDeep = Color(0xFFEDE8E0);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16161A);
  static const inkSoft = Color(0xFF55545C);
  static const inkMuted = Color(0xFF8E8C94);
  static const line = Color(0xFFE2DDD4);

  static const success = Color(0xFF1F9D63);
  static const warning = Color(0xFFE59A1A);
  static const danger = Color(0xFFD9412B);

  static const plateBlue = Color(0xFF0B3EA8);
  static const plateYellow = Color(0xFFFFCC00);
}

/// Accents proposés dans « Apparence ».
class AccentChoice {
  final String name;
  final Color color;
  const AccentChoice(this.name, this.color);
}

const List<AccentChoice> accentChoices = [
  AccentChoice('Orange signal', Color(0xFFFF5A1F)),
  AccentChoice('Bleu piste', Color(0xFF2F5BEA)),
  AccentChoice('Vert anglais', Color(0xFF1E6B4E)),
  AccentChoice('Rosso corsa', Color(0xFFD7262E)),
  AccentChoice('Rose néon', Color(0xFFE5337A)),
  AccentChoice('Carbone', Color(0xFF2A2A30)),
];

class AppText {
  AppText._();

  static TextStyle display(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.archivo(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.05,
        letterSpacing: -0.5,
      );

  static TextStyle body(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: 1.35);

  static TextStyle label(double size, {Color color = AppColors.inkSoft}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.6,
      );

  static TextStyle mono(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: FontWeight.w700, color: color);
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

ThemeData buildAppTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: accent,
    onPrimary: Colors.white,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    surfaceContainerLowest: AppColors.card,
    surfaceContainerLow: AppColors.paper,
    surfaceContainer: AppColors.paperDeep,
    error: AppColors.danger,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.light,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: AppText.display(44),
    displayMedium: AppText.display(36),
    displaySmall: AppText.display(30),
    headlineLarge: AppText.display(28),
    headlineMedium: AppText.display(24),
    headlineSmall: AppText.display(20),
    titleLarge: AppText.display(19, weight: FontWeight.w700),
    titleMedium: AppText.body(16, weight: FontWeight.w700),
    titleSmall: AppText.body(14, weight: FontWeight.w700),
    bodyLarge: AppText.body(16),
    bodyMedium: AppText.body(14),
    bodySmall: AppText.body(12, color: AppColors.inkSoft),
    labelLarge: AppText.body(15, weight: FontWeight.w700),
  );

  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    primaryColor: accent,
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.display(22),
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 24, thickness: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: AppText.body(14, color: AppColors.inkSoft),
      floatingLabelStyle: AppText.body(13, color: accent, weight: FontWeight.w700),
      hintStyle: AppText.body(14, color: AppColors.inkMuted),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(accent, 1.8),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: AppText.body(16, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        textStyle: AppText.body(16, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        textStyle: AppText.body(15, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: AppText.body(15, weight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
      labelStyle: AppText.body(13, weight: FontWeight.w600),
      secondaryLabelStyle: AppText.body(13, color: Colors.white, weight: FontWeight.w700),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.body(14, color: Colors.white, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: AppText.display(22),
      contentTextStyle: AppText.body(15, color: AppColors.inkSoft),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.ink,
      titleTextStyle: AppText.body(15, weight: FontWeight.w700),
      subtitleTextStyle: AppText.body(13, color: AppColors.inkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: AppColors.paperDeep,
      circularTrackColor: AppColors.paperDeep,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.card,
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        textStyle: AppText.body(14, weight: FontWeight.w700),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
