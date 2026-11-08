import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/spot_card.dart';

class ShareService {
  ShareService._();

  /// Aperçu de la carte puis partage en image (Insta, WhatsApp, Snap…).
  static Future<void> shareSpot(BuildContext context, Map<String, dynamic> car, {String? carId}) {
    final key = GlobalKey();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var busy = false;
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: key,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 250,
                            height: 340,
                            child: SpotCard(car: car, carId: carId, heroTag: 'share_${car.hashCode}', large: true),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_car_filled_rounded, color: Colors.white54, size: 16),
                              const SizedBox(width: 6),
                              Text('Spotté avec SpotMyCar', style: AppText.body(12.5, color: Colors.white54, weight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                await _capture(key, car);
                              } finally {
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                              }
                            },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(busy ? 'Préparation…' : 'Partager'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _capture(GlobalKey key, Map<String, dynamic> car) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final name = fullCarName(car['brandName'] as String?, car['modelName'] as String?);
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: 'spotmycar.png')],
      text: 'Regarde ce que je viens de spotter : $name 👀',
    ));
  }
}
