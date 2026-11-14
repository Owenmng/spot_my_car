import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/spotted_car_detail_screen.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class SpotPoint {
  final String id;
  final LatLng point;
  final Map<String, dynamic> car;
  final Rarity rarity;
  SpotPoint({required this.id, required this.point, required this.car, required this.rarity});
}

/// Carte de chasse : chaque spot est une épingle couleur rareté.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final _map = MapController();
  static const _france = LatLng(46.603354, 1.888334);
  Rarity _minRarity = Rarity.commune;
  bool _fitted = false;
  bool _hideEmpty = false;
  LatLng? _me;
  double _accuracy = 0;
  bool _locating = false;
  bool _retryOnResume = false;
  StreamSubscription<Position>? _follow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _follow?.cancel();
    _map.dispose();
    super.dispose();
  }

  // Retour des réglages Android : on relance la localisation tout seul.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryOnResume) {
      _retryOnResume = false;
      _locate();
    }
  }

  void _fit(List<SpotPoint> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first.point, 13);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(coordinates: points.map((p) => p.point).toList(), padding: const EdgeInsets.fromLTRB(50, 140, 50, 120), maxZoom: 14));
  }

  Future<void> _locate() async {
    if (_locating) return;
    HapticFeedback.selectionClick();
    // Déjà localisé : on recentre simplement.
    if (_me != null && _follow != null) {
      _map.move(_me!, _map.camera.zoom < 15 ? 15 : _map.camera.zoom);
      return;
    }
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) await _askToEnable(serviceOff: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) await _askToEnable(serviceOff: false);
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) showAppSnack(context, tr('Sans autorisation, impossible de te placer sur la carte.'), icon: Icons.location_off_outlined);
        return;
      }
      // Position rapide d'abord (dernière connue), puis précise.
      final last = await Geolocator.getLastKnownPosition().catchError((_) => null);
      if (last != null) _setMe(last, move: true);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      _setMe(pos, move: last == null);
      if (last != null) _map.move(_me!, 15);
      _follow ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 8),
      ).listen((p) => _setMe(p), onError: (_) {});
    } on TimeoutException {
      if (mounted && _me == null) showAppSnack(context, tr('Signal GPS trop faible. Réessaie à l\'extérieur.'), icon: Icons.gps_off_rounded);
    } catch (_) {
      if (mounted && _me == null) showAppSnack(context, tr('Position indisponible.'), icon: Icons.location_off_outlined);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setMe(Position p, {bool move = false}) {
    if (!mounted) return;
    setState(() {
      _me = LatLng(p.latitude, p.longitude);
      _accuracy = p.accuracy;
      _hideEmpty = true;
    });
    if (move) _map.move(_me!, 15);
  }

  Future<void> _askToEnable({required bool serviceOff}) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFF4DA3FF).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.location_searching_rounded, color: Color(0xFF4DA3FF), size: 32),
              ),
              const SizedBox(height: 14),
              Text(serviceOff ? tr('Active la localisation') : tr('Autorise la localisation'), style: AppText.display(22), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                serviceOff
                    ? tr('La localisation de ton téléphone est coupée. Active-la pour te voir sur la carte de chasse.')
                    : tr('Tu as refusé l\'accès à ta position. Autorise-le dans les réglages de l\'appli pour te voir sur la carte.'),
                textAlign: TextAlign.center,
                style: AppText.body(14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(serviceOff ? tr('Activer la localisation') : tr('Ouvrir les réglages')),
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Plus tard'))),
            ],
          ),
        ),
      ),
    );
    if (go != true) return;
    _retryOnResume = true;
    if (serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  void _open(SpotPoint s) {
    AudioService.instance.playSfx(SoundEffect.clicLeger);
    HapticFeedback.selectionClick();
    _map.move(s.point, _map.camera.zoom < 12 ? 12 : _map.camera.zoom);
    showModalBottomSheet(context: context, builder: (_) => _SpotSheet(spot: s));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final accent = Theme.of(context).colorScheme.primary;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(tr('Carte de chasse')),
        backgroundColor: AppColors.paper.withValues(alpha: 0.85),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('spotted_cars').where('userId', isEqualTo: user.uid).snapshots(),
        builder: (context, snap) {
          final all = <SpotPoint>[];
          for (final d in snap.data?.docs ?? const []) {
            final c = d.data()['locationCoords'];
            if (c is GeoPoint) all.add(SpotPoint(id: d.id, point: LatLng(c.latitude, c.longitude), car: d.data(), rarity: rarityOfSpot(d.data())));
          }
          final points = all.where((p) => p.rarity.index >= _minRarity.index).toList();
          if (!_fitted && all.isNotEmpty) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
          }
          final cities = all.map((p) => p.car['locationName']).whereType<String>().toSet().length;

          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _france,
                  initialZoom: 5.2,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, _) {
                    if (!_hideEmpty) setState(() => _hideEmpty = true);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.owenmengual.spotmycar',
                    tileBuilder: darkModeTileBuilder,
                  ),
                  if (_me != null && _accuracy > 0)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _me!,
                        radius: _accuracy.clamp(8, 400).toDouble(),
                        useRadiusInMeter: true,
                        color: const Color(0x334DA3FF),
                        borderColor: const Color(0x884DA3FF),
                        borderStrokeWidth: 1,
                      ),
                    ]),
                  if (_me != null)
                    MarkerLayer(markers: [
                      Marker(point: _me!, width: 64, height: 64, child: const _MeDot()),
                    ]),
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 48,
                      size: const Size(46, 46),
                      padding: const EdgeInsets.all(60),
                      markers: [
                        for (final p in points)
                          Marker(
                            key: ValueKey(p.id),
                            point: p.point,
                            width: 40,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: GestureDetector(onTap: () => _open(p), child: _Pin(spot: p)),
                          ),
                      ],
                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.card,
                            border: Border.all(color: accent, width: 2.5),
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12)],
                          ),
                          alignment: Alignment.center,
                          child: Text('${markers.length}', style: AppText.mono(15)),
                        );
                      },
                    ),
                  ),
                  SimpleAttributionWidget(source: Text(tr('OpenStreetMap')), backgroundColor: Color(0xAA000000)),
                ],
              ),
              // Filtres de rareté + compteur
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.paddingOf(context).top + 6,
                child: Column(
                  children: [
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final r in [Rarity.commune, Rarity.peuCommune, Rarity.rare, Rarity.epique, Rarity.legendaire])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(r == Rarity.commune ? tr('Tous les spots') : '${r.label} +'),
                                selected: _minRarity == r,
                                avatar: r == Rarity.commune ? null : CircleAvatar(backgroundColor: r.color, radius: 5),
                                onSelected: (_) => setState(() => _minRarity = r),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (all.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            tr('{0} spot{1} · {2} ville{3}', [points.length, points.length > 1 ? 's' : '', cities, cities > 1 ? 's' : '']),
                            style: AppText.body(12.5, color: Colors.white, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (snap.hasData && all.isEmpty && !_hideEmpty)
                Center(
                  child: GestureDetector(
                  onTap: () => setState(() => _hideEmpty = true),
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.card.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.travel_explore_rounded, size: 40, color: accent),
                        const SizedBox(height: 10),
                        Text(tr('Ta carte est vierge'), style: AppText.display(22)),
                        const SizedBox(height: 6),
                        Text(tr('Ajoute une ville ou ta position quand tu enregistres un spot : il apparaîtra ici.'), textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.inkSoft)),
                        const SizedBox(height: 12),
                        Text(tr('Touche pour fermer'), style: AppText.label(11, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                  ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.96, 0.96)),
                ),
              Positioned(
                right: 16,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: Column(
                  children: [
                    _MapButton(
                      icon: _me != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                      tooltip: tr('Ma position'),
                      onTap: _locate,
                      busy: _locating,
                      active: _me != null,
                    ),
                    const SizedBox(height: 10),
                    _MapButton(icon: Icons.fit_screen_rounded, tooltip: tr('Tout voir'), onTap: () => _fit(points)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;
  final bool active;
  const _MapButton({required this.icon, required this.tooltip, required this.onTap, this.busy = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
          ),
          child: busy
              ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF4DA3FF)))
              : Icon(icon, color: active ? const Color(0xFF4DA3FF) : AppColors.ink),
        ),
      ),
    );
  }
}

/// Point bleu « vous êtes ici » avec une onde qui pulse.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF4DA3FF);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x554DA3FF)))
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 1800.ms, curve: Curves.easeOut)
            .fadeOut(duration: 1800.ms, curve: Curves.easeIn),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x884DA3FF), blurRadius: 10, spreadRadius: 2)],
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final SpotPoint spot;
  const _Pin({required this.spot});

  @override
  Widget build(BuildContext context) {
    final brand = DataManager.instance.brands.whereType<Map>().where((b) => b['id'] == spot.car['brandId']);
    final logo = brand.isEmpty ? null : brand.first['logoUrl'] as String?;
    final c = spot.rarity.color;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 3),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: spot.rarity.index >= 3 ? 14 : 6)],
          ),
          child: logo != null
              ? BrandLogo(url: logo, name: '${spot.car['brandName'] ?? '?'}', size: 22)
              : Center(child: Text('${spot.car['brandName'] ?? '?'}'.characters.first, style: AppText.display(15, color: Colors.black))),
        ),
        CustomPaint(size: const Size(10, 8), painter: _TipPainter(c)),
      ],
    );
  }
}

class _TipPainter extends CustomPainter {
  final Color color;
  _TipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TipPainter old) => old.color != color;
}

class _SpotSheet extends StatelessWidget {
  final SpotPoint spot;
  const _SpotSheet({required this.spot});

  @override
  Widget build(BuildContext context) {
    final car = spot.car;
    final t = (car['spottedAt'] as Timestamp?)?.toDate();
    final model = cleanModelName(car['modelName'] as String?);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SpotImage(carId: spot.id, car: car),
                    Positioned(top: 10, left: 10, child: RarityBadge(rarity: spot.rarity, compact: true)),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 200.ms),
            const SizedBox(height: 14),
            Text(brandHeader(car['brandName'] as String?, car['modelName'] as String?).toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
            Text(model.isEmpty ? '—' : model, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(26)),
            const SizedBox(height: 10),
            Row(
              children: [
                PlateBadge(plate: '${car['plate'] ?? ''}', countryCode: car['plateCountryCode'] as String?, scale: 0.7),
                const Spacer(),
                if (car['xp'] is num && (car['xp'] as num) > 0) Text(tr('+{0} XP', [car['xp']]), style: AppText.mono(13, color: spot.rarity.color)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 6),
                Expanded(child: Text('${car['locationName'] ?? 'Lieu inconnu'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13.5, color: AppColors.inkSoft))),
                if (t != null) ...[
                  Icon(Icons.event_outlined, size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(DateFormat('d MMM yyyy', I18n.instance.dateLocale).format(t), style: AppText.body(13.5, color: AppColors.inkSoft)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SpottedCarDetailScreen(carId: spot.id, carData: car)));
              },
              child: Text(tr('Voir la fiche')),
            ),
          ],
        ),
      ),
    );
  }
}
