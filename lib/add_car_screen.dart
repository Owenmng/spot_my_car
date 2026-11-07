import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spot_my_car/achievement_overlay.dart';
import 'package:spot_my_car/brand_selection_screen.dart';
import 'package:spot_my_car/level_up_overlay.dart';
import 'package:spot_my_car/model_selection_screen.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/plate_input_formatter.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/location_service.dart';
import 'package:spot_my_car/services/spot_service.dart';
import 'package:spot_my_car/services/vehicle_recognition_service.dart';
import 'package:spot_my_car/shared/app_data.dart';
import 'package:spot_my_car/shared/plate_formats.dart';
import 'package:spot_my_car/spot_reveal_screen.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

final List<Map<String, String>> countryData = [
  {'code': 'FR', 'name': 'France', 'flag': '🇫🇷', 'hint': 'AB-123-CD'},
  {'code': 'DE', 'name': 'Allemagne', 'flag': '🇩🇪', 'hint': 'B SK 1234'},
  {'code': 'IT', 'name': 'Italie', 'flag': '🇮🇹', 'hint': 'AB 123 CD'},
  {'code': 'ES', 'name': 'Espagne', 'flag': '🇪🇸', 'hint': '1234 ABC'},
  {'code': 'GB', 'name': 'Royaume-Uni', 'flag': '🇬🇧', 'hint': 'AB12 CDE'},
  {'code': 'BE', 'name': 'Belgique', 'flag': '🇧🇪', 'hint': '1-ABC-234'},
  {'code': 'CH', 'name': 'Suisse', 'flag': '🇨🇭', 'hint': 'VD 123456'},
  {'code': 'LU', 'name': 'Luxembourg', 'flag': '🇱🇺', 'hint': 'AB 1234'},
  {'code': 'AT', 'name': 'Autriche', 'flag': '🇦🇹', 'hint': 'W 123 AB'},
  {'code': 'US', 'name': 'États-Unis', 'flag': '🇺🇸', 'hint': 'ABC 1234'},
  {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦', 'hint': 'ABCD 123'},
  {'code': 'XX', 'name': 'Autre', 'flag': '🌍', 'hint': 'Format libre'},
];

class AddCarScreen extends StatefulWidget {
  /// Ouvre directement l'appareil photo à l'arrivée sur l'écran.
  final bool openCamera;

  const AddCarScreen({super.key, this.openCamera = false});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _draft = SpotDraft();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _manual = false;
  bool _analyzing = false;
  bool _saving = false;
  bool _locating = false;
  RecognitionResult? _result;
  VehicleCandidate? _picked;

  @override
  void initState() {
    super.initState();
    DataManager.instance.loadAllData();
    AppData.loadWorldCities();
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(ImageSource.camera));
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  bool get _hasVehicle => _draft.brand != null && (_draft.model != null || _draft.isCustomBrand);
  bool get _showDetails => _hasVehicle || _manual;

  // ---------------------------------------------------------------- photo & IA

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1600, maxHeight: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _draft.photo = bytes;
        _result = null;
        _picked = null;
        if (!_manual) {
          _draft.brand = null;
          _draft.model = null;
        }
      });
      if (!_manual) unawaited(_analyze(bytes));
    } on PlatformException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.code == 'camera_access_denied'
          ? "Autorise l'accès à l'appareil photo dans les réglages du téléphone."
          : "Impossible d'ouvrir la photo.", icon: Icons.no_photography_outlined);
    }
  }

  Future<void> _analyze(Uint8List bytes) async {
    setState(() => _analyzing = true);
    final result = await VehicleRecognitionService.instance.analyze(bytes);
    if (!mounted || _draft.photo != bytes) return;

    setState(() {
      _analyzing = false;
      _result = result;
      if (result.colorName != null) _draft.color ??= result.colorName;
      if (result.plate != null && _plateCtrl.text.isEmpty) {
        final country = countryData.any((c) => c['code'] == result.plateCountry) ? result.plateCountry! : _draft.countryCode;
        _draft.countryCode = country;
        _plateCtrl.text = _formatPlate(result.plate!, country);
      }
    });

    if (result.status == RecognitionStatus.car && result.best != null) {
      HapticFeedback.mediumImpact();
      AudioService.instance.playSfx(SoundEffect.notification);
      if (result.best!.confidence >= 0.75) _choose(result.best!);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _choose(VehicleCandidate c, {Map<String, dynamic>? modelOverride}) {
    setState(() {
      _picked = c;
      if (c.brand != null) {
        _draft.brand = c.brand;
        _draft.model = modelOverride ?? c.model ?? {'id': 'other', 'name': 'Autre'};
        if (_draft.model!['id'] == 'other') _modelCtrl.text = c.rawModel;
      } else {
        _draft.brand = {'id': 'other', 'name': 'Autre'};
        _draft.model = {'id': 'other', 'name': 'Autre'};
        _brandCtrl.text = c.rawMake;
        _modelCtrl.text = c.rawModel;
      }
      _draft.aiGuess = '${c.displayBrand} ${c.displayModel}';
      _draft.aiConfidence = c.confidence;
    });
  }

  String _formatPlate(String raw, String country) {
    final mask = plateFormats[country];
    if (mask == null) return raw.toUpperCase();
    final formatted = PlateInputFormatter(mask: mask)
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: raw))
        .text;
    return formatted.isEmpty ? raw.toUpperCase() : formatted;
  }

  // ---------------------------------------------------------------- choix manuel

  Future<void> _pickBrand() async {
    final brand = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const BrandSelectionScreen()),
    );
    if (brand == null || !mounted) return;
    setState(() {
      _draft.brand = brand;
      _draft.model = brand['id'] == 'other' ? {'id': 'other', 'name': 'Autre'} : null;
    });
    if (brand['id'] != 'other') await _pickModel();
  }

  Future<void> _pickModel() async {
    final brand = _draft.brand;
    if (brand == null || brand['id'] == 'other') return;
    final models = DataManager.instance.modelsByBrand[brand['id']] ?? [];
    final model = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ModelSelectionScreen(brandName: brand['name'], models: models)),
    );
    if (model == null || !mounted) return;
    setState(() => _draft.model = model);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationService.current();
      if (!mounted) return;
      if (loc == null) {
        showAppSnack(context, 'Localisation indisponible. Active-la ou tape la ville.', icon: Icons.location_off_outlined);
      } else {
        setState(() {
          _draft.locationName = loc.name;
          _draft.latitude = loc.latitude;
          _draft.longitude = loc.longitude;
          _locationCtrl.text = loc.name;
        });
      }
    } catch (_) {
      if (mounted) showAppSnack(context, "Je n'ai pas réussi à te localiser.", icon: Icons.location_off_outlined);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------------------------------------------------------------- sauvegarde

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_hasVehicle) {
      showAppSnack(context, 'Choisis la marque et le modèle.', icon: Icons.info_outline);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }

    _draft
      ..plate = _plateCtrl.text
      ..customBrand = _brandCtrl.text
      ..customModel = _modelCtrl.text
      ..note = _noteCtrl.text;

    if (_draft.locationName == null && _locationCtrl.text.trim().isNotEmpty) {
      _draft.locationName = _locationCtrl.text.trim();
    }

    setState(() => _saving = true);
    try {
      if (_draft.aiGuess != null) {
        unawaited(SpotService.instance.sendRecognitionFeedback(aiGuess: _draft.aiGuess, chosen: '${_draft.brandName} ${_draft.modelName}'));
      }
      final result = await SpotService.instance.save(_draft);
      if (!mounted) return;
      AudioService.instance.playSfx(SoundEffect.succesPrincipal);
      HapticFeedback.heavyImpact();

      final navigator = Navigator.of(context);
      await navigator.push(SpotRevealScreen.route(draft: _draft, result: result));
      if (!mounted) return;

      for (final a in result.newAchievements) {
        final parent = result.achievementsAfter.where((x) => x.levels.contains(a));
        if (!mounted) return;
        await showAchievementUnlocked(context, a, parent.isEmpty ? Icons.emoji_events_rounded : parent.first.icon);
      }
      if (result.newLevel != null && mounted) {
        await showLevelUp(context, oldLevel: result.oldLevel, newLevel: result.newLevel!, oldXp: result.oldXp, newXp: result.newXp);
      }
      if (mounted) navigator.pop(true);
    } on DuplicatePlateException catch (e) {
      if (mounted) showAppSnack(context, e.toString(), icon: Icons.content_copy_rounded);
    } catch (e) {
      if (mounted) showAppSnack(context, "L'enregistrement a échoué. Vérifie ta connexion et réessaie.", icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_manual ? 'Ajout manuel' : 'Nouveau spot'),
        actions: [
          if (_draft.photo != null || _manual)
            TextButton(
              onPressed: () => setState(() {
                _manual = !_manual;
                if (!_manual && _draft.photo != null && _result == null && !_analyzing) _analyze(_draft.photo!);
              }),
              child: Text(_manual ? 'Mode auto' : 'Saisir à la main'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 120 + bottomInset),
          children: [
            _PhotoStage(
              photo: _draft.photo,
              analyzing: _analyzing,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
            ),
            if (_draft.photo == null && !_manual) ...[
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ajouter sans photo'),
                ),
              ),
              const SizedBox(height: 8),
              const _Tips(),
            ],
            if (!_manual && _result != null) ...[
              const SizedBox(height: 20),
              _ResultPanel(
                result: _result!,
                picked: _picked,
                onPick: _choose,
                onManual: () => setState(() => _manual = true),
                onRetry: () => _analyze(_draft.photo!),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ],
            if (_manual) ...[
              const SizedBox(height: 22),
              _sectionLabel('La voiture'),
              _PickerTile(
                label: 'Marque',
                value: _draft.brand?['name'] as String?,
                logoUrl: _draft.brand?['logoUrl'] as String?,
                onTap: _pickBrand,
              ),
              if (_draft.brand?['id'] == 'other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom de la marque'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique la marque' : null,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _PickerTile(
                  label: 'Modèle',
                  value: _draft.model?['name'] as String?,
                  enabled: _draft.brand != null,
                  onTap: _pickModel,
                ),
              ],
            ],
            if (_draft.model?['id'] == 'other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom du modèle'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique le modèle' : null,
              ),
              const SizedBox(height: 10),
              Text(
                "Hors catalogue : la voiture rejoint ton garage, mais ne rapporte pas d'XP.",
                style: AppText.body(13, color: AppColors.inkSoft),
              ),
            ],
            if (_showDetails) ...[
              const SizedBox(height: 26),
              _sectionLabel('La plaque'),
              _plateField(),
              const SizedBox(height: 26),
              _sectionLabel('La couleur'),
              _ColorPicker(
                selected: _draft.color,
                onChanged: (c) => setState(() => _draft.color = c),
              ),
              const SizedBox(height: 26),
              _sectionLabel('Où ça ?'),
              _locationField(accent),
              const SizedBox(height: 26),
              _sectionLabel('Un mot sur ce spot'),
              TextFormField(
                controller: _noteCtrl,
                maxLength: 280,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Garée devant la boulangerie, son V8 réveillait tout le quartier…',
                  counterText: '',
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _showDetails
          ? _SaveBar(
              saving: _saving,
              xp: _draft.xp,
              rarity: _draft.isCatalogued ? _draft.rarity : null,
              onSave: _save,
            ).animate().slideY(begin: 1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
          : null,
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text.toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
      );

  Widget _plateField() {
    final country = countryData.firstWhere((c) => c['code'] == _draft.countryCode, orElse: () => countryData.first);
    final mask = plateFormats[_draft.countryCode];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          onTap: () async {
            final picked = await showModalBottomSheet<Map<String, String>>(
              context: context,
              builder: (_) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in countryData)
                      ListTile(
                        leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                        title: Text(c['name']!),
                        trailing: c['code'] == _draft.countryCode ? const Icon(Icons.check_rounded) : null,
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ],
                ),
              ),
            );
            if (picked != null) {
              setState(() {
                _draft.countryCode = picked['code']!;
                _plateCtrl.text = _formatPlate(_plateCtrl.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''), _draft.countryCode);
              });
            }
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Text(country['flag']!, style: const TextStyle(fontSize: 22)),
                const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _plateCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: mask == null ? [UpperCaseTextFormatter()] : [PlateInputFormatter(mask: mask)],
            style: AppText.mono(18),
            decoration: InputDecoration(hintText: country['hint']),
            validator: (value) {
              final v = (value ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
              if (v.isEmpty) return 'La plaque est obligatoire';
              if (mask == null) return v.length < 3 ? 'Au moins 3 caractères' : null;
              final expected = mask.replaceAll(RegExp(r'[^A#]'), '').length;
              return v.length < expected ? 'Plaque incomplète' : null;
            },
          ),
        ),
      ],
    );
  }

  Widget _locationField(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TypeAheadField<Map<String, dynamic>>(
          controller: _locationCtrl,
          builder: (context, controller, focusNode) => TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ville',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: _locating
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                  : IconButton(
                      tooltip: 'Ma position',
                      icon: Icon(Icons.my_location_rounded, color: accent),
                      onPressed: _useMyLocation,
                    ),
            ),
            onChanged: (_) {
              _draft.locationName = null;
              _draft.latitude = null;
              _draft.longitude = null;
            },
          ),
          suggestionsCallback: (pattern) {
            final p = VehicleRecognitionService.normalize(pattern);
            if (p.length < 2) return <Map<String, dynamic>>[];
            return AppData.worldCities
                .where((c) => VehicleRecognitionService.normalize(c['nom']).startsWith(p))
                .take(12)
                .toList();
          },
          itemBuilder: (context, city) => ListTile(
            dense: true,
            leading: const Icon(Icons.location_city_outlined, size: 20),
            title: Text(city['nom']?.toString() ?? ''),
          ),
          onSelected: (city) {
            setState(() {
              _locationCtrl.text = city['nom']?.toString() ?? '';
              _draft.locationName = _locationCtrl.text;
              _draft.latitude = (city['latitude'] as num?)?.toDouble();
              _draft.longitude = (city['longitude'] as num?)?.toDouble();
            });
            FocusScope.of(context).unfocus();
          },
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Ville introuvable — elle sera enregistrée telle quelle.', style: AppText.body(13, color: AppColors.inkSoft)),
          ),
          decorationBuilder: (context, child) => Material(
            elevation: 6,
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 260), child: child),
          ),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// ==================================================================== widgets

class _PhotoStage extends StatelessWidget {
  final Uint8List? photo;
  final bool analyzing;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoStage({required this.photo, required this.analyzing, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (photo == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Une voiture te fait de l’œil ?', style: AppText.display(26, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Prends-la en photo : je reconnais la marque, le modèle, la génération et même la plaque.',
              style: AppText.body(15, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Pressable(
                    onTap: onCamera,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Text('Prendre une photo', style: AppText.body(16, color: Colors.white, weight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Pressable(
                    onTap: onGallery,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.photo_library_outlined, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.98, 0.98), curve: Curves.easeOut);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        if (analyzing) const Positioned.fill(child: _ScanOverlay()),
        Positioned(
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              _RoundIcon(icon: Icons.photo_library_outlined, onTap: onGallery),
              const SizedBox(width: 8),
              _RoundIcon(icon: Icons.photo_camera_rounded, onTap: onCamera),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Viseur + balayage lumineux pendant que l'IA regarde la photo.
class _ScanOverlay extends StatefulWidget {
  const _ScanOverlay();

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  Timer? _timer;
  int _step = 0;

  static const _steps = [
    'Je regarde la calandre…',
    'Je compare les optiques…',
    'Je cherche le logo…',
    'Je date la génération…',
    'Je lis la plaque…',
    'Presque fini…',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Align(
              alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.45), accent.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: Padding(padding: EdgeInsets.all(18), child: CustomPaint(painter: _CornersPainter()))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: child),
                ),
                child: Container(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
                  child: Text(_steps[_step], style: AppText.body(13.5, color: Colors.white, weight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    final w = size.width, h = size.height;
    for (final c in [
      [Offset.zero, const Offset(l, 0), const Offset(0, l)],
      [Offset(w, 0), Offset(w - l, 0), Offset(w, l)],
      [Offset(0, h), Offset(l, h), Offset(0, h - l)],
      [Offset(w, h), Offset(w - l, h), Offset(w, h - l)],
    ]) {
      canvas.drawLine(c[0], c[1], p);
      canvas.drawLine(c[0], c[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultPanel extends StatelessWidget {
  final RecognitionResult result;
  final VehicleCandidate? picked;
  final void Function(VehicleCandidate, {Map<String, dynamic>? modelOverride}) onPick;
  final VoidCallback onManual;
  final VoidCallback onRetry;

  const _ResultPanel({required this.result, required this.picked, required this.onPick, required this.onManual, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (result.status != RecognitionStatus.car) {
      final failed = result.status == RecognitionStatus.failed;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.status == RecognitionStatus.unclear ? Icons.blur_on_rounded : failed ? Icons.wifi_tethering_error_rounded : Icons.do_not_disturb_on_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.status == RecognitionStatus.unclear ? 'Pas assez net' : failed ? 'Analyse impossible' : 'Hmm…',
                    style: AppText.display(19),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.message, style: AppText.body(14.5, color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (failed || result.status == RecognitionStatus.unclear)
                  Expanded(child: OutlinedButton(onPressed: onRetry, child: const Text('Réessayer'))),
                if (failed || result.status == RecognitionStatus.unclear) const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: onManual, child: const Text('Saisir à la main'))),
              ],
            ),
          ],
        ),
      );
    }

    final best = result.best!;
    final current = picked ?? best;
    final others = result.candidates.where((c) => c != current).toList();
    final rarity = current.inCatalog ? rarityFor(brand: current.brand, model: current.model) : null;
    final percent = (current.confidence * 100).round();
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: picked != null ? accent : AppColors.line, width: picked != null ? 1.8 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandLogo(url: current.brand?['logoUrl'] as String?, name: current.displayBrand, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.displayBrand.toUpperCase(), style: AppText.label(11.5, color: AppColors.inkMuted)),
                          const SizedBox(height: 3),
                          Text(current.displayModel, style: AppText.display(23)),
                          if (current.generation != null || current.yearsLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [if (current.generation != null) current.generation!, if (current.yearsLabel != null) current.yearsLabel!].join(' · '),
                              style: AppText.body(13.5, color: AppColors.inkSoft, weight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _ConfidenceRing(value: current.confidence),
                  ],
                ),
              ),
              if (current.reasoning != null && current.reasoning!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Text('« ${current.reasoning} »', style: AppText.body(13.5, color: AppColors.inkSoft).copyWith(fontStyle: FontStyle.italic)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (rarity != null) RarityBadge(rarity: rarity),
                    if (rarity != null)
                      Text('+${rarity.xp} XP', style: AppText.body(13, color: rarity.color, weight: FontWeight.w800)),
                    if (!current.inCatalog)
                      Text('Pas encore dans le catalogue', style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600)),
                    Text(
                      percent >= 75 ? 'Sûr à $percent %' : 'Probable à $percent %',
                      style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (picked == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: ElevatedButton.icon(
                    onPressed: () => onPick(best),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Oui, c'est elle"),
                  ),
                ),
            ],
          ),
        ),
        if (current.alternatives.isNotEmpty && current.brand != null) ...[
          const SizedBox(height: 16),
          Text('Une autre version ?', style: AppText.label(11.5, color: AppColors.inkMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in current.alternatives)
                ActionChip(
                  label: Text(m['name'] as String),
                  onPressed: () => onPick(current, modelOverride: m),
                ),
            ],
          ),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Ou peut-être…', style: AppText.label(11.5, color: AppColors.inkMuted)),
          const SizedBox(height: 8),
          for (final c in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => onPick(c),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 44,
                        child: CarImage(
                          urls: [c.model?['imageUrl'] as String?],
                          brandName: c.displayBrand,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${c.displayBrand} ${c.displayModel}', style: AppText.body(15, weight: FontWeight.w700)),
                      ),
                      Text('${(c.confidence * 100).round()} %', style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton(onPressed: onManual, child: const Text("Ce n'est pas ça, je choisis moi-même")),
        ),
      ],
    );
  }
}

class _ConfidenceRing extends StatelessWidget {
  final double value;
  const _ConfidenceRing({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.75 ? AppColors.success : value >= 0.5 ? AppColors.warning : AppColors.danger;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: v, strokeWidth: 4.5, color: color, backgroundColor: AppColors.paperDeep, strokeCap: StrokeCap.round),
            Text('${(v * 100).round()}', style: AppText.body(13, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? logoUrl;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerTile({required this.label, required this.value, required this.onTap, this.logoUrl, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              if (value != null && logoUrl != null) ...[
                BrandLogo(url: logoUrl, name: value!, size: 34),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.body(12, color: AppColors.inkSoft, weight: FontWeight.w600)),
                    Text(value ?? 'Choisir', style: AppText.body(16, weight: FontWeight.w700, color: value == null ? AppColors.inkMuted : AppColors.ink)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ColorPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final e in kCarColorSwatches.entries)
          Tooltip(
            message: e.key,
            child: Pressable(
              onTap: () => onChanged(selected == e.key ? null : e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == e.key ? AppColors.ink : AppColors.line,
                    width: selected == e.key ? 3 : 1.2,
                  ),
                  boxShadow: selected == e.key ? [BoxShadow(color: e.value.withValues(alpha: 0.5), blurRadius: 10)] : null,
                ),
                child: selected == e.key
                    ? Icon(Icons.check_rounded, size: 18, color: e.value.computeLuminance() > 0.5 ? AppColors.ink : Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.crop_free_rounded, 'Cadre la voiture en entier, de 3/4 avant si possible.'),
      (Icons.wb_sunny_outlined, 'Évite le contre-jour : les optiques et la calandre parlent beaucoup.'),
      (Icons.pin_outlined, 'Si la plaque est lisible, je la remplis pour toi.'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pour une reconnaissance au top', style: AppText.body(15, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(t.$1, size: 19, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.$2, style: AppText.body(14, color: AppColors.inkSoft))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final int xp;
  final Rarity? rarity;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.xp, required this.rarity, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.paper,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: ElevatedButton(
        onPressed: saving ? null : onSave,
        child: saving
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ajouter au garage'),
                  if (xp > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(99)),
                      child: Text('+$xp XP', style: AppText.body(13, color: Colors.white, weight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
