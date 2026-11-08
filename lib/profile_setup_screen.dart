import 'package:spot_my_car/l10n/i18n.dart';
import 'package:spot_my_car/theme/app_theme.dart';
import 'package:spot_my_car/widgets/language_picker.dart';
// Fichier: lib/profile_setup_screen.dart (VERSION COMPLÈTE ET CORRIGÉE)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:spot_my_car/brand_selection.dart';
import 'dart:convert';
import 'package:spot_my_car/date_input_formatter.dart'; // Import du nouveau formateur
import 'package:spot_my_car/services/audio_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? initialUserData;
  const ProfileSetupScreen({super.key, this.initialUserData});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialUserData != null) {
      _pseudoController.text = widget.initialUserData!['pseudo'] ?? '';
      _firstNameController.text = widget.initialUserData!['firstName'] ?? '';
      _lastNameController.text = widget.initialUserData!['lastName'] ?? '';
      _dobController.text = widget.initialUserData!['dateOfBirth'] ?? '';
      final favoriteBrandId = widget.initialUserData!['favoriteBrandId'];
      if (favoriteBrandId != null) {
        _loadInitialBrand(favoriteBrandId);
      }
    }
  }

  Future<void> _loadInitialBrand(String brandId) async {
    final response = await rootBundle.loadString('assets/data/brands.json');
    final data = json.decode(response);
    final allBrands = data['brands'] as List;
    final brand = allBrands.firstWhere((b) => b['id'] == brandId, orElse: () => null);
    if (brand != null && mounted) {
      setState(() {
        _selectedBrand = brand;
        _favoriteBrandController.text = brand['name'];
      });
    }
  }

  final _pseudoController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _favoriteBrandController = TextEditingController();

  Map<String, dynamic>? _selectedBrand;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: I18n.instance.locale,
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _selectFavoriteBrand() async {
    final selectedBrand = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const BrandSelection()),
    );
    if (selectedBrand != null && mounted) {
      setState(() {
        _selectedBrand = selectedBrand;
        _favoriteBrandController.text = selectedBrand['name'];
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isLoading = false; });
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pseudo': _pseudoController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'favoriteBrandId': _selectedBrand?['id'],
        'stats.favoriteBrandName': _selectedBrand?['name'],
        'stats.favoriteBrandLogoUrl': _selectedBrand?['logoUrl'],
        'profileCompleted': true,
      }, SetOptions(merge: true));

      await user.updateDisplayName('${_firstNameController.text.trim()} ${_lastNameController.text.trim()}');
      
      // On affiche un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Profil mis à jour !')), backgroundColor: Colors.green),
        );
        // Et on ferme la page
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Une erreur est survenue.')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _favoriteBrandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialUserData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? tr('Modifier le profil') : ''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AudioService.instance.playSfx(SoundEffect.clicLeger);
            if (isEditing) {
              Navigator.of(context).pop();
            } else {
              showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(tr('Quitter la configuration ?')),
                  content: Text(tr('Si vous quittez maintenant, votre compte sera créé mais votre profil ne sera pas finalisé. Vous devrez vous reconnecter pour le compléter.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Rester'))),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        FirebaseAuth.instance.signOut();
                      },
                      child: Text(tr('Quitter'), style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEditing ? tr('Mon profil') : tr('Dernière ligne droite'), style: AppText.display(34)),
                  const SizedBox(height: 8),
                  Text(
                    isEditing ? tr('Mets à jour tes infos de spotter.') : tr('Choisis ton pseudo : c’est lui qui apparaîtra au classement.'),
                    style: AppText.body(15, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 22),
                  if (!isEditing) ...[
                    Text(tr('LANGUE DE L’APPLI'), style: AppText.label(11.5, color: AppColors.inkMuted)),
                    const SizedBox(height: 10),
                    const LanguageGrid(),
                    const SizedBox(height: 26),
                  ],

                  TextFormField(
                      controller: _pseudoController,
                      maxLength: 20,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: tr('Pseudo'), prefixIcon: Icon(Icons.badge_outlined), counterText: ''),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('Le pseudo est obligatoire')
                          : null),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: TextFormField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(labelText: tr('Prénom')),
                              validator: (value) => value == null || value.isEmpty
                                  ? tr('Le prénom est obligatoire')
                                  : null)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(labelText: tr('Nom')),
                              validator: (value) => value == null || value.isEmpty
                                  ? tr('Le nom est obligatoire')
                                  : null)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // === LE CHAMP DE DATE CORRIGÉ ===
                  TextFormField(
                      controller: _dobController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        DateInputFormatter(),
                      ],
                      decoration: InputDecoration(
                          labelText: tr('Date de naissance'),
                          hintText: tr('JJ/MM/AAAA'),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: () {
                                AudioService.instance.playSfx(SoundEffect.clicLeger);
                                _selectDate(context);
                              })),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 10) {
                          return tr('Date incomplète');
                        }
                        try {
                          if (value != null && value.isNotEmpty) {
                            DateFormat('dd/MM/yyyy').parseStrict(value);
                            final parts = value.split('/');
                            final year = int.parse(parts[2]);
                            final now = DateTime.now();
                            if (year < now.year - 100 || year > now.year) {
                              return tr('Année invalide');
                            }
                          }
                        } catch (e) {
                          return tr('Date invalide');
                        }
                        return null; // Pas d'erreur
                      },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                      controller: _favoriteBrandController,
                      readOnly: true,
                      onTap: () {
                        AudioService.instance.playSfx(SoundEffect.clicLeger);
                        _selectFavoriteBrand();
                      },
                      decoration: InputDecoration(
                          labelText: tr('Marque de voiture préférée'),
                          hintText: tr('Appuie pour choisir'),
                          suffixIcon: Icon(Icons.arrow_drop_down)),
                      validator: (value) => value == null || value.isEmpty
                          ? tr('Choisis une marque')
                          : null),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () {
                            // On vérifie si le formulaire est valide avant de jouer le son
                            if (_formKey.currentState!.validate()) {
                               AudioService.instance.playSfx(SoundEffect.clicPrincipal);
                               _saveProfile();
                            } else {
                               AudioService.instance.playSfx(SoundEffect.clicLeger); // Son d'erreur
                            }
                          },
                          child: Text(isEditing ? tr('Enregistrer') : tr('C’est parti'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}