import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/models/rarity.dart';
import 'package:spot_my_car/services/custom_cache_manager.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Petit enfoncement + vibration légère au toucher, pour que chaque bouton « réponde ».
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Titre de section : un petit sur-titre en capitales, sans trait de séparation.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? overline;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionTitle(this.title, {super.key, this.overline, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 12)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(overline!.toUpperCase(), style: AppText.label(11, color: AppColors.inkMuted)),
                  const SizedBox(height: 4),
                ],
                Text(title, style: AppText.display(21)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class RarityBadge extends StatelessWidget {
  final Rarity rarity;
  final bool compact;
  final bool onDark;

  const RarityBadge({super.key, required this.rarity, this.compact = false, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withValues(alpha: 0.35) : rarity.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: rarity.color.withValues(alpha: onDark ? 0.9 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_rounded, size: compact ? 11 : 13, color: rarity.color),
          const SizedBox(width: 4),
          Text(
            rarity.label,
            style: AppText.body(compact ? 10.5 : 12, color: onDark ? Colors.white : rarity.color, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const BrandLogo({super.key, required this.url, required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: AppText.display(size * 0.45),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.line),
      ),
      child: (url == null || url!.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: url!,
              cacheManager: CustomCacheManager(),
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => fallback,
              placeholder: (_, __) => const SizedBox.shrink(),
            ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: AppText.display(22)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.inkSoft)),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Pastille de stat : un gros chiffre, un petit libellé.
class StatPill extends StatelessWidget {
  final String value;
  final String label;
  final bool dark;

  const StatPill({super.key, required this.value, required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.display(24, color: dark ? Colors.white : AppColors.ink)),
        const SizedBox(height: 2),
        Text(label, style: AppText.body(12, color: dark ? Colors.white60 : AppColors.inkSoft, weight: FontWeight.w600)),
      ],
    );
  }
}

void showAppSnack(BuildContext context, String message, {IconData? icon, Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: color ?? Colors.white, size: 20), const SizedBox(width: 10)],
          Expanded(child: Text(message)),
        ],
      ),
    ));
}

const Map<String, Color> kCarColorSwatches = {
  'Noir': Color(0xFF151515),
  'Blanc': Color(0xFFF7F7F5),
  'Gris': Color(0xFF7D7F84),
  'Argent': Color(0xFFC9CDD2),
  'Rouge': Color(0xFFC8102E),
  'Bleu': Color(0xFF1F4FB8),
  'Vert': Color(0xFF2F6B3E),
  'Jaune': Color(0xFFF2C200),
  'Orange': Color(0xFFF26A1B),
  'Violet': Color(0xFF6A3FA0),
  'Marron': Color(0xFF6B4226),
  'Beige': Color(0xFFD9C7A3),
};
