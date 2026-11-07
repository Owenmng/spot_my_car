// Fichier: lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
// On utilise un ChangeNotifier pour que l'UI puisse écouter les changements
class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityService() {
    // On écoute les changements de statut de la connexion dès le démarrage
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results.first);
    });
    // On vérifie aussi l'état initial
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result.first);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasOnline = _isOnline;
    _isOnline = (result != ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      notifyListeners();

      // === DÉBUT DE L'AJOUT ===
      // Si on vient de REPASSER EN LIGNE
      if (_isOnline) {
        print("Connexion rétablie ! Lancement de la synchronisation...");
        // On appelle notre service de synchronisation
      }
      // === FIN DE L'AJOUT ===
    }
  }
}