import 'package:flutter/material.dart';

class EmptyNotesState extends StatelessWidget {
  final String query;
  final VoidCallback onCreate;

  const EmptyNotesState({super.key, required this.query, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141B2D),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF27314A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF10182A),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.auto_awesome_mosaic,
                  size: 36,
                  color: Color(0xFF86E7C8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hasQuery ? 'No matching notes' : 'Your notes live here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                hasQuery
                    ? 'Try a different keyword or clear the search to see everything again.'
                    : 'Start a new note and keep track of ideas, project drafts, and quick thoughts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create note'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
