import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mynotes/core/config/app_config.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';

/// About Notely, and credit for the artwork and fonts it uses.
class CreditsView extends StatelessWidget {
  const CreditsView({super.key});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final heading = TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: notely.text3);
    final body = TextStyle(fontFamily: 'Geist', fontSize: 15, height: 1.5, color: notely.text);
    return Scaffold(
      appBar: AppBar(title: const Text('About & credits')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Center(child: NotelyMark(size: 96)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Notely',
              style: TextStyle(
                fontFamily: 'Instrument Serif',
                fontStyle: FontStyle.italic,
                fontSize: 36,
                color: notely.text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Notes encrypted on your device.',
              style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: notely.text2),
            ),
          ),
          const SizedBox(height: 32),
          Text('Artwork', style: heading),
          const SizedBox(height: 6),
          GestureDetector(
            onLongPress: () => Clipboard.setData(const ClipboardData(text: iconAttribution)),
            child: Text('$iconAttribution
$iconAttributionUrl', style: body),
          ),
          const SizedBox(height: 24),
          Text('Fonts', style: heading),
          const SizedBox(height: 6),
          Text('Geist, Instrument Serif and JetBrains Mono, used under the SIL Open Font License.', style: body),
        ],
      ),
    );
  }
}
