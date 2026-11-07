// Fichier: lib/info_page_screen.dart
import 'package:flutter/material.dart';

class InfoPageScreen extends StatelessWidget {
  final String title;
  final Widget content;

  const InfoPageScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: content,
      ),
    );
  }
}