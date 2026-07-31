import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/db/app_database.dart';

void main() {
  test('index and search note by title', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.indexNote(
      noteId: 'note-1',
      ownerId: 'user-1',
      title: 'Shopping List',
      content: 'Milk, eggs, bread',
    );
    await db.indexNote(
      noteId: 'note-2',
      ownerId: 'user-1',
      title: 'Work Notes',
      content: 'Meeting at 3pm',
    );

    final results = await db.searchNotes('user-1', 'shopping');

    expect(results, contains('note-1'));
    expect(results, isNot(contains('note-2')));
    await db.close();
  });

  test('search scoped to owner', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.indexNote(
      noteId: 'note-1',
      ownerId: 'user-1',
      title: 'Shared Note',
      content: 'Hello',
    );
    await db.indexNote(
      noteId: 'note-2',
      ownerId: 'user-2',
      title: 'Shared Note',
      content: 'Hello',
    );

    final user1Results = await db.searchNotes('user-1', 'shared');
    final user2Results = await db.searchNotes('user-2', 'shared');

    expect(user1Results, contains('note-1'));
    expect(user2Results, contains('note-2'));
    expect(user2Results, isNot(contains('note-1')));
    await db.close();
  });

  test('removing index removes from search results', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.indexNote(noteId: 'note-1', ownerId: 'user-1', title: 'Temporary', content: 'Will be deleted');
    await db.removeNoteIndex('note-1');

    final results = await db.searchNotes('user-1', 'temporary');

    expect(results, isEmpty);
    await db.close();
  });
}
