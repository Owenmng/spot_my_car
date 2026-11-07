// Fichier: lib/services/audio_service.dart (SOLUTION ROBUSTE DÉFINITIVE - CORRIGÉE POUR SFX)

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect {
  clicPrincipal,
  clicLeger,
  transitionPage,
  succesPrincipal,
  notification,
  levelUp,
  achievement,
  flip,
  shutter,
}

class AudioService with ChangeNotifier, WidgetsBindingObserver {
  // === PLAYERS SÉPARÉS AVEC CONFIGURATION OPTIMISÉE ===
  late final AudioPlayer _musicPlayer;
  // Nous n'avons plus besoin d'un pool de SFX Players pour la gestion actuelle
  // final Map<String, AudioPlayer> _sfxPlayersPool = {}; 
  
  // === ÉTAT ET CONTRÔLES ===
  bool _isMusicEnabled = true;
  bool _isSfxEnabled = true;
  bool _isMusicInitialized = false;
  bool _isMusicReady = false;
  bool _isAppInForeground = true;
  
  // === GESTION DES ERREURS ET RETRY ===
  int _musicRetryCount = 0;
  static const int _maxRetryCount = 3;
  Timer? _retryTimer;
  
  // === GETTERS ===
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  bool get isMusicPlaying => _musicPlayer.state == PlayerState.playing;
  
  // === CONFIGURATION AUDIO OPTIMISÉE ===
  static const String _musicAsset = 'audio/musique_calme.mp3';
  static const double _musicVolume = 0.16;

  AudioService._() {
    _initializeAudioService();
  }
  
  static final AudioService instance = AudioService._();
  
  Future<void> _initializeAudioService() async {
    try {
      // === CONFIGURATION AUDIO CONTEXT POUR ÉVITER LES CONFLITS ===
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck, // ← SOLUTION CLÉE !
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
      
      // === INITIALISATION DU LECTEUR MUSIQUE ===
      _musicPlayer = AudioPlayer();
      await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer); // Mode optimisé pour la musique
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      
      // === LISTENERS POUR LE MONITORING ===
      _musicPlayer.onPlayerStateChanged.listen(_onMusicPlayerStateChanged);
      _musicPlayer.onPlayerComplete.listen(_onMusicPlayerComplete);
      
      // === Pas de pré-initialisation des players SFX dans cette version, ils seront créés à la volée ===
      // await _preloadSfxPlayers(); 
      
      // === CHARGEMENT DES PARAMÈTRES ===
      await _loadSettings();
      
      // === OBSERVER DU CYCLE DE VIE ===
      WidgetsBinding.instance.addObserver(this);
      
      
    } catch (e) {
    }
  }
  
  // === PRÉ-CHARGEMENT DES PLAYERS SFX - Cette méthode n'est plus utilisée pour la nouvelle approche ===
  // Future<void> _preloadSfxPlayers() async {
  //   const sfxSounds = [
  //     'audio/clic_principal.mp3',
  //     'audio/clic_leger.mp3',
  //     'audio/transition_page.mp3',
  //     'audio/succes.mp3',
  //     'audio/notification.mp3',
  //   ];
    
  //   for (String soundPath in sfxSounds) {
  //     try {
  //       final player = AudioPlayer();
  //       await player.setPlayerMode(PlayerMode.lowLatency);
  //       await player.setReleaseMode(ReleaseMode.release);
  //       _sfxPlayersPool[soundPath] = player;
  //     } catch (e) {
  //     }
  //   }
  // }
  
  // === CHARGEMENT DES PARAMÈTRES ===
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
      notifyListeners();
    } catch (e) {
    }
  }
  
  // === LISTENERS POUR LA MUSIQUE ===
  void _onMusicPlayerStateChanged(PlayerState state) {
    
    // Le onPlayerComplete est suffisant pour le relancement
    // if (state == PlayerState.completed && _isMusicEnabled && _isAppInForeground) {
    //   // Relancer automatiquement si la boucle échoue
    //   _retryMusicPlayback();
    // }
  }
  
  void _onMusicPlayerComplete(void _) {
    if (_isMusicEnabled && _isAppInForeground) {
      _retryMusicPlayback();
    }
  }
  
  // === DÉMARRAGE ROBUSTE DE LA MUSIQUE ===
  Future<void> startMusic({bool force = false}) async {
    if (!_isMusicEnabled && !force) {
      return;
    }
    
    if (_isMusicReady && _musicPlayer.state == PlayerState.playing && !force) {
      return;
    }
    
    try {
      
      // === PRÉPARATION DE LA SOURCE AUDIO ===
      Source musicSource;
      
      if (kIsWeb) {
        // Web: utilisation d'UrlSource
        musicSource = UrlSource('assets/$_musicAsset');
      } else {
        // Mobile: copie locale pour garantir la stabilité
        musicSource = await _prepareMobileAudioSource();
      }
      
      // === CONFIGURATION DU LECTEUR ===
      await _musicPlayer.stop(); // Stop propre avant de redémarrer
      await _musicPlayer.setSource(musicSource);
      await _musicPlayer.setVolume(_musicVolume);
      
      // === DÉMARRAGE AVEC VÉRIFICATION ===
      await _musicPlayer.resume();
      
      // Vérification que ça a bien démarré
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_musicPlayer.state == PlayerState.playing) {
        _isMusicReady = true;
        _isMusicInitialized = true;
        _musicRetryCount = 0;
        notifyListeners();
      } else {
        throw Exception("Le lecteur n'est pas en état playing après démarrage");
      }
      
    } catch (e) {
      _retryMusicPlayback();
    }
  }
  
  // === PRÉPARATION SOURCE MOBILE ===
  Future<Source> _prepareMobileAudioSource() async {
    try {
      final dir = await getTemporaryDirectory();
      final musicFile = File('${dir.path}/night_drive_v2.mp3');
      
      // Copier le fichier si nécessaire
      if (!await musicFile.exists()) {
        final byteData = await rootBundle.load('assets/$_musicAsset');
        await musicFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      
      return DeviceFileSource(musicFile.path);
      
    } catch (e) {
      return AssetSource(_musicAsset);
    }
  }
  
  // === SYSTÈME DE RETRY INTELLIGENT ===
  void _retryMusicPlayback() {
    if (_musicRetryCount >= _maxRetryCount || !_isMusicEnabled) {
      return;
    }
    
    _musicRetryCount++;
    _retryTimer?.cancel();
    
    final delay = Duration(seconds: _musicRetryCount * 2); // Délai progressif
    
    _retryTimer = Timer(delay, () {
      startMusic(force: true);
    });
  }
  
  // === ARRÊT DE LA MUSIQUE ===
  Future<void> stopMusic() async {
    try {
      _retryTimer?.cancel();
      await _musicPlayer.stop();
      _isMusicReady = false;
      notifyListeners();
    } catch (e) {
    }
  }
  
  // === PLAY SFX - LOGIQUE MODIFIÉE POUR STABILITÉ ===
  Future<void> playSfx(SoundEffect effect) async {
    if (!_isSfxEnabled) return;
    
    try {
      // 1. On récupère les propriétés (chemin ET volume) du son via notre nouvelle fonction
      final sfx = _getSfxProperties(effect);
      
      final sfxPlayer = AudioPlayer();
      await sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
      await sfxPlayer.setReleaseMode(ReleaseMode.release); 
      
      // 2. On utilise le chemin récupéré
      Source source = kIsWeb ? UrlSource('assets/${sfx.path}') : AssetSource(sfx.path);
      
      // 3. On utilise le volume spécifique au son
      await sfxPlayer.play(source, volume: sfx.volume);
      
      sfxPlayer.onPlayerComplete.listen((_) {
        sfxPlayer.dispose(); 
      });

      _ensureMusicContinues();
      
    } catch (e) {
    }
  }  // === VÉRIFICATION QUE LA MUSIQUE CONTINUE APRÈS SFX ===
  void _ensureMusicContinues() {
    // Vérifier dans 100ms que la musique joue toujours
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isMusicEnabled && 
          _isMusicReady && 
          _musicPlayer.state != PlayerState.playing &&
          _isAppInForeground) {
        _musicPlayer.resume();
      }
    });
  }
  
  // CETTE FONCTION RETOURNE LE CHEMIN ET LE VOLUME POUR CHAQUE SON
  ({String path, double volume}) _getSfxProperties(SoundEffect effect) {
    switch (effect) {
      // ===== CONFIGUREZ VOS VOLUMES ICI (1.0 = maximum) =====
      case SoundEffect.clicPrincipal:
        return (path: 'audio/clic_principal.mp3', volume: 0.45);
        
      case SoundEffect.clicLeger:
        return (path: 'audio/clic_leger.mp3', volume: 0.35);
        
      case SoundEffect.transitionPage:
        return (path: 'audio/transition_page.mp3', volume: 0.4);
        
      case SoundEffect.succesPrincipal:
        return (path: 'audio/succes.mp3', volume: 0.75);
        
      case SoundEffect.notification:
        return (path: 'audio/notification.mp3', volume: 0.6);
      case SoundEffect.levelUp:
        return (path: 'audio/level_up.mp3', volume: 0.8);
      case SoundEffect.achievement:
        return (path: 'audio/succes_debloque.mp3', volume: 0.7);
      case SoundEffect.flip:
        return (path: 'audio/flip.mp3', volume: 0.6);
      case SoundEffect.shutter:
        return (path: 'audio/shutter.mp3', volume: 0.6);
    }
  }
  
  Future<void> toggleMusic(bool isEnabled) async {
    // 1. On met à jour l'état interne
    _isMusicEnabled = isEnabled;

    // 2. ON NOTIFIE L'INTERFACE IMMÉDIATEMENT !
    // L'animation du Switch va donc démarrer tout de suite.
    notifyListeners();

    // 3. On effectue les tâches longues (sauvegarde et gestion audio) en arrière-plan
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', isEnabled);
      
      if (isEnabled) {
        await startMusic(force: true);
      } else {
        await stopMusic();
      }
      
      
    } catch (e) {
    }
  }
  
  Future<void> toggleSfx(bool isEnabled) async {
    _isSfxEnabled = isEnabled;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sfx_enabled', isEnabled);
      notifyListeners();
      
    } catch (e) {
    }
  }
  
  // === GESTION DU CYCLE DE VIE OPTIMISÉE ===
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInForeground = false;
        if (_musicPlayer.state == PlayerState.playing) {
          _musicPlayer.pause();
        }
        break;
        
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_isMusicEnabled && _musicPlayer.state == PlayerState.paused) {
          _musicPlayer.resume();
        } else if (_isMusicEnabled && !_isMusicReady) {
          // Relancer complètement si nécessaire
          startMusic(force: true);
        }
        break;
        
      case AppLifecycleState.detached:
        // App fermée complètement
        stopMusic();
        break;
        
      case AppLifecycleState.hidden:
        // Nouvel état en Flutter 3.13+
        break;
    }
  }
  
  // === NETTOYAGE RESSOURCES ===
  @override
  void dispose() {
    
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    
    // Nettoyage lecteur musique
    _musicPlayer.dispose();
    
    // Le pool SFX n'est plus utilisé de la même manière, donc plus besoin de le vider ici.
    // Les SFX Players sont disposés immédiatement après leur lecture.
    // for (final player in _sfxPlayersPool.values) {
    //   player.dispose();
    // }
    // _sfxPlayersPool.clear();
    
    super.dispose();
  }
  
  // === MÉTHODES DE DEBUG ===
  String getDebugInfo() {
    return '''
AudioService Debug Info:
- Musique activée: $_isMusicEnabled
- SFX activés: $_isSfxEnabled  
- Musique initialisée: $_isMusicInitialized
- Musique prête: $_isMusicReady
- État lecteur: ${_musicPlayer.state}
- App au premier plan: $_isAppInForeground
- Tentatives retry: $_musicRetryCount
- Pool SFX: N/A (créés/disposés à la volée)
''';
  }
}