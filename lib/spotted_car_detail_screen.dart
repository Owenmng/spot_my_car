import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:spot_my_car/services/share_service.dart';
import 'package:spot_my_car/services/vehicle_recognition_service.dart';
import 'package:spot_my_car/shared/app_data.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';
import 'package:spot_my_car/widgets/spot_card.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

class SpottedCarDetailScreen extends StatefulWidget {
  final String carId;
  final Map<String, dynamic> carData;

  const SpottedCarDetailScreen({super.key, required this.carId, required this.carData});

  @override
  State<SpottedCarDetailScreen> createState() => _SpottedCarDetailScreenState();
}

class _SpottedCarDetailScreenState extends State<SpottedCarDetailScreen> {
  bool _showOfficial = false;

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance.collection('spotted_cars').doc(widget.carId);

  Future<void> _delete(Map<String, dynamic> car) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du garage ?'),
        content: const Text('Cette voiture et sa photo seront supprimées définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final url = car['userPhotoUrl'] as String?;
      if (url != null) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
      await _ref.delete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showAppSnack(context, 'La suppression a échoué.', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasData && !(snap.data?.exists ?? false)) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final car = snap.data?.data() ?? widget.carData;
        final rarity = rarityOfSpot(car);
        final brand = (car['brandName'] as String?) ?? 'Marque inconnue';
        final model = cleanModelName(car['modelName'] as String?);
        final userPhoto = car['userPhotoUrl'] as String?;
        final official = car['modelImageUrl'] as String?;
        final hasBoth = userPhoto != null && official != null;
        final date = (car['spottedAt'] as Timestamp?)?.toDate();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _GlassButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                ),
                actions: [
                  _GlassButton(icon: Icons.ios_share_rounded, onTap: () => ShareService.shareSpot(context, car)),
                  const SizedBox(width: 8),
                  _GlassButton(icon: Icons.more_horiz_rounded, onTap: () => _menu(car)),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'carImage_${widget.carId}',
                        child: CarImage(
                          urls: _showOfficial ? [official, userPhoto] : [userPhoto, official],
                          brandName: brand,
                          modelName: model,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.25, 0.7, 1],
                            colors: [Color(0x88000000), Colors.transparent, Colors.transparent, Color(0xAA000000)],
                          ),
                        ),
                      ),
                      if (hasBoth)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.4),
                              foregroundColor: Colors.white,
                              selectedBackgroundColor: Colors.white,
                              selectedForegroundColor: AppColors.ink,
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: const [
                              ButtonSegment(value: false, label: Text('Mon spot')),
                              ButtonSegment(value: true, label: Text('Officielle')),
                            ],
                            selected: {_showOfficial},
                            onSelectionChanged: (s) => setState(() => _showOfficial = s.first),
                          ),
                        ),
                      Positioned(left: 20, bottom: 18, child: RarityBadge(rarity: rarity, onDark: true)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 40 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.toUpperCase(), style: AppText.label(12, color: AppColors.inkMuted)),
                      const SizedBox(height: 4),
                      Text(model, style: AppText.display(32)),
                      if (car['production_years'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Produite ${car['production_years']}'.replaceAll("Aujourd'hui", "aujourd'hui"), style: AppText.body(14, color: AppColors.inkSoft, weight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 16),
                      PlateBadge(plate: (car['plate'] as String?) ?? '', countryCode: car['plateCountryCode'] as String?),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (date != null)
                            _InfoChip(icon: Icons.event_outlined, text: DateFormat("d MMMM yyyy 'à' HH'h'mm", 'fr_FR').format(date)),
                          _InfoChip(icon: Icons.place_outlined, text: (car['locationName'] as String?) ?? 'Lieu inconnu', muted: car['locationName'] == null),
                          _ColorChip(color: car['color'] as String?),
                          if ((car['xp'] as num?) != null && (car['xp'] as num) > 0)
                            _InfoChip(icon: Icons.bolt_rounded, text: '+${car['xp']} XP'),
                        ],
                      ),
                      if ((car['note'] as String?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Text('“${car['note']}”', style: AppText.body(15).copyWith(fontStyle: FontStyle.italic)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _edit(car),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Modifier les infos du spot'),
                        ),
                      ),
                      if (car['isCatalogued'] == true) ...[
                        const SizedBox(height: 18),
                        Text('Fiche technique', style: AppText.display(22)),
                        const SizedBox(height: 14),
                        SpecsGrid(model: car),
                      ],
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _menu(Map<String, dynamic> car) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _edit(car);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _delete(car);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> car) async {
    await AppData.loadWorldCities();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(car: car, docRef: _ref),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;
  const _InfoChip({required this.icon, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, overflow: TextOverflow.ellipsis, style: AppText.body(13.5, weight: FontWeight.w600, color: muted ? AppColors.inkMuted : AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String? color;
  const _ColorChip({required this.color});

  @override
  Widget build(BuildContext context) {
    final swatch = kCarColorSwatches[color];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(color: swatch ?? AppColors.paperDeep, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          ),
          const SizedBox(width: 7),
          Text(color ?? 'Couleur ?', style: AppText.body(13.5, weight: FontWeight.w600, color: color == null ? AppColors.inkMuted : AppColors.ink)),
        ],
      ),
    );
  }
}

/// Fiche technique en tuiles, lisible d'un coup d'œil.
class SpecsGrid extends StatelessWidget {
  final Map<String, dynamic> model;
  const SpecsGrid({super.key, required this.model});

  static String _num(dynamic v) {
    if (v == null) return '';
    if (v is num) return NumberFormat.decimalPattern('fr_FR').format(v);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dims = (model['dimensions_lwh_mm'] as String?)?.split(RegExp(r'\s*x\s*'));
    final specs = <(IconData, String, String)>[
      if (model['puissance_ch'] != null) (Icons.bolt_rounded, 'Puissance', '${_num(model['puissance_ch'])} ch'),
      if (model['zero_a_cent_s'] != null) (Icons.timer_outlined, '0 à 100 km/h', '${_num(model['zero_a_cent_s'])} s'),
      if (model['vitesse_max_kmh'] != null) (Icons.speed_rounded, 'Vitesse max', '${_num(model['vitesse_max_kmh'])} km/h'),
      if (model['poids_kg'] != null) (Icons.scale_outlined, 'Poids', '${_num(model['poids_kg'])} kg'),
      if (model['type_carburant'] != null) (Icons.local_gas_station_outlined, 'Énergie', '${model['type_carburant']}'),
      if (model['consommation_mixte'] != null) (Icons.water_drop_outlined, 'Consommation', '${model['consommation_mixte']}'),
      if (model['prix_lancement_eur'] != null) (Icons.euro_rounded, 'Prix de lancement', '${_num(model['prix_lancement_eur'])} €'),
      if (dims != null && dims.length == 3) (Icons.straighten_rounded, 'L × l × h', '${_num(int.tryParse(dims[0]) ?? dims[0])} × ${dims[1]} × ${dims[2]} mm'),
    ];
    if (specs.isEmpty) {
      return Text('Pas encore de données techniques pour ce modèle.', style: AppText.body(14, color: AppColors.inkSoft));
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in specs)
              Container(
                width: s.$2 == 'L × l × h' ? c.maxWidth : w,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s.$1, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(s.$3, style: AppText.display(18, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.$2, style: AppText.body(12.5, color: AppColors.inkSoft, weight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EditSheet extends StatefulWidget {
  final Map<String, dynamic> car;
  final DocumentReference<Map<String, dynamic>> docRef;

  const _EditSheet({required this.car, required this.docRef});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late String? _color = widget.car['color'] as String?;
  late final _location = TextEditingController(text: widget.car['locationName'] as String? ?? '');
  late final _note = TextEditingController(text: widget.car['note'] as String? ?? '');
  GeoPoint? _coords;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _coords = widget.car['locationCoords'] as GeoPoint?;
  }

  @override
  void dispose() {
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.docRef.update({
        'color': _color,
        'locationName': _location.text.trim().isEmpty ? null : _location.text.trim(),
        'locationCoords': _location.text.trim().isEmpty ? null : _coords,
        'note': _note.text.trim().isEmpty ? FieldValue.delete() : _note.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, "Impossible d'enregistrer.", icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modifier le spot', style: AppText.display(22)),
            const SizedBox(height: 20),
            Text('COULEUR', style: AppText.label(11.5, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in kCarColorSwatches.entries)
                  Pressable(
                    onTap: () => setState(() => _color = _color == e.key ? null : e.key),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == e.key ? AppColors.ink : AppColors.line, width: _color == e.key ? 3 : 1.2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('LIEU', style: AppText.label(11.5, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            TypeAheadField<Map<String, dynamic>>(
              controller: _location,
              builder: (context, controller, focusNode) => TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(hintText: 'Ville', prefixIcon: Icon(Icons.place_outlined)),
                onChanged: (_) => _coords = null,
              ),
              suggestionsCallback: (pattern) {
                final p = VehicleRecognitionService.normalize(pattern);
                if (p.length < 2) return <Map<String, dynamic>>[];
                return AppData.worldCities.where((c) => VehicleRecognitionService.normalize(c['nom']).startsWith(p)).take(10).toList();
              },
              itemBuilder: (context, city) => ListTile(dense: true, title: Text(city['nom']?.toString() ?? '')),
              onSelected: (city) {
                _location.text = city['nom']?.toString() ?? '';
                final lat = (city['latitude'] as num?)?.toDouble();
                final lon = (city['longitude'] as num?)?.toDouble();
                _coords = lat != null && lon != null ? GeoPoint(lat, lon) : null;
                FocusScope.of(context).unfocus();
              },
              emptyBuilder: (_) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            Text('NOTE', style: AppText.label(11.5, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 280,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Un souvenir de ce spot…', counterText: ''),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
