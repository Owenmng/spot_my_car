import 'package:spot_my_car/theme/app_theme.dart';
// Fichier: lib/contact_support_screen.dart
import 'package:flutter/material.dart';
import 'package:spot_my_car/shared/app_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // On récupère l'email de l'utilisateur connecté pour savoir qui envoie le message
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'utilisateur-non-identifie@app.com';
    final userPseudo = FirebaseAuth.instance.currentUser?.displayName ?? 'Pseudo inconnu';

    try {
      // On écrit dans la collection 'mail' (le nom par défaut de l'extension)
      await FirebaseFirestore.instance.collection('mail').add({
        'to': [AppConstants.supportEmail],
        'replyTo': userEmail, // <-- CORRIGÉ : On envoie une simple chaîne de caractères
        'message': {
          'subject': '[Support SpotMyCar] - ${_subjectController.text.trim()}',
          'html': """
            <h3>Nouveau message de support</h3>
            <p><strong>Utilisateur :</strong> ${userPseudo} (${userEmail})</p>
            <hr>
            <p><strong>Message :</strong></p>
            <p>${_bodyController.text.trim()}</p>
          """,
        },
      });

      if (mounted) {
        Navigator.pop(context); // On ferme la page de contact
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre message a bien été envoyé. Nous vous répondrons rapidement !'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi du message : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacter le support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: _sendEmail,
            tooltip: 'Envoyer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nous sommes là pour vous aider. Décrivez votre problème ou votre question ci-dessous.',
                style: TextStyle(fontSize: 16, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Objet',
                  hintText: 'Ex: Problème de connexion',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.subject),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un objet.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: 'Votre message',
                  hintText: 'Bonjour, je rencontre un problème avec...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true, // Pour que le label soit en haut
                ),
                maxLines: 10,
                minLines: 5,
                validator: (value) => value == null || value.isEmpty ? 'Veuillez écrire un message.' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined),
                label: const Text('Envoyer le message'),
                onPressed: _sendEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}