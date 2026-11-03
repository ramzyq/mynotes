import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/features/notes/presentation/widgets/checklist_text.dart';

TextEditingValue _v(String text, int caret) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));

void main() {
  group('NoteBodyController', () {
    test('tapping the marker ticks and unticks an item', () {
      final c = NoteBodyController(text: 'Shopping\n- [ ] eggs\n- [x] milk');
      expect(c.toggleAt(10), isTrue); // on "- [ ]" of eggs
      expect(c.text, 'Shopping\n- [x] eggs\n- [x] milk');
      expect(c.toggleAt(23), isTrue); // on milk's marker
      expect(c.text, 'Shopping\n- [x] eggs\n- [ ] milk');
    });

    test('tapping the item text or a plain line does nothing', () {
      final c = NoteBodyController(text: 'Shopping\n- [ ] eggs');
      expect(c.toggleAt(17), isFalse); // inside "eggs"
      expect(c.toggleAt(3), isFalse); // plain line
      expect(c.text, 'Shopping\n- [ ] eggs');
    });

    test('toggleChecklistLine adds and removes the marker', () {
      final c = NoteBodyController(text: 'eggs')..selection = const TextSelection.collapsed(offset: 4);
      c.toggleChecklistLine();
      expect(c.text, '- [ ] eggs');
      expect(c.selection.baseOffset, 10);
      c.toggleChecklistLine();
      expect(c.text, 'eggs');
    });
  });

  group('ChecklistContinuation', () {
    final f = ChecklistContinuation();

    test('Enter after an item starts the next one', () {
      final out = f.formatEditUpdate(_v('- [ ] eggs', 10), _v('- [ ] eggs\n', 11));
      expect(out.text, '- [ ] eggs\n- [ ] ');
      expect(out.selection.baseOffset, 17);
    });

    test('keeps indentation', () {
      final out = f.formatEditUpdate(_v('  - [x] eggs', 12), _v('  - [x] eggs\n', 13));
      expect(out.text, '  - [x] eggs\n  - [ ] ');
    });

    test('Enter on an empty item ends the list', () {
      final out = f.formatEditUpdate(_v('- [ ] eggs\n- [ ] ', 17), _v('- [ ] eggs\n- [ ] \n', 18));
      expect(out.text, '- [ ] eggs\n');
      expect(out.selection.baseOffset, 11);
    });

    test('leaves ordinary lines alone', () {
      final out = f.formatEditUpdate(_v('hello', 5), _v('hello\n', 6));
      expect(out.text, 'hello\n');
    });
  });

  test('Note reports checklist progress and previews items without markers', () {
    final note = Note(
      id: 'n',
      title: 'Trip',
      content: 'Pack\n- [x] passport\n- [ ] charger\n- [ ] socks',
      colorIndex: 0,
      isPinned: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(note.checklist, (done: 1, total: 3));
    expect(note.previewText, 'Pack passport charger socks');
  });
}
