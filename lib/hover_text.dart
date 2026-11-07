// Fichier: lib/hover_text.dart

import 'package:flutter/material.dart';

class HoverUnderlineText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const HoverUnderlineText({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  State<HoverUnderlineText> createState() => _HoverUnderlineTextState();
}

class _HoverUnderlineTextState extends State<HoverUnderlineText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Colors.blue,
          ),
        ),
      ),
    );
  }
}