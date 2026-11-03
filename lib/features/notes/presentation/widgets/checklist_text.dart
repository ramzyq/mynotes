import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Checklists in plain text: a line starting with "- [ ] " is an open item
/// and "- [x] " a done one. Stored as typed, so they survive export, older
/// app versions and other editors; this file only makes them nice to use.
final RegExp _itemLine = RegExp(r'^([ \t]*)- \[( |x|X)\] (.*)$', multiLine: true);

/// The range of the line containing [offset] in [text].
({int start, int end}) _lineAt(String text, int offset) {
  final o = offset.clamp(0, text.length);
  final start = o == 0 ? 0 : text.lastIndexOf('\n', o - 1) + 1;
  final nl = text.indexOf('\n', o);
  return (start: start, end: nl == -1 ? text.length : nl);
}

/// Note body controller: draws checklist markers quietly and done items
/// struck through, and can toggle items.
class NoteBodyController extends TextEditingController {
  NoteBodyController({super.text});

  Color mutedColor = Colors.grey;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // While the keyboard is composing a word, keep the default rendering so
    // the composing underline stays correct.
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final text = this.text;
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _itemLine.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final done = m.group(2)!.toLowerCase() == 'x';
      final markerEnd = m.start + m.group(1)!.length + 6; // "- [ ] "
      spans.add(TextSpan(
        text: text.substring(m.start, markerEnd),
        style: TextStyle(color: mutedColor, fontFamily: 'JetBrains Mono'),
      ));
      spans.add(TextSpan(
        text: text.substring(markerEnd, m.end),
        style: done ? TextStyle(color: mutedColor, decoration: TextDecoration.lineThrough, decorationColor: mutedColor) : null,
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }

  /// If [offset] is on the "- [ ]" marker of a checklist line, tick or untick
  /// it and return true. The caret stays where it was.
  bool toggleAt(int offset) {
    final line = _lineAt(text, offset);
    final m = _itemLine.firstMatch(text.substring(line.start, line.end));
    if (m == null) return false;
    final indent = m.group(1)!.length;
    final markerStart = line.start + indent;
    if (offset < line.start || offset > markerStart + 5) return false;
    final box = markerStart + 3; // the char inside [ ]
    final next = text[box] == ' ' ? 'x' : ' ';
    value = value.copyWith(
      text: text.replaceRange(box, box + 1, next),
      selection: TextSelection.collapsed(offset: line.end),
      composing: TextRange.empty,
    );
    return true;
  }

  /// Turn the line under the caret into a checklist item, or back.
  void toggleChecklistLine() {
    final caret = selection.isValid ? selection.baseOffset : text.length;
    final line = _lineAt(text, caret);
    final current = text.substring(line.start, line.end);
    final m = _itemLine.firstMatch(current);
    final String replaced;
    final int shift;
    if (m != null) {
      replaced = '${m.group(1)}${m.group(3)}';
      shift = -6;
    } else {
      replaced = '- [ ] $current';
      shift = 6;
    }
    value = value.copyWith(
      text: text.replaceRange(line.start, line.end, replaced),
      selection: TextSelection.collapsed(offset: (caret + shift).clamp(line.start, line.start + replaced.length)),
      composing: TextRange.empty,
    );
  }
}

/// Enter on a checklist item starts the next item; Enter on an empty item
/// ends the list.
class ChecklistContinuation extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final sel = newValue.selection;
    if (!sel.isValid || !sel.isCollapsed) return newValue;
    if (newValue.text.length != oldValue.text.length + 1) return newValue;
    final caret = sel.baseOffset;
    if (caret == 0 || newValue.text[caret - 1] != '\n') return newValue;
    // The inserted char must be that newline (not a paste ending in one).
    if (oldValue.text != newValue.text.replaceRange(caret - 1, caret, '')) return newValue;

    final prev = _lineAt(newValue.text, caret - 1);
    final m = _itemLine.firstMatch(newValue.text.substring(prev.start, prev.end));
    if (m == null) return newValue;

    if (m.group(3)!.trim().isEmpty) {
      // Empty item: remove its marker and the new line break.
      final text = newValue.text.replaceRange(prev.start, caret, '');
      return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: prev.start));
    }
    final marker = '${m.group(1)}- [ ] ';
    final text = newValue.text.replaceRange(caret, caret, marker);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret + marker.length));
  }
}
