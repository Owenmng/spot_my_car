import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/add_car_screen.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/backend_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/services/plate_insight.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Assistant plaque : tu as la plaque mais pas le modèle ? On déduit tout ce qui est possible
/// (pays, période, département), puis on t'aide à trouver la voiture.
class PlateLookupScreen extends StatefulWidget {
  final String? initialPlate;
  const PlateLookupScreen({super.key, this.initialPlate});

  @override
  State<PlateLookupScreen> createState() => _PlateLookupScreenState();
}

class _PlateLookupScreenState extends State<PlateLookupScreen> {
  late final _ctrl = TextEditingController(text: widget.initialPlate ?? '');
  String? _country; // null = automatique
  PlateInsight? _insight;
  Map<String, dynamic>? _brand;

  static const _countries = [
    (null, '✨', 'Auto'),
    ('FR', '🇫🇷', 'France'),
    ('GB', '🇬🇧', 'UK'),
    ('ES', '🇪🇸', 'España'),
    ('IT', '🇮🇹', 'Italia'),
    ('BE', '🇧🇪', 'Belgique'),
    ('DE', '🇩🇪', 'Deutschland'),
    ('CH', '🇨🇭', 'Suisse'),
  ];

  @override
  void initState() {
    super.initState();
    DataManager.instance.loadAllData();
    if (_ctrl.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final p = PlateAnalyzer.clean(_ctrl.text);
    if (p.length < 4) {
      showAppSnack(context, tr('Saisis la plaque complète.'), icon: Icons.pin_outlined);
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    AudioService.instance.playSfx(SoundEffect.clicPrincipal);
    setState(() {
      _insight = PlateAnalyzer.analyze(p, hintCountry: _country);
      _brand = null;
    });
    BackendService.instance.event('plate.lookup', _insight!.country);
  }

  static (int, int)? _years(dynamic py) {
    if (py == null) return null;
    final s = py.toString();
    final ys = RegExp(r'(18|19|20)\d{2}').allMatches(s).map((m) => int.parse(m.group(0)!)).toList();
    if (ys.isEmpty) return null;
    final open = RegExp(r'présent|present|aujourd|now|actuel', caseSensitive: false).hasMatch(s) || ys.length == 1;
    return (ys.first, open ? DateTime.now().year : ys.last);
  }

  List<Map<String, dynamic>> _plausible(Map<String, dynamic> brand) {
    final models = DataManager.instance.visibleModels('${brand['id']}');
    final y = _insight?.year;
    if (y == null || (_insight?.yearTo ?? 0) - (_insight?.yearFrom ?? 0) > 5) return models;
    final from = (_insight!.yearFrom ?? y) - 1, to = (_insight!.yearTo ?? y);
    final hits = models.where((m) {
      final r = _years(m['production_years']);
      return r == null || (r.$1 <= to && r.$2 >= from);
    }).toList();
    return hits.isEmpty ? models : hits;
  }

  Future<void> _pickBrand() async {
    final b = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => const _BrandSheet(),
    );
    if (b != null && mounted) setState(() => _brand = b);
  }

  void _add({bool camera = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddCarScreen(openCamera: camera, initialPlate: _ctrl.text.trim().toUpperCase(), initialCountry: _insight?.recognized == true ? _insight!.country : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final ins = _insight;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(tr('Assistant plaque')), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(tr('Tu as relevé une plaque mais pas le modèle ?'), style: AppText.display(26)),
          const SizedBox(height: 6),
          Text(tr('Entre-la : on déduit son pays, sa période d\'immatriculation et sa région, puis on t\'aide à trouver la voiture.'),
              style: AppText.body(14.5, color: AppColors.inkSoft)),
          const SizedBox(height: 22),
          _PlateField(controller: _ctrl, country: _country ?? ins?.country ?? 'FR', onSubmit: _analyze),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (code, flag, name) in _countries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$flag $name'),
                      selected: _country == code,
                      onSelected: (_) => setState(() => _country = code),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _analyze,
            icon: const Icon(Icons.manage_search_rounded),
            label: Text(tr('Analyser la plaque')),
            style: ElevatedButton.styleFrom(minimumSize: const Size(64, 54)),
          ),
          if (ins != null) ...[
            const SizedBox(height: 24),
            _InsightCard(insight: ins, accent: accent).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 26),
            Text(tr('QUELLE VOITURE ?'), style: AppText.label(12, color: AppColors.inkMuted).copyWith(letterSpacing: 2)),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.photo_camera_rounded,
              color: accent,
              title: tr('Je la prends en photo'),
              subtitle: tr('L\'IA reconnaît la marque et le modèle, la plaque est déjà remplie.'),
              onTap: () => _add(camera: true),
            ).animate(delay: 120.ms).fadeIn().slideX(begin: 0.05, end: 0),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.directions_car_filled_rounded,
              color: const Color(0xFF4DA3FF),
              title: _brand == null ? tr('Je connais la marque') : tr('Marque : {0}', ['${_brand!['name']}']),
              subtitle: ins.year != null
                  ? tr('On te montre ses modèles vendus vers {0}.', [ins.year!])
                  : tr('On te montre tous ses modèles pour la retrouver.'),
              onTap: _pickBrand,
            ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.05, end: 0),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.edit_note_rounded,
              color: AppColors.success,
              title: tr('Je l\'ajoute à la main'),
              subtitle: tr('Saisis la marque et le modèle toi-même.'),
              onTap: _add,
            ).animate(delay: 280.ms).fadeIn().slideX(begin: 0.05, end: 0),
            if (_brand != null) ...[
              const SizedBox(height: 22),
              _ModelsGrid(brand: _brand!, models: _plausible(_brand!), year: ins.year),
            ],
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip_outlined, size: 18, color: AppColors.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Spot My Car ne consulte aucun fichier des cartes grises : tout est déduit de la plaque elle-même, et elle reste privée dans ton garage.'),
                    style: AppText.body(12.5, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateField extends StatelessWidget {
  final TextEditingController controller;
  final String country;
  final VoidCallback onSubmit;
  const _PlateField({required this.controller, required this.country, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    const eu = {'FR', 'DE', 'IT', 'ES', 'BE', 'LU', 'AT', 'NL', 'PT', 'IE'};
    final letter = {'FR': 'F', 'DE': 'D', 'IT': 'I', 'ES': 'E', 'BE': 'B', 'PT': 'P', 'NL': 'NL', 'LU': 'L', 'AT': 'A', 'IE': 'IRL'}[country] ?? '';
    final band = eu.contains(country);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: country == 'GB' ? AppColors.plateYellow : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.plateInk, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (band)
            Container(
              width: 46,
              color: AppColors.plateBlue,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.plateYellow, size: 18),
                  const SizedBox(height: 4),
                  Text(letter, style: AppText.body(18, color: Colors.white, weight: FontWeight.w900)),
                ],
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: controller.text.isEmpty,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')), LengthLimitingTextInputFormatter(12)],
              onSubmitted: (_) => onSubmit(),
              style: AppText.mono(28, color: AppColors.plateInk).copyWith(letterSpacing: 1.5),
              cursorColor: AppColors.plateInk,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'AB-123-CD',
                hintStyle: AppText.mono(28, color: Colors.black26).copyWith(letterSpacing: 1.5),
              ),
            ),
          ),
          if (band) Container(width: 46, color: AppColors.plateBlue),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final PlateInsight insight;
  final Color accent;
  const _InsightCard({required this.insight, required this.accent});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final age = insight.year == null ? null : now - insight.year!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: insight.recognized ? accent.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(insight.flag, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(child: Text(insight.format, style: AppText.body(15, weight: FontWeight.w800))),
            ],
          ),
          if (insight.dateLabel != null || insight.region != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (insight.dateLabel != null)
                  Expanded(child: _Stat(icon: Icons.event_rounded, label: tr('Mise en circulation'), value: insight.dateLabel!)),
                if (insight.region != null) ...[
                  if (insight.dateLabel != null) const SizedBox(width: 10),
                  Expanded(child: _Stat(icon: Icons.place_outlined, label: tr('Origine'), value: insight.region!)),
                ],
              ],
            ),
          ],
          if (age != null && insight.yearTo != null && insight.yearTo! - (insight.yearFrom ?? 0) <= 2) ...[
            const SizedBox(height: 10),
            _Stat(icon: Icons.cake_outlined, label: tr('Âge estimé'), value: age <= 0 ? tr('Toute neuve !') : tr('Environ {0} an(s)', [age])),
          ],
          const SizedBox(height: 14),
          for (final n in insight.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: accent)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n, style: AppText.body(13.5, color: AppColors.inkSoft))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.panelHi, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: AppText.label(10, color: AppColors.inkMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.body(14, weight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(15, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.body(12.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ],
          ),
        ),
      );
}

class _ModelsGrid extends StatelessWidget {
  final Map<String, dynamic> brand;
  final List<Map<String, dynamic>> models;
  final int? year;
  const _ModelsGrid({required this.brand, required this.models, this.year});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          year == null ? tr('{0} modèles {1}', [models.length, '${brand['name']}']) : tr('{0} modèles {1} plausibles', [models.length, '${brand['name']}']),
          style: AppText.display(22),
        ),
        const SizedBox(height: 4),
        Text(tr('Touche un modèle pour voir sa fiche et le comparer à ta voiture.'), style: AppText.body(13, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: models.length.clamp(0, 60),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
          itemBuilder: (context, i) {
            final m = models[i];
            return Pressable(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailScreen(modelsList: models, initialIndex: i, isSpotted: false, brand: brand))),
              child: Container(
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: CarImage(urls: [m['imageUrl'] as String?], brandName: '${brand['name']}', modelName: '${m['name']}', fit: BoxFit.cover, borderRadius: BorderRadius.zero)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13.5, weight: FontWeight.w800)),
                          if (m['production_years'] != null)
                            Text('${m['production_years']}', maxLines: 1, style: AppText.body(11.5, color: AppColors.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BrandSheet extends StatefulWidget {
  const _BrandSheet();
  @override
  State<_BrandSheet> createState() => _BrandSheetState();
}

class _BrandSheetState extends State<_BrandSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brands = DataManager.instance.brands.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).where((b) => '${b['name']}'.toLowerCase().contains(_q.toLowerCase())).toList()
      ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(9))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(hintText: tr('Rechercher une marque'), prefixIcon: const Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: brands.length,
              itemBuilder: (_, i) {
                final b = brands[i];
                return ListTile(
                  leading: BrandLogo(url: b['logoUrl'] as String?, name: '${b['name']}', size: 36),
                  title: Text('${b['name']}', style: AppText.body(15, weight: FontWeight.w700)),
                  onTap: () => Navigator.pop(context, b),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
