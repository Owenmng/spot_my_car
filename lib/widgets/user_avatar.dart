import 'package:flutter/material.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Avatar d'un joueur : photo Google, avatar de l'appli, ou initiale.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final Color? ring;

  const UserAvatar({super.key, required this.photoUrl, required this.name, this.size = 44, this.ring});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    ImageProvider? image;
    if (url != null && url.startsWith('http')) image = NetworkImage(url, headers: kImageHeaders);
    if (url != null && url.startsWith('assets/')) image = AssetImage(url);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring == null ? 0 : 2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: CircleAvatar(
        backgroundColor: AppColors.panelHi,
        backgroundImage: image,
        child: image == null
            ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: AppText.display(size * 0.42, color: AppColors.inkSoft))
            : null,
      ),
    );
  }
}
