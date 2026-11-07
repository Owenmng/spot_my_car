// Fichier: lib/brand_detail_screen.dart (Version Finale Corrigée)
import 'package:flutter/material.dart';
import 'package:spot_my_car/brand_models_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spot_my_car/services/audio_service.dart';

class BrandDetailScreen extends StatelessWidget {
  final Map<String, dynamic> brand;

  const BrandDetailScreen({super.key, required this.brand});

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String label, String? value}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: Theme.of(context).primaryColor.withOpacity(0.7), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[800], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // === 1. ON AJOUTE BuildContext context EN PARAMÈTRE ========
  // ==========================================================
  Widget _buildStatCard(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty || value.contains("Non communiqué")) {
      return const Expanded(child: SizedBox.shrink());
    }
    return Expanded(
      child: Card(
        elevation: 0,
        color: Theme.of(context).primaryColor.withOpacity(0.05), // On utilise le thème ici aussi
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      // 'context' est maintenant connu, plus d'erreur !
                      color: Theme.of(context).primaryColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString != null) {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        print('Impossible de lancer $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final logoUrl = brand['logoUrl'] as String?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            // On ajoute le bouton de retour manuellement pour y mettre un son
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                Navigator.of(context).pop();
              },
            ),
            expandedHeight: 220.0,
            pinned: true,
            stretch: true,
            // L'AppBar prendra les couleurs du thème, pas besoin de spécifier
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                brand['name'] ?? 'Détails',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 2.0, color: Colors.black87)]),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [primaryColor.withOpacity(0.8), primaryColor],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50.0),
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white));
                            },
                            errorBuilder: (c, e, s) => const SizedBox.shrink(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ==========================================================
                      // === 2. ON PASSE LE context LORS DE L'APPEL ==============
                      // ==========================================================
                      _buildStatCard(context, 'Fondation', brand['annee_fondation']),
                      const SizedBox(width: 8),
                      _buildStatCard(context, 'Ventes / an', brand['ventes_annuelles']),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (brand['description'] != null &&
                      brand['description'].isNotEmpty) ...[
                    const Text('À propos de la marque',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const Divider(height: 16, thickness: 0.5),
                    Text(brand['description'],
                        style: const TextStyle(
                            fontSize: 16, height: 1.5, color: Colors.black87)),
                    const SizedBox(height: 24),
                  ],
                  const Text('Carte d\'identité',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Divider(height: 16, thickness: 0.5),
                  _buildInfoRow(context, icon: Icons.auto_awesome, label: 'Modèle Emblématique', value: brand['modele_emblematique']),
                  _buildInfoRow(context, icon: Icons.star_border_purple500_outlined, label: 'Fait Marquant', value: brand['fait_marquant']),
                  _buildInfoRow(context, icon: Icons.lightbulb_outline, label: 'Slogan', value: brand['slogan']),
                  _buildInfoRow(context, icon: Icons.business_outlined, label: 'Société Mère', value: brand['societe_mere']),
                  _buildInfoRow(context, icon: Icons.person_outline, label: 'Fondateur(s)', value: brand['fondateur']),
                  _buildInfoRow(context, icon: Icons.location_on_outlined, label: 'Siège Social', value: brand['siege_social']),
                  _buildInfoRow(context, icon: Icons.groups_outlined, label: 'Nombre d\'employés', value: brand['nombre_employes']),
                  _buildInfoRow(context, icon: Icons.euro_symbol_outlined, label: 'Chiffre d\'affaires', value: brand['chiffre_affaires']),
                  if (brand['site_officiel'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.public),
                          label: const Text('Visiter le site officiel'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(
                                  color: primaryColor.withOpacity(0.5))),
                          onPressed: () {
                            AudioService.instance.playSfx(SoundEffect.clicLeger); // <-- SON AJOUTÉ
                            _launchURL(brand['site_officiel']);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AudioService.instance.playSfx(SoundEffect.clicPrincipal); // <-- SON AJOUTÉ
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => BrandModelsScreen(brand: brand)));
        },
        label: const Text('Voir les modèles'),
        icon: const Icon(Icons.directions_car),
        // Le bouton prendra automatiquement les bonnes couleurs du thème
      ),
    );
  }
}