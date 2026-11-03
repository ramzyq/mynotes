import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';

/// Friendly full-screen error shown when app bootstrap fails, with a retry
/// action instead of a silent crash. Runs before the main app exists, so it
/// brings its own MaterialApp with the Notely theme.
class BootstrapErrorView extends StatelessWidget {
  final String? message;
  final Future<void> Function() onRetry;

  const BootstrapErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notely',
      theme: buildNotelyTheme(Brightness.light),
      darkTheme: buildNotelyTheme(Brightness.dark),
      home: Builder(
        builder: (context) {
          final notely = NotelyTheme.of(context);
          return Scaffold(
            backgroundColor: notely.bg,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: notely.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: notely.border),
                            ),
                            child: Icon(Icons.cloud_off_outlined, size: 22, color: notely.violet),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const NotelyHeading(
                          title: "Notely couldn't start",
                          subtitle: 'Check your connection and try again. Your notes are safe; nothing was changed.',
                        ),
                        const SizedBox(height: 32),
                        NotelyPrimaryButton(label: 'Try again', icon: Icons.refresh, onPressed: onRetry),
                        if (message != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            message!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: notely.text3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
