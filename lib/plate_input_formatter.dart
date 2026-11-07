// Fichier: lib/plate_input_formatter.dart (Version FINALE, Robuste et Testée)
import 'package:flutter/services.dart';

class PlateInputFormatter extends TextInputFormatter {
  final String mask;

  PlateInputFormatter({required this.mask});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si l'utilisateur efface tout, on le laisse faire.
    if (newValue.text.isEmpty) {
      return const TextEditingValue();
    }

    // On nettoie le texte entré pour ne garder que les lettres et les chiffres.
    final newUnformatted = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    
    // Si après nettoyage il ne reste rien, on vide le champ.
    if (newUnformatted.isEmpty) {
      return const TextEditingValue();
    }

    final newFormatted = StringBuffer();
    int unformattedIndex = 0;
    int maskIndex = 0;

    // On parcourt le masque et le texte de l'utilisateur en même temps.
    while (unformattedIndex < newUnformatted.length && maskIndex < mask.length) {
      final maskCharacter = mask[maskIndex];
      final inputCharacter = newUnformatted[unformattedIndex];

      // Cas 1 : Le caractère du masque est un séparateur (espace ou tiret).
      if (maskCharacter == ' ' || maskCharacter == '-') {
        // On l'ajoute à notre résultat et on avance dans le masque.
        newFormatted.write(maskCharacter);
        maskIndex++;
        continue; // On passe à la prochaine itération.
      }
      
      // Cas 2 : Le caractère du masque attend une LETTRE ('A').
      if (maskCharacter == 'A' && RegExp(r'[a-zA-Z]').hasMatch(inputCharacter)) {
        newFormatted.write(inputCharacter.toUpperCase());
        unformattedIndex++;
      } 
      // Cas 3 : Le caractère du masque attend un CHIFFRE ('#').
      else if (maskCharacter == '#' && RegExp(r'[0-9]').hasMatch(inputCharacter)) {
        newFormatted.write(inputCharacter);
        unformattedIndex++;
      } 
      // Si l'utilisateur tape un caractère non autorisé (ex: un chiffre pour 'A'), on arrête.
      else {
        break;
      }
      
      maskIndex++;
    }

    // On retourne le texte formaté avec le curseur à la fin.
    String result = newFormatted.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}