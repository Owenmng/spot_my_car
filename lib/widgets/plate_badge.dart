import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Une vraie plaque d'immatriculation : bande bleue européenne quand le pays s'y prête,
/// fond jaune pour le Royaume-Uni arrière / Luxembourg, fond blanc sinon.
class PlateBadge extends StatelessWidget {
  final String plate;
  final String? countryCode;
  final double scale;

  const PlateBadge({super.key, required this.plate, this.countryCode, this.scale = 1});

  static const _euCountries = {'FR', 'DE', 'IT', 'ES', 'BE', 'LU', 'AT', 'NL', 'PT', 'IE'};

  @override
  Widget build(BuildContext context) {
    final code = (countryCode ?? 'FR').toUpperCase();
    final isEu = _euCountries.contains(code);
    final yellow = code == 'LU' || code == 'NL';
    final h = 34.0 * scale;
    final text = plate.isEmpty ? '—' : plate.toUpperCase();

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: yellow ? AppColors.plateYellow : Colors.white,
        borderRadius: BorderRadius.circular(5 * scale),
        border: Border.all(color: AppColors.plateInk, width: 1.6 * scale),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4 * scale, offset: Offset(0, 2 * scale)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEu)
            Container(
              width: 18 * scale,
              decoration: BoxDecoration(
                color: AppColors.plateBlue,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(3.4 * scale)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.star_rounded, size: 7 * scale, color: AppColors.plateYellow),
                  Text(
                    code == 'DE' ? 'D' : code == 'ES' ? 'E' : code == 'IT' ? 'I' : code == 'AT' ? 'A' : code == 'LU' ? 'L' : code.substring(0, 1),
                    style: GoogleFonts.inter(fontSize: 10 * scale, color: Colors.white, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                  SizedBox(height: 2 * scale),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
            child: Text(
              text,
              maxLines: 1,
              style: GoogleFonts.barlowCondensed(
                fontSize: 21 * scale,
                fontWeight: FontWeight.w600,
                color: AppColors.plateInk,
                letterSpacing: 1.2 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
