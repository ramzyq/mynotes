import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';

/// What to tell the user when data could not be loaded.
String loadErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return "You're offline or the connection dropped. Notes you've opened before stay available.";
      case 'permission-denied':
      case 'unauthenticated':
        return 'Your session may have expired. Sign out and back in.';
      case 'failed-precondition':
        return 'Notely is being updated. Try again in a few minutes.';
    }
  }
  if (error is TimeoutException) return 'This is taking too long. Check your connection.';
  return 'Something went wrong while loading.';
}

/// Centered progress indicator for a first load.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(label!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
        ],
      ]),
    );
  }
}

/// Full-area error with a retry button, for when nothing could be shown.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.title, required this.error, this.onRetry});
  final String title;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 28, color: notely.text3),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                loadErrorMessage(error),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Geist', fontSize: 14, height: 1.45, color: notely.text2),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              // A cap, not a fixed width, so large accessibility text still fits.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: NotelySecondaryButton(label: 'Try again', onPressed: onRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A one-line notice that part of the screen failed, while the rest shows.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.error_outline, size: 16, color: notely.text2),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(message, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text2)),
          ),
        ),
        if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

/// Shows [data] once a value exists (also while it refreshes or after a
/// later error, so a hiccup never blanks a screen that has content), a
/// spinner before the first value, and [ErrorState] if the first load fails.
/// Never shows "empty" for "not loaded yet".
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    required this.errorTitle,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final String errorTitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) return ErrorState(title: errorTitle, error: value.error!, onRetry: onRetry);
    return const LoadingState();
  }
}
