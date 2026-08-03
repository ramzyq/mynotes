import 'package:flutter/material.dart';

/// Friendly full-screen error shown when app bootstrap fails, with a retry
/// action instead of a silent crash.
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFF)),
        scaffoldBackgroundColor: const Color(0xFF121214),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: Color(0xFF7C5CFF),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "We couldn't connect",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEDEDEF),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Something went wrong while starting Notely. '
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9BA1AD),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7078),
                          ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
