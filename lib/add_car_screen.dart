import 'package:spot_my_car/l10n/i18n.dart';
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

List<Map<String, String>> get countryData => [
  {'code': 'FR', 'name': tr('France'), 'flag': '🇫🇷', 'hint': 'AB-123-CD'},
  {'code': 'DE', 'name': tr('Allemagne'), 'flag': '🇩🇪', 'hint': tr('B SK 1234')},
  {'code': 'IT', 'name': tr('Italie'), 'flag': '🇮🇹', 'hint': tr('AB 123 CD')},
  {'code': 'ES', 'name': tr('Espagne'), 'flag': '🇪🇸', 'hint': tr('1234 ABC')},
  {'code': 'GB', 'name': tr('Royaume-Uni'), 'flag': '🇬🇧', 'hint': tr('AB12 CDE')},
  {'code': 'BE', 'name': tr('Belgique'), 'flag': '🇧🇪', 'hint': '1-ABC-234'},
  {'code': 'CH', 'name': tr('Suisse'), 'flag': '🇨🇭', 'hint': tr('VD 123456')},
  {'code': 'LU', 'name': tr('Luxembourg'), 'flag': '🇱🇺', 'hint': tr('AB 1234')},
  {'code': 'AT', 'name': tr('Autriche'), 'flag': '🇦🇹', 'hint': tr('W 123 AB')},
  {'code': 'US', 'name': tr('États-Unis'), 'flag': '🇺🇸', 'hint': tr('ABC 1234')},
  {'code': 'CA', 'name': tr('Canada'), 'flag': '🇨🇦', 'hint': tr('ABCD 123')},
  {'code': 'XX', 'name': tr('Autre'), 'flag': '🌍', 'hint': tr('Format libre')},
];

class AddCarScreen extends StatefulWidget {
  /// Ouvre directement l'appareil photo à l'arrivée sur l'écran.
  final bool openCamera;

  /// Plaque déjà connue (ex. depuis l'assistant plaque).
  final String? initialPlate;
  final String? initialCountry;

  const AddCarScreen({super.key, this.openCamera = false, this.initialPlate, this.initialCountry});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _draft = SpotDraft();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  bool _noPlate = false;
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
    if (widget.initialPlate != null && widget.initialPlate!.trim().isNotEmpty) {
      _plateCtrl.text = widget.initialPlate!.trim().toUpperCase();
      if (widget.initialCountry != null) _draft.countryCode = widget.initialCountry!;
    }
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
      if (source == ImageSource.camera) AudioService.instance.playSfx(SoundEffect.shutter);
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
          ? tr('Autorise l\'accès à l\'appareil photo dans les réglages du téléphone.')
          : tr('Impossible d\'ouvrir la photo.'), icon: Icons.no_photography_outlined);
    }
  }

  bool _deep = false;

  Future<void> _analyze(Uint8List bytes, {bool deep = false}) async {
    setState(() {
      _analyzing = true;
      _deep = deep;
      _result = null;
      _picked = null;
    });
    final result = await VehicleRecognitionService.instance.analyze(bytes, deep: deep);
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
        _draft.model = modelOverride ?? c.model ?? {'id': 'other', 'name': tr('Autre')};
        if (_draft.model!['id'] == 'other') _modelCtrl.text = c.rawModel;
      } else {
        _draft.brand = {'id': 'other', 'name': tr('Autre')};
        _draft.model = {'id': 'other', 'name': tr('Autre')};
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
      _draft.model = brand['id'] == 'other' ? {'id': 'other', 'name': tr('Autre')} : null;
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
        showAppSnack(context, tr('Localisation indisponible. Active-la ou tape la ville.'), icon: Icons.location_off_outlined);
      } else {
        setState(() {
          _draft.locationName = loc.name;
          _draft.latitude = loc.latitude;
          _draft.longitude = loc.longitude;
          _locationCtrl.text = loc.name;
        });
      }
    } catch (_) {
      if (mounted) showAppSnack(context, tr('Je n\'ai pas réussi à te localiser.'), icon: Icons.location_off_outlined);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------------------------------------------------------------- sauvegarde

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_hasVehicle) {
      showAppSnack(context, tr('Choisis la marque et le modèle.'), icon: Icons.info_outline);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }

    _draft
      ..plate = _noPlate ? '' : _plateCtrl.text
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

      // Un seul grand moment par spot : le succès le plus prestigieux. Les autres
      // sont déjà listés sur la carte révélée, pas de rafale de pop-ups.
      if (result.newAchievements.isNotEmpty && mounted) {
        final a = (result.newAchievements.toList()..sort((x, y) => y.xpReward.compareTo(x.xpReward))).first;
        final parent = result.achievementsAfter.where((x) => x.levels.contains(a));
        await showAchievementUnlocked(context, a, parent.isEmpty ? Icons.emoji_events_rounded : parent.first.icon,
            others: result.newAchievements.length - 1);
      }
      if (result.newLevel != null && mounted) {
        await showLevelUp(context, oldLevel: result.oldLevel, newLevel: result.newLevel!, oldXp: result.oldXp, newXp: result.newXp);
      }
      if (mounted) navigator.pop(true);
    } on DuplicatePlateException catch (e) {
      if (mounted) showAppSnack(context, e.toString(), icon: Icons.content_copy_rounded);
    } catch (e) {
      if (mounted) showAppSnack(context, tr('L\'enregistrement a échoué. Vérifie ta connexion et réessaie.'), icon: Icons.error_outline);
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
        title: Text(_manual ? tr('Ajout manuel') : tr('Nouveau spot')),
        actions: [
          if (_draft.photo != null || _manual)
            IconButton(
              tooltip: _manual ? tr('Reconnaissance automatique') : tr('Saisir à la main'),
              onPressed: () => setState(() {
                _manual = !_manual;
                if (!_manual && _draft.photo != null && _result == null && !_analyzing) _analyze(_draft.photo!);
              }),
              icon: Icon(_manual ? Icons.auto_awesome_rounded : Icons.edit_note_rounded),
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
            if (_analyzing) ...[
              const SizedBox(height: 18),
              _AnalysisProgress(deep: _deep),
            ],
            if (_draft.photo == null && !_manual) ...[
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(tr('Ajouter sans photo')),
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
                onDeep: () => _analyze(_draft.photo!, deep: true),
                deepDone: _deep,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ],
            if (_manual) ...[
              const SizedBox(height: 22),
              _sectionLabel(tr('La voiture')),
              _PickerTile(
                label: tr('Marque'),
                value: _draft.brand?['name'] as String?,
                logoUrl: _draft.brand?['logoUrl'] as String?,
                onTap: _pickBrand,
              ),
              if (_draft.brand?['id'] == 'other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('Nom de la marque')),
                  validator: (v) => (v == null || v.trim().isEmpty) ? tr('Indique la marque') : null,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _PickerTile(
                  label: tr('Modèle'),
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
                decoration: InputDecoration(labelText: tr('Nom du modèle')),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Indique le modèle') : null,
              ),
              const SizedBox(height: 10),
              Text(
                tr('Hors catalogue : la voiture rejoint ton garage, mais ne rapporte pas d\'XP.'),
                style: AppText.body(13, color: AppColors.inkSoft),
              ),
            ],
            if (_showDetails) ...[
              const SizedBox(height: 26),
              _sectionLabel(tr('La plaque')),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _noPlate
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.visibility_off_outlined, color: AppColors.inkSoft, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(tr('Spot enregistré sans plaque.'), style: AppText.body(14, color: AppColors.inkSoft, weight: FontWeight.w600))),
                          ],
                        ),
                      )
                    : _plateField(),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  avatar: Icon(_noPlate ? Icons.check_rounded : Icons.do_not_disturb_alt_rounded, size: 16),
                  showCheckmark: false,
                  label: Text(tr('Je n\'ai pas la plaque')),
                  selected: _noPlate,
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _noPlate = v);
                  },
                ),
              ),
              const SizedBox(height: 26),
              _sectionLabel(tr('La couleur')),
              _ColorPicker(
                selected: _draft.color,
                onChanged: (c) => setState(() => _draft.color = c),
              ),
              const SizedBox(height: 26),
              _sectionLabel(tr('Où ça ?')),
              _locationField(accent),
              const SizedBox(height: 26),
              _sectionLabel(tr('Un mot sur ce spot')),
              TextFormField(
                controller: _noteCtrl,
                maxLength: 280,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr('Garée devant la boulangerie, son V8 réveillait tout le quartier…'),
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
                Icon(Icons.expand_more_rounded, size: 20, color: AppColors.inkSoft),
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
              if (v.isEmpty) return tr('La plaque est obligatoire');
              if (mask == null) return v.length < 3 ? tr('Au moins 3 caractères') : null;
              final expected = mask.replaceAll(RegExp(r'[^A#]'), '').length;
              return v.length < expected ? tr('Plaque incomplète') : null;
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
              hintText: tr('Ville'),
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: _locating
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                  : IconButton(
                      tooltip: tr('Ma position'),
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
            child: Text(tr('Ville introuvable — elle sera enregistrée telle quelle.'), style: AppText.body(13, color: AppColors.inkSoft)),
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
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('NOUVEAU SPOT'), style: AppText.display(30)),
            const SizedBox(height: 8),
            Text(
              tr('Photographie la voiture : marque, modèle, génération, couleur et plaque sont reconnus automatiquement.'),
              style: AppText.body(15, color: AppColors.inkSoft),
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
                          Icon(Icons.photo_camera_rounded, color: Theme.of(context).colorScheme.onPrimary),
                          const SizedBox(width: 10),
                          Flexible(child: Text(tr('Prendre une photo'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(16, color: Theme.of(context).colorScheme.onPrimary, weight: FontWeight.w800))),
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
                        color: AppColors.panelHi,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.photo_library_outlined, color: AppColors.ink),
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

  @override
  void dispose() {
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
        ],
      ),
    );
  }
}

/// Ce que fait l'IA, étape par étape : chaque ligne se coche une seule fois,
/// puis une carte fantôme et une anecdote occupent l'écran jusqu'au résultat.
class _AnalysisProgress extends StatefulWidget {
  final bool deep;
  const _AnalysisProgress({required this.deep});

  @override
  State<_AnalysisProgress> createState() => _AnalysisProgressState();
}

class _AnalysisProgressState extends State<_AnalysisProgress> {
  static List<String> get _labels => [tr('Silhouette et carrosserie'), tr('Logo et calandre'), tr('Modèle et génération'), tr('Couleur et plaque')];
  static List<String> get _facts => [
    tr('La Bugatti Veyron change ses pneus pour environ 30 000 € le train.'),
    tr('La Lamborghini Miura est souvent citée comme la première supercar moderne.'),
    tr('Le logo Alfa Romeo mêle la croix de Milan et la guivre des Visconti.'),
    tr('La Porsche 911 garde son moteur en porte-à-faux arrière depuis 1963.'),
    tr('La Renault 5 Turbo avait son moteur à la place des sièges arrière.'),
    tr('Le nom « Countach » vient d’une exclamation piémontaise de surprise.'),
    tr('La McLaren F1 a un siège conducteur central, flanqué de deux passagers.'),
    tr('La Citroën DS fut la première voiture de série à freins à disque à l’avant.'),
    tr('La Ford Model T a été produite à plus de 15 millions d’exemplaires.'),
    tr('Le cheval cabré de Ferrari venait de l’avion du pilote Francesco Baracca.'),
    tr('La Peugeot 205 GTI est l’une des sportives les plus collectionnées de France.'),
    tr('La Toyota Corolla est la voiture la plus vendue de l’histoire.'),
  ];

  int _done = 0;
  final List<Timer> _timers = [];
  late final String _fact = (_facts.toList()..shuffle()).first;

  @override
  void initState() {
    super.initState();
    final pace = widget.deep ? 2600 : 350;
    for (var i = 1; i < _labels.length; i++) {
      _timers.add(Timer(Duration(milliseconds: pace * i), () {
        if (mounted) setState(() => _done = i);
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                  Text(widget.deep ? tr('ANALYSE POUSSÉE') : tr('ANALYSE EN COURS'), style: AppText.label(11.5, color: accent)),
                  const Spacer(),
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: i < _done
                            ? const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), size: 20, color: AppColors.success)
                            : i == _done
                                ? SizedBox(key: const ValueKey('run'), width: 20, height: 20, child: Padding(padding: const EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: accent)))
                                : Icon(Icons.radio_button_unchecked_rounded, key: ValueKey('wait'), size: 20, color: AppColors.inkMuted),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _labels[i],
                        style: AppText.body(14.5, weight: i <= _done ? FontWeight.w700 : FontWeight.w500, color: i <= _done ? AppColors.ink : AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 14),
        // Carte fantôme : la forme du résultat qui arrive.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _bone(46, 46, circle: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_bone(70, 10), const SizedBox(height: 8), _bone(170, 20), const SizedBox(height: 8), _bone(110, 12)],
                ),
              ),
              _bone(44, 44, circle: true),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1400.ms, color: AppColors.ink.withValues(alpha: 0.08)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('LE SAVAIS-TU ?'), style: AppText.label(10.5, color: accent)),
                    const SizedBox(height: 4),
                    Text(_fact, style: AppText.body(14, color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
      ],
    );
  }

  Widget _bone(double w, double h, {bool circle = false}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.panelHi,
          borderRadius: BorderRadius.circular(circle ? 99 : 6),
        ),
      );
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
  final VoidCallback onDeep;
  final bool deepDone;

  const _ResultPanel({
    required this.result,
    required this.picked,
    required this.onPick,
    required this.onManual,
    required this.onRetry,
    required this.onDeep,
    required this.deepDone,
  });

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
                    result.status == RecognitionStatus.unclear ? tr('Pas assez net') : failed ? tr('Analyse impossible') : tr('Hmm…'),
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
                  Expanded(child: OutlinedButton(onPressed: deepDone ? onRetry : onDeep, child: Text(deepDone ? tr('Réessayer') : tr('Analyse poussée')))),
                if (failed || result.status == RecognitionStatus.unclear) const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: onManual, child: Text(tr('Saisir à la main')))),
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
                      Text(tr('+{0} XP', [rarity.xp]), style: AppText.body(13, color: rarity.color, weight: FontWeight.w800)),
                    if (!current.inCatalog)
                      Text(tr('Pas encore dans le catalogue'), style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600)),
                    Text(
                      percent >= 75 ? tr('Sûr à {0} %', [percent]) : tr('Probable à {0} %', [percent]),
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
                    label: Text(tr('Oui, c\'est elle')),
                  ),
                ),
            ],
          ),
        ),
        if (current.alternatives.isNotEmpty && current.brand != null) ...[
          const SizedBox(height: 16),
          Text(tr('Une autre version ?'), style: AppText.label(11.5, color: AppColors.inkMuted)),
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
          Text(tr('Ou peut-être…'), style: AppText.label(11.5, color: AppColors.inkMuted)),
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
        if (!deepDone && current.confidence < 0.93) ...[
          const SizedBox(height: 8),
          Pressable(
            onTap: onDeep,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.manage_search_rounded, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Un doute ? Analyse poussée'), style: AppText.body(14.5, weight: FontWeight.w800)),
                        Text(tr('Plus lente, l\'IA examine chaque détail.'), style: AppText.body(12.5, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton(onPressed: onManual, child: Text(tr('Ce n\'est pas ça, je choisis moi-même'))),
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
                    Text(value ?? tr('Choisir'), style: AppText.body(16, weight: FontWeight.w700, color: value == null ? AppColors.inkMuted : AppColors.ink)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
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
            message: tr(e.key),
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
    final tips = [
      (Icons.crop_free_rounded, tr('Cadre la voiture en entier, de 3/4 avant si possible.')),
      (Icons.wb_sunny_outlined, tr('Évite le contre-jour : les optiques et la calandre parlent beaucoup.')),
      (Icons.pin_outlined, tr('Si la plaque est lisible, je la remplis pour toi.')),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Pour une reconnaissance au top'), style: AppText.body(15, weight: FontWeight.w800)),
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
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Theme.of(context).colorScheme.onPrimary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('Ajouter au garage')),
                  if (xp > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                      child: Text(tr('+{0} XP', [xp]), style: AppText.body(13, color: Theme.of(context).colorScheme.onPrimary, weight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
