import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:spot_my_car/services/audio_service.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';

/// Choix de la marque préférée : logos sur pastille claire, recherche instantanée.
class BrandSelection extends StatefulWidget {
  const BrandSelection({super.key});

  @override
  State<BrandSelection> createState() => _BrandSelectionState();
}

class _BrandSelectionState extends State<BrandSelection> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    DataManager.instance.loadAllData().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final q = _query.trim().toLowerCase();
    final brands = DataManager.instance.brands
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .where((b) => q.isEmpty || '${b['name']}'.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Marque préférée'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(hintText: tr('Rechercher une marque'), prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: DataManager.instance.brands.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : brands.isEmpty
                    ? EmptyState(icon: Icons.search_off_rounded, title: tr('Aucune marque'), message: tr('Essaie une autre orthographe.'))
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: brands.length,
                        itemBuilder: (context, i) {
                          final b = brands[i];
                          return Pressable(
                            onTap: () {
                              AudioService.instance.playSfx(SoundEffect.clicLeger);
                              Navigator.pop(context, b);
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(18),
                                          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 14)],
                                        ),
                                        child: BrandLogo(url: b['logoUrl'] as String?, name: '${b['name']}', size: 62),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${b['name']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: AppText.body(13, weight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (15 * (i % 18)).ms, duration: 200.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
