import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';

/// The compact brand lockup for headers: the Notely mark beside the name, in
/// the same logo and serif italic as the splash, welcome and credits screens.
class NotelyWordmark extends StatelessWidget {
  final double size;

  const NotelyWordmark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The name beside the mark already announces "Notely".
        ExcludeSemantics(child: NotelyMark(size: size * 1.6)),
        const SizedBox(width: 8),
        Text(
          'Notely',
          style: TextStyle(
            fontFamily: 'Instrument Serif',
            fontStyle: FontStyle.italic,
            fontSize: size * 1.45,
            height: 1,
            color: notely.text,
          ),
        ),
      ],
    );
  }
}
