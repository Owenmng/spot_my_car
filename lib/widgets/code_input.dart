import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spot_my_car/theme/app_theme.dart';

/// Saisie d'un code à 6 chiffres : une case par chiffre, collage et remplissage automatique gérés.
class CodeInput extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int length;

  const CodeInput({super.key, required this.onCompleted, this.onChanged, this.enabled = true, this.length = 6});

  @override
  State<CodeInput> createState() => CodeInputState();
}

class CodeInputState extends State<CodeInput> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _error = false;

  String get value => _ctrl.text;

  void clear({bool error = false}) {
    _ctrl.clear();
    setState(() => _error = error);
    if (error) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    _focus.requestFocus();
  }

  void focus() => _focus.requestFocus();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _changed(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits != v) {
      _ctrl.value = TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
    }
    if (_error) setState(() => _error = false);
    setState(() {});
    widget.onChanged?.call(digits);
    if (digits.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted(digits);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final text = _ctrl.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(sin(_shake.value * pi * 5) * 10 * (1 - _shake.value), 0),
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 64,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
                  onChanged: _changed,
                  showCursor: false,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i == widget.length / 2) const SizedBox(width: 10),
                    _box(i < text.length ? text[i] : '', active: _focus.hasFocus && i == min(text.length, widget.length - 1), filled: i < text.length, accent: accent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String d, {required bool active, required bool filled, required Color accent}) {
    final border = _error
        ? AppColors.danger
        : active
            ? accent
            : filled
                ? AppColors.inkMuted
                : AppColors.line;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 46,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: active || _error ? 2 : 1.4),
        boxShadow: active ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 14)] : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Text(d, key: ValueKey(d), style: AppText.mono(26, color: _error ? AppColors.danger : AppColors.ink)),
      ),
    );
  }
}
