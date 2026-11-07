import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:spot_my_car/brand_models_screen.dart';
import 'package:spot_my_car/model_detail_screen.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandDetailScreen extends StatelessWidget {
  final Map<String, dynamic> brand;

  const BrandDetailScreen({super.key, required this.brand});

  static String? _clean(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty || s.toLowerCase().contains('non communiqu')) return null;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataManager>();
    final models = data.visibleModels(brand['id'] as String)
      ..sort((a, b) => rarityFor(brand: brand, model: b).index.compareTo(rarityFor(brand: brand, model: a).index));
    final showcase = models.take(8).toList();
    final rarity = Rarity.values[((brand['rarete'] as num?)?.toInt() ?? 2).clamp(1, 5) - 1];
    final accent = Theme.of(context).colorScheme.primary;

    final facts = <(String, String?)>[
      ('Fondation', _clean(brand['annee_fondation'])),
      ('Pays', _clean(brand['pays'])),
      ('Fondateur', _clean(brand['fondateur'])),
      ('Siège', _clean(brand['siege_social'])),
      ('Groupe', _clean(brand['societe_mere'])),
      ('Ventes / an', _clean(brand['ventes_annuelles'])),
      ('Effectif', _clean(brand['nombre_employes'])),
      ('Chiffre d’affaires', _clean(brand['chiffre_affaires'])),
    ].where((f) => f.$2 != null).toList();

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              BrandLogo(url: brand['logoUrl'] as String?, name: brand['name'] as String? ?? '', size: 76),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand['name'] as String? ?? '', style: AppText.display(36)),
                    if (_clean(brand['slogan']) != null)
                      Text('« ${brand['slogan']} »', style: AppText.body(13.5, color: AppColors.inkSoft).copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    RarityBadge(rarity: rarity, compact: true),
                  ],
                ),
              ),
            ],
          ),
          if (_clean(brand['description']) != null) ...[
            const SizedBox(height: 22),
            Text(brand['description'] as String, style: AppText.body(15, color: AppColors.ink).copyWith(height: 1.55)),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
              child: Column(
                children: [
                  for (var i = 0; i < facts.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: AppColors.line))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 120, child: Text(facts[i].$1, style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w600))),
                          Expanded(child: Text(facts[i].$2!, textAlign: TextAlign.right, style: AppText.body(14, weight: FontWeight.w700))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_clean(brand['modele_emblematique']) != null || _clean(brand['fait_marquant']) != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_clean(brand['modele_emblematique']) != null) ...[
                    Text('MODÈLE EMBLÉMATIQUE', style: AppText.label(11, color: accent)),
                    const SizedBox(height: 4),
                    Text(brand['modele_emblematique'] as String, style: AppText.display(20)),
                  ],
                  if (_clean(brand['fait_marquant']) != null) ...[
                    const SizedBox(height: 14),
                    Text('LE SAVAIS-TU ?', style: AppText.label(11, color: accent)),
                    const SizedBox(height: 4),
                    Text(brand['fait_marquant'] as String, style: AppText.body(14, color: AppColors.ink).copyWith(height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          Row(
            children: [
              Text('LES PLUS RARES', style: AppText.label(12, color: AppColors.inkSoft)),
              const Spacer(),
              Text('${models.length} modèles', style: AppText.mono(12, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: showcase.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final m = showcase[i];
                final r = rarityFor(brand: brand, model: m);
                return Pressable(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ModelDetailScreen(modelsList: showcase, initialIndex: i, isSpotted: false, brand: brand)),
                  ),
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: CarImage(urls: [m['imageUrl'] as String?], brandName: brand['name'] as String?, borderRadius: BorderRadius.circular(AppRadius.md))),
                        const SizedBox(height: 8),
                        Text(m['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(14, weight: FontWeight.w800)),
                        Text(r.label, style: AppText.body(12, color: r.color, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BrandModelsScreen(brand: brand))),
            child: Text('Voir les ${models.length} modèles'),
          ),
          if (_clean(brand['site_officiel']) != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(brand['site_officiel'] as String), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Site officiel'),
            ),
          ],
        ].animate(interval: 25.ms).fadeIn(duration: 250.ms),
      ),
    );
  }
}
