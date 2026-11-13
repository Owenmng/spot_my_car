import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/services/remote_config_service.dart';
import 'package:spot_my_car/shared/app_constants.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openPlayStore() async {
  final market = Uri.parse(AppConstants.playStoreMarket);
  if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
    await launchUrl(Uri.parse(AppConstants.playStoreUrl), mode: LaunchMode.externalApplication);
  }
}

class _FullMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const _FullMessage({required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: const Alignment(0, -0.6), radius: 1.1, colors: [accent.withValues(alpha: 0.22), AppColors.paper]),
        ),
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 72),
              const SizedBox(height: 30),
              Icon(icon, size: 46, color: accent).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.03, end: 0.03, duration: 1200.ms),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: AppText.display(32)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: AppText.body(15.5, color: AppColors.inkSoft)),
              if (action != null) ...[const SizedBox(height: 28), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});
  @override
  Widget build(BuildContext context) => _FullMessage(
        icon: Icons.build_circle_outlined,
        title: tr('Au stand !'),
        message: RemoteConfig.instance.maintenanceMessage,
      );
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) => _FullMessage(
        icon: Icons.system_update_rounded,
        title: tr('Mise à jour nécessaire'),
        message: RemoteConfig.instance.updateMessage,
        action: ElevatedButton.icon(
          onPressed: openPlayStore,
          icon: const Icon(Icons.shop_rounded),
          label: Text(tr('Mettre à jour')),
          style: ElevatedButton.styleFrom(minimumSize: const Size(220, 52)),
        ),
      );
}

/// Bandeau d'annonce envoyé depuis la console (fermable, une fois par annonce).
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});
  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _dismissed = (p.getStringList('dismissed_announcements') ?? []).toSet());
    });
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed.add(id));
    final p = await SharedPreferences.getInstance();
    await p.setStringList('dismissed_announcements', _dismissed.toList());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfig.instance,
      builder: (context, _) {
        final rc = RemoteConfig.instance;
        String? text;
        String id = '';
        String level = rc.announcementLevel;
        VoidCallback? onTap;
        if (rc.announcement.isNotEmpty && !_dismissed.contains('a${rc.announcementId}')) {
          text = rc.announcement;
          id = 'a${rc.announcementId}';
        } else if (rc.canUpdate && !_dismissed.contains('u${rc.latestVersion}')) {
          text = rc.updateMessage;
          id = 'u${rc.latestVersion}';
          level = 'success';
          onTap = openPlayStore;
        }
        if (text == null) return const SizedBox.shrink();
        final color = level == 'warning' ? AppColors.warning : level == 'success' ? AppColors.success : Theme.of(context).colorScheme.primary;
        final icon = level == 'warning' ? Icons.warning_amber_rounded : level == 'success' ? Icons.celebration_rounded : Icons.campaign_rounded;
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Material(
              color: AppColors.panelHi,
              borderRadius: BorderRadius.circular(AppRadius.md),
              elevation: 8,
              shadowColor: Colors.black54,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(text, style: AppText.body(13.5, weight: FontWeight.w600))),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded, size: 18, color: AppColors.inkSoft),
                        onPressed: () => _dismiss(id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: -1.2, end: 0, duration: 450.ms, curve: Curves.easeOutCubic),
        );
      },
    );
  }
}
