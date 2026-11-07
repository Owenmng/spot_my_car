import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Une ambiance d'interface : fond, surfaces, encre.
class AppPalette {
  final String id;
  final String name;
  final Brightness brightness;
  final Color paper, paperDeep, card, panel, panelHi, ink, inkSoft, inkMuted, line;

  const AppPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.paper,
    required this.paperDeep,
    required this.card,
    required this.panel,
    required this.panelHi,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.line,
  });

  bool get isDark => brightness == Brightness.dark;
}

const List<AppPalette> palettes = [
  AppPalette(
    id: 'carbone',
    name: 'Carbone',
    brightness: Brightness.dark,
    paper: Color(0xFF0A0A0D),
    paperDeep: Color(0xFF1E1E24),
    card: Color(0xFF141418),
    panel: Color(0xFF18181D),
    panelHi: Color(0xFF222229),
    ink: Color(0xFFF4F4F6),
    inkSoft: Color(0xFFA9A9B2),
    inkMuted: Color(0xFF6E6E78),
    line: Color(0xFF26262D),
  ),
  AppPalette(
    id: 'minuit',
    name: 'Bleu nuit',
    brightness: Brightness.dark,
    paper: Color(0xFF070B14),
    paperDeep: Color(0xFF1A2132),
    card: Color(0xFF0F1522),
    panel: Color(0xFF131A29),
    panelHi: Color(0xFF1C2436),
    ink: Color(0xFFF1F4FA),
    inkSoft: Color(0xFFA3ACBF),
    inkMuted: Color(0xFF6B7489),
    line: Color(0xFF222B3D),
  ),
  AppPalette(
    id: 'graphite',
    name: 'Graphite',
    brightness: Brightness.dark,
    paper: Color(0xFF17171A),
    paperDeep: Color(0xFF2E2E34),
    card: Color(0xFF212125),
    panel: Color(0xFF26262B),
    panelHi: Color(0xFF303036),
    ink: Color(0xFFF5F5F7),
    inkSoft: Color(0xFFB0B0B8),
    inkMuted: Color(0xFF7A7A84),
    line: Color(0xFF34343B),
  ),
  AppPalette(
    id: 'clair',
    name: 'Clair',
    brightness: Brightness.light,
    paper: Color(0xFFF3F3F6),
    paperDeep: Color(0xFFE3E3E9),
    card: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    panelHi: Color(0xFFEBEBF0),
    ink: Color(0xFF121216),
    inkSoft: Color(0xFF5A5A66),
    inkMuted: Color(0xFF8D8D98),
    line: Color(0xFFE0E0E7),
  ),
];

/// Couleurs de l'appli : elles suivent l'ambiance choisie dans « Apparence ».
class AppColors {
  AppColors._();

  static AppPalette current = palettes.first;

  /// Fond de l'appli.
  static Color get paper => current.paper;
  /// Remplissage discret (pistes de jauges, champs inactifs).
  static Color get paperDeep => current.paperDeep;
  /// Surface des cartes.
  static Color get card => current.card;
  /// Panneaux mis en avant (en-têtes, barre de navigation).
  static Color get panel => current.panel;
  static Color get panelHi => current.panelHi;
  /// Texte principal.
  static Color get ink => current.ink;
  static Color get inkSoft => current.inkSoft;
  static Color get inkMuted => current.inkMuted;
  static Color get line => current.line;
  static bool get isDark => current.isDark;

  static const plateInk = Color(0xFF111111);
  static const success = Color(0xFF34C77B);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFFF5A4E);

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
  AccentChoice('Rosso corsa', Color(0xFFE5202E)),
  AccentChoice('Bleu de France', Color(0xFF2F6BFF)),
  AccentChoice('Vert British', Color(0xFF1FA463)),
  AccentChoice('Rose Mulliner', Color(0xFFFF4F9A)),
  AccentChoice('Argent Silberpfeil', Color(0xFFB8C2CC)),
  AccentChoice('Orange papaye', Color(0xFFFF7A1A)),
  AccentChoice('Bleu Gulf', Color(0xFF59B3E8)),
  AccentChoice('Vert Lime', Color(0xFFB4F000)),
  AccentChoice('Jaune Giallo', Color(0xFFFFC72C)),
  AccentChoice('Violet Viper', Color(0xFF9B6BFF)),
];

class AppText {
  AppText._();

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.barlowCondensed(
        fontSize: size * 1.12,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        height: 1.0,
        letterSpacing: 0.2,
      );

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, height: 1.35);

  static TextStyle label(double size, {Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.inkSoft,
        letterSpacing: 0.6,
      );

  static TextStyle mono(double size, {Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: FontWeight.w700, color: color ?? AppColors.ink);
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

ThemeData buildAppTheme(Color accent, [AppPalette? palette]) {
  if (palette != null) AppColors.current = palette;
  final dark = AppColors.isDark;
  final onAccent = accent.computeLuminance() > 0.5 ? const Color(0xFF0A0A0D) : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: accent,
    onPrimary: onAccent,
    secondary: AppColors.ink,
    onSecondary: AppColors.paper,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    surfaceContainerLowest: AppColors.paper,
    surfaceContainerLow: AppColors.card,
    surfaceContainer: AppColors.panel,
    surfaceContainerHigh: AppColors.panelHi,
    surfaceContainerHighest: AppColors.paperDeep,
    error: AppColors.danger,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: dark ? Brightness.dark : Brightness.light,
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
      systemOverlayStyle: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.paper,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
    ),
    iconTheme: IconThemeData(color: AppColors.ink),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.panelHi),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.inkMuted,
      indicatorColor: accent,
      dividerColor: Colors.transparent,
      labelStyle: AppText.body(14, weight: FontWeight.w800),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : AppColors.inkSoft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : AppColors.paperDeep),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 24, thickness: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      prefixIconColor: AppColors.inkSoft,
      suffixIconColor: AppColors.inkSoft,
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
        foregroundColor: onAccent,
        disabledBackgroundColor: AppColors.panelHi,
        disabledForegroundColor: AppColors.inkMuted,
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
        foregroundColor: AppColors.paper,
        minimumSize: const Size(64, 54),
        textStyle: AppText.body(16, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: AppColors.line, width: 1.4),
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
      side: BorderSide(color: AppColors.line),
      labelStyle: AppText.body(13, weight: FontWeight.w600),
      secondaryLabelStyle: AppText.body(13, color: AppColors.paper, weight: FontWeight.w700),
      checkmarkColor: AppColors.paper,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panelHi,
      contentTextStyle: AppText.body(14, color: AppColors.ink, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panel,
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
      foregroundColor: onAccent,
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
        selectedForegroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        side: BorderSide(color: AppColors.line),
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
