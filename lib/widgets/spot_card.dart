import 'package:spot_my_car/l10n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/data_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/car_image.dart';
import 'package:spot_my_car/widgets/plate_badge.dart';

/// Rareté d'un spot enregistré : stockée depuis la v2, recalculée pour les anciens spots.
Rarity rarityOfSpot(Map<String, dynamic> car) {
  final stored = car['rarity'];
  if (stored is String) {
    final r = Rarity.values.where((x) => x.name == stored);
    if (r.isNotEmpty) return r.first;
  }
  if (car['isCatalogued'] != true) return Rarity.commune;
  final brandId = car['brandId'];
  final brand = DataManager.instance.brands.whereType<Map>().where((b) => b['id'] == brandId);
  return rarityFor(brand: brand.isEmpty ? null : Map<String, dynamic>.from(brand.first), model: car);
}

String cleanModelName(String? name) {
  final n = name ?? '';
  final i = n.indexOf('(');
  return (i > 0 ? n.substring(0, i) : n).trim();
}

/// Nom complet sans répétition : « Mustang » + « Mustang » → « Mustang »,
/// « Ford Mustang » + « Mustang Mach-E » → « Ford Mustang Mach-E ».
String fullCarName(String? brand, String? model) {
  final b = (brand ?? '').trim();
  final m = cleanModelName(model);
  if (b.isEmpty) return m;
  if (m.isEmpty) return b;
  final bl = b.toLowerCase(), ml = m.toLowerCase();
  if (ml == bl || ml.startsWith('$bl ')) return m;
  final first = ml.split(' ').first;
  if (bl.endsWith(first)) return '$b${m.substring(first.length)}';
  return '$b $m';
}

/// Libellé « marque » au-dessus du nom : quand la marque est aussi le nom du modèle
/// (Mustang, Mini…), on affiche plutôt le constructeur parent.
String brandHeader(String? brand, String? model) {
  final b = (brand ?? '').trim();
  final m = cleanModelName(model).toLowerCase();
  if (b.isNotEmpty && (m == b.toLowerCase() || m.startsWith('${b.toLowerCase()} '))) {
    final hit = DataManager.instance.brands.whereType<Map>().where((x) => x['name'] == b);
    final parent = hit.isEmpty ? null : hit.first['societe_mere'] as String?;
    if (parent != null && parent.isNotEmpty && parent.length < 20 && parent.toLowerCase() != b.toLowerCase()) return parent;
  }
  return b;
}

/// Carte de collection : la voiture, son cadre de rareté, sa plaque.
class SpotCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final String heroTag;
  final String? carId;
  final bool large;

  const SpotCard({super.key, required this.car, required this.heroTag, this.carId, this.large = false});

  @override
  Widget build(BuildContext context) {
    final rarity = rarityOfSpot(car);
    final brand = (car['brandName'] as String?) ?? tr('Marque inconnue');
    final model = cleanModelName(car['modelName'] as String?);

    return Container(
      padding: EdgeInsets.all(large ? 4 : 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(large ? AppRadius.xl : AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: rarity.frame,
        ),
        boxShadow: [
          BoxShadow(
            color: rarity.color.withValues(alpha: rarity.index >= 3 ? 0.35 : 0.12),
            blurRadius: rarity.index >= 3 ? 18 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((large ? AppRadius.xl : AppRadius.lg) - 3),
        child: ColoredBox(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: carId != null
                          ? SpotImage(carId: carId!, car: car)
                          : CarImage(
                              urls: [
                                car['userPhotoUrl'] as String?,
                                DataManager.instance.modelById(car['modelId'] as String?)?['imageUrl'] as String?,
                                car['modelImageUrl'] as String?,
                              ],
                              brandName: brand,
                              modelName: model,
                            ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.55, 1],
                          colors: [Colors.transparent, Color(0x99000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _RarityTag(rarity: rarity),
                    ),
                    if (car['isPending'] == true)
                      const Positioned(top: 8, right: 8, child: Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18)),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Text(
                        brandHeader(brand, car['modelName'] as String?).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(large ? 12 : 10, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(large ? 14 : 10, large ? 12 : 8, large ? 14 : 10, large ? 14 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.isEmpty ? '—' : model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(large ? 22 : 15.5, weight: FontWeight.w800),
                    ),
                    SizedBox(height: large ? 10 : 7),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: PlateBadge(
                              plate: (car['plate'] as String?) ?? '',
                              countryCode: car['plateCountryCode'] as String?,
                              scale: large ? 0.8 : 0.58,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (car['xp'] is num && (car['xp'] as num) > 0)
                          Text('+${car['xp']}', style: AppText.mono(large ? 12 : 10, color: rarity.color)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityTag extends StatelessWidget {
  final Rarity rarity;
  const _RarityTag({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: rarity.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(rarity.label.toUpperCase(), style: AppText.label(9, color: Colors.white)),
        ],
      ),
    );
  }
}
