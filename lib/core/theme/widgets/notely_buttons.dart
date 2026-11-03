import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';

/// Full-width primary action: ink fill, 48 tall, spinner while [loading].
class NotelyPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool danger;

  const NotelyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? notely.bg : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: danger ? notely.danger : notely.violet,
          foregroundColor: fg,
          disabledBackgroundColor: (danger ? notely.danger : notely.violet).withValues(alpha: loading ? 0.85 : 0.4),
          disabledForegroundColor: fg,
        ),
        child: loading
            ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Full-width secondary action: surface with a hairline.
class NotelySecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  const NotelySecondaryButton({super.key, required this.label, required this.onPressed, this.leading});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: notely.surface,
          foregroundColor: notely.text,
          side: BorderSide(color: notely.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w500),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// A password field with a show/hide toggle.
class NotelyPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String>? autofillHints;

  const NotelyPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  @override
  State<NotelyPasswordField> createState() => _NotelyPasswordFieldState();
}

class _NotelyPasswordFieldState extends State<NotelyPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: notely.text3),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Plain page with a back button and a quiet title, on the paper background.
class NotelyPage extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;

  const NotelyPage({super.key, this.title, required this.body, this.actions, this.showBack = true, this.bottom});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Scaffold(
      backgroundColor: notely.bg,
      appBar: AppBar(
        backgroundColor: notely.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: showBack && Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        titleSpacing: showBack && Navigator.of(context).canPop() ? 0 : 20,
        title: title == null ? null : Text(title!),
        actions: actions,
      ),
      bottomNavigationBar: bottom,
      body: body,
    );
  }
}

/// Serif page heading with an optional supporting line.
class NotelyHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const NotelyHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notely = NotelyTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.displayMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: TextStyle(fontFamily: 'Geist', fontSize: 15, height: 1.5, color: notely.text2)),
        ],
      ],
    );
  }
}
