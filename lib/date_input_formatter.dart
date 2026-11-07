// Fichier: lib/date_input_formatter.dart (Version Finale Corrigée)

import 'package:flutter/services.dart';

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String oldText = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newText.length > 8) {
      newText = newText.substring(0, 8);
    }
    
    // Si l'utilisateur efface, on laisse faire et on reformate à la fin
    if (newText.length < oldText.length) {
       // Pas de validation sur la suppression pour rester simple
    } else {
      // --- VALIDATION EN TEMPS RÉEL DE L'AJOUT ---
      if (newText.isNotEmpty) {
        if (int.parse(newText[0]) > 3) { newText = oldText; }
      }
      if (newText.length >= 2) {
        final day = int.parse(newText.substring(0, 2));
        if (day == 0 || day > 31) { newText = oldText; }
      }
      if (newText.length >= 3) {
        if (int.parse(newText[2]) > 1) { newText = oldText; }
      }
      if (newText.length >= 4) {
        final month = int.parse(newText.substring(2, 4));
        if (month == 0 || month > 12) { newText = oldText; }
      }

      // ==========================================================
      // === NOUVELLE LOGIQUE POUR L'ANNÉE (19xx ou 20xx) =========
      // ==========================================================
      if (newText.length >= 5) {
        // Le premier chiffre de l'année doit être '1' ou '2'.
        if (newText[4] != '1' && newText[4] != '2') {
          newText = oldText;
        }
      }
      if (newText.length >= 6) {
        // Si le premier chiffre est '1', le deuxième doit être '9'.
        if (newText[4] == '1' && newText[5] != '9') {
          newText = oldText;
        }
        // Si le premier chiffre est '2', le deuxième doit être '0'.
        if (newText[4] == '2' && newText[5] != '0') {
          newText = oldText;
        }
      }
      // ==========================================================
    }

    String formattedText = '';
    if (newText.length > 4) {
      formattedText = '${newText.substring(0, 2)}/${newText.substring(2, 4)}/${newText.substring(4)}';
    } else if (newText.length > 2) {
      formattedText = '${newText.substring(0, 2)}/${newText.substring(2)}';
    } else {
      formattedText = newText;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}