import 'package:spot_my_car/l10n/i18n.dart';

/// Ce qu'on peut déduire d'une plaque, sans aucune base payante :
/// pays, format, période d'immatriculation estimée, département ou région.
class PlateInsight {
  final String country; // code ISO
  final String flag;
  final String format;
  final int? yearFrom;
  final int? yearTo;
  final String? dateLabel;
  final String? region;
  final List<String> notes;
  final bool recognized;

  const PlateInsight({
    required this.country,
    required this.flag,
    required this.format,
    this.yearFrom,
    this.yearTo,
    this.dateLabel,
    this.region,
    this.notes = const [],
    this.recognized = true,
  });

  /// Année la plus probable de mise en circulation (pour filtrer les modèles).
  int? get year => yearFrom == null ? null : ((yearFrom! + (yearTo ?? yearFrom!)) / 2).round();
}

class PlateAnalyzer {
  PlateAnalyzer._();

  static String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Lettres du SIV français (I, O et U ne sont pas utilisés).
  static const _siv = 'ABCDEFGHJKLMNPQRSTVWXYZ';

  /// Points de repère des séries SIV (début de série → date d'apparition), sources publiques.
  static const _sivMarks = <String, (int, int)>{
    'AA': (2009, 4),
    'AD': (2009, 9),
    'BA': (2010, 9),
    'BV': (2011, 9),
    'CL': (2012, 9),
    'CY': (2013, 9),
    'DK': (2014, 9),
    'DW': (2015, 9),
    'EF': (2017, 9),
    'FA': (2018, 9),
    'FK': (2019, 9),
    'FS': (2020, 9),
    'GB': (2021, 8),
    'GJ': (2022, 9),
    'GR': (2023, 9),
    'GZ': (2024, 9),
    'HF': (2025, 9),
  };

  static int? _sivIndex(String two) {
    final a = _siv.indexOf(two[0]), b = _siv.indexOf(two[1]);
    if (a < 0 || b < 0) return null;
    return a * _siv.length + b;
  }

  /// Date estimée (en mois depuis l'an 0) d'une série SIV.
  static double? _sivMonths(String two) {
    final idx = _sivIndex(two);
    if (idx == null) return null;
    final pts = _sivMarks.entries.map((e) => (_sivIndex(e.key)!, e.value.$1 * 12.0 + e.value.$2 - 1)).toList()..sort((x, y) => x.$1.compareTo(y.$1));
    if (idx <= pts.first.$1) return pts.first.$2;
    for (var i = 0; i < pts.length - 1; i++) {
      final (i0, m0) = pts[i];
      final (i1, m1) = pts[i + 1];
      if (idx <= i1) return m0 + (m1 - m0) * (idx - i0) / (i1 - i0);
    }
    // Au-delà du dernier repère : environ 8 séries par an.
    final (il, ml) = pts.last;
    return ml + (idx - il) * 12 / 8;
  }

  static String _month(double months) {
    final y = months ~/ 12;
    final m = (months - y * 12).floor().clamp(0, 11);
    const names = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${tr(names[m])} $y';
  }

  static PlateInsight analyze(String raw, {String? hintCountry}) {
    final p = clean(raw);
    final now = DateTime.now().year;

    // ── France, SIV : AA-123-AA
    final siv = RegExp(r'^([A-HJ-NP-TV-Z]{2})(\d{3})([A-HJ-NP-TV-Z]{2})$').firstMatch(p);
    if (siv != null && (hintCountry == null || hintCountry == 'FR')) {
      final pre = siv.group(1)!;
      if (pre == 'WW') {
        return PlateInsight(country: 'FR', flag: '🇫🇷', format: tr('France · immatriculation provisoire (WW)'),
            notes: [tr('Plaque temporaire : véhicule en attente de sa carte grise définitive, souvent importé ou tout juste acheté.')]);
      }
      if (pre.startsWith('W')) {
        return PlateInsight(country: 'FR', flag: '🇫🇷', format: tr('France · plaque W garage'),
            notes: [tr('Plaque de professionnel de l\'automobile (essais, convoyage).')]);
      }
      final m = _sivMonths(pre);
      if (m != null) {
        final y = m ~/ 12;
        final yf = y.clamp(2009, now);
        return PlateInsight(
          country: 'FR',
          flag: '🇫🇷',
          format: tr('France · format SIV (depuis 2009)'),
          yearFrom: yf,
          yearTo: (y + 1).clamp(2009, now),
          dateLabel: tr('Immatriculée vers {0}', [_month(m)]),
          notes: [
            tr('Les plaques SIV sont attribuées dans l\'ordre : la série « {0} » est sortie vers {1}.', [pre, _month(m)]),
            tr('Un véhicule importé ou d\'occasion venue de l\'étranger peut être plus ancien que sa plaque.'),
          ],
        );
      }
    }

    // ── France, ancien FNI : 1234 AB 56
    final fni = RegExp(r'^(\d{1,4})([A-Z]{1,3})(\d{2,3}|2A|2B)$').firstMatch(p);
    if (fni != null && (hintCountry == null || hintCountry == 'FR')) {
      final dep = fni.group(3)!;
      final name = _departements[dep];
      if (name != null) {
        return PlateInsight(
          country: 'FR',
          flag: '🇫🇷',
          format: tr('France · ancien format FNI'),
          yearFrom: 1950,
          yearTo: 2009,
          dateLabel: tr('Immatriculée avant avril 2009'),
          region: '$dep · $name',
          notes: [
            tr('Ancien système : le numéro final indique le département d\'immatriculation.'),
            tr('Cette voiture a plus de {0} ans : une youngtimer, voire une collection !', [now - 2009]),
          ],
        );
      }
    }

    // ── Royaume-Uni : AB12 CDE (identifiant d'âge)
    final uk = RegExp(r'^([A-Z]{2})(\d{2})([A-Z]{3})$').firstMatch(p);
    if (uk != null && (hintCountry == null || hintCountry == 'GB')) {
      final n = int.parse(uk.group(2)!);
      int? y;
      String? label;
      if (n >= 2 && n <= 50) {
        y = 2000 + n;
        label = tr('Immatriculée entre mars et août {0}', [y]);
      } else if (n >= 51 && n <= 99) {
        y = 2000 + n - 50;
        label = tr('Immatriculée entre sept. {0} et févr. {1}', [y, y + 1]);
      }
      if (y != null && y <= now + 1) {
        return PlateInsight(country: 'GB', flag: '🇬🇧', format: tr('Royaume-Uni · format depuis 2001'), yearFrom: y, yearTo: y, dateLabel: label,
            notes: [tr('Au Royaume-Uni, les deux chiffres donnent la période d\'immatriculation.')]);
      }
    }

    // ── Autres pays : reconnaissance du format seulement
    final formats = <(RegExp, String, String, String)>[
      (RegExp(r'^\d{4}[B-DF-HJ-NP-TV-Z]{3}$'), 'ES', '🇪🇸', tr('Espagne · format national (depuis 2000)')),
      (RegExp(r'^[A-Z]{2}\d{3}[A-Z]{2}$'), 'IT', '🇮🇹', tr('Italie · format depuis 1994')),
      (RegExp(r'^\d[A-Z]{3}\d{3}$'), 'BE', '🇧🇪', tr('Belgique · format depuis 2010')),
      (RegExp(r'^[A-Z]{1,3}[A-Z]{1,2}\d{1,4}[EH]?$'), 'DE', '🇩🇪', tr('Allemagne (probable)')),
      (RegExp(r'^(AG|AI|AR|BE|BL|BS|FR|GE|GL|GR|JU|LU|NE|NW|OW|SG|SH|SO|SZ|TG|TI|UR|VD|VS|ZG|ZH)\d{1,6}$'), 'CH', '🇨🇭', tr('Suisse')),
      (RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}$'), 'PT', '🇵🇹', tr('Portugal (probable)')),
      (RegExp(r'^\d{2}[A-Z]{2}\d{2}$'), 'PT', '🇵🇹', tr('Portugal (probable)')),
    ];
    for (final (re, cc, flag, label) in formats) {
      if (re.hasMatch(p) && (hintCountry == null || hintCountry == cc)) {
        String? region;
        if (cc == 'CH') region = _cantons[p.substring(0, 2)];
        return PlateInsight(country: cc, flag: flag, format: label, region: region,
            notes: [tr('Pour ce pays, la plaque ne donne pas l\'année : utilise la photo pour identifier le modèle.')]);
      }
    }
    return PlateInsight(country: hintCountry ?? '??', flag: '🏳️', format: tr('Format non reconnu'), recognized: false,
        notes: [tr('Vérifie la saisie, ou prends la voiture en photo : l\'IA lit aussi les plaques.')]);
  }

  static const _cantons = {
    'VD': 'Vaud', 'GE': 'Genève', 'ZH': 'Zurich', 'BE': 'Berne', 'VS': 'Valais', 'FR': 'Fribourg', 'NE': 'Neuchâtel', 'TI': 'Tessin',
    'LU': 'Lucerne', 'BS': 'Bâle-Ville', 'BL': 'Bâle-Campagne', 'SG': 'Saint-Gall', 'AG': 'Argovie', 'JU': 'Jura', 'GR': 'Grisons',
  };

  static const _departements = {
    '01': 'Ain', '02': 'Aisne', '03': 'Allier', '04': 'Alpes-de-Haute-Provence', '05': 'Hautes-Alpes', '06': 'Alpes-Maritimes',
    '07': 'Ardèche', '08': 'Ardennes', '09': 'Ariège', '10': 'Aube', '11': 'Aude', '12': 'Aveyron', '13': 'Bouches-du-Rhône',
    '14': 'Calvados', '15': 'Cantal', '16': 'Charente', '17': 'Charente-Maritime', '18': 'Cher', '19': 'Corrèze', '2A': 'Corse-du-Sud',
    '2B': 'Haute-Corse', '20': 'Corse', '21': 'Côte-d\'Or', '22': 'Côtes-d\'Armor', '23': 'Creuse', '24': 'Dordogne', '25': 'Doubs',
    '26': 'Drôme', '27': 'Eure', '28': 'Eure-et-Loir', '29': 'Finistère', '30': 'Gard', '31': 'Haute-Garonne', '32': 'Gers',
    '33': 'Gironde', '34': 'Hérault', '35': 'Ille-et-Vilaine', '36': 'Indre', '37': 'Indre-et-Loire', '38': 'Isère', '39': 'Jura',
    '40': 'Landes', '41': 'Loir-et-Cher', '42': 'Loire', '43': 'Haute-Loire', '44': 'Loire-Atlantique', '45': 'Loiret', '46': 'Lot',
    '47': 'Lot-et-Garonne', '48': 'Lozère', '49': 'Maine-et-Loire', '50': 'Manche', '51': 'Marne', '52': 'Haute-Marne', '53': 'Mayenne',
    '54': 'Meurthe-et-Moselle', '55': 'Meuse', '56': 'Morbihan', '57': 'Moselle', '58': 'Nièvre', '59': 'Nord', '60': 'Oise',
    '61': 'Orne', '62': 'Pas-de-Calais', '63': 'Puy-de-Dôme', '64': 'Pyrénées-Atlantiques', '65': 'Hautes-Pyrénées',
    '66': 'Pyrénées-Orientales', '67': 'Bas-Rhin', '68': 'Haut-Rhin', '69': 'Rhône', '70': 'Haute-Saône', '71': 'Saône-et-Loire',
    '72': 'Sarthe', '73': 'Savoie', '74': 'Haute-Savoie', '75': 'Paris', '76': 'Seine-Maritime', '77': 'Seine-et-Marne', '78': 'Yvelines',
    '79': 'Deux-Sèvres', '80': 'Somme', '81': 'Tarn', '82': 'Tarn-et-Garonne', '83': 'Var', '84': 'Vaucluse', '85': 'Vendée',
    '86': 'Vienne', '87': 'Haute-Vienne', '88': 'Vosges', '89': 'Yonne', '90': 'Territoire de Belfort', '91': 'Essonne',
    '92': 'Hauts-de-Seine', '93': 'Seine-Saint-Denis', '94': 'Val-de-Marne', '95': 'Val-d\'Oise', '971': 'Guadeloupe',
    '972': 'Martinique', '973': 'Guyane', '974': 'La Réunion', '976': 'Mayotte',
  };
}
