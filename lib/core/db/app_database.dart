import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalNotes, NoteFts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(localNotes);
      await customStatement('CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(note_id UNINDEXED, owner_id UNINDEXED, title, content, tokenize=\'porter unicode61\')');
    },
    beforeOpen: (details) async {
      await customStatement('CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(note_id UNINDEXED, owner_id UNINDEXED, title, content, tokenize=\'porter unicode61\')');
    },
  );

  Future<void> indexNote({required String noteId, required String ownerId, required String title, required String content}) async {
    await customInsert(
      'INSERT OR REPLACE INTO note_fts (note_id, owner_id, title, content) VALUES (?, ?, ?, ?)',
      variables: [Variable<String>(noteId), Variable<String>(ownerId), Variable<String>(title), Variable<String>(content)],
    );
  }

  Future<void> removeNoteIndex(String noteId) async {
    await customUpdate(
      'DELETE FROM note_fts WHERE note_id = ?',
      variables: [Variable<String>(noteId)],
    );
  }

  Future<List<String>> searchNotes(String ownerId, String query) async {
    final result = await customSelect(
      'SELECT note_id FROM note_fts WHERE owner_id = ? AND note_fts MATCH ?',
      variables: [Variable<String>(ownerId), Variable<String>(query)],
    ).get();
    return result.map((row) => row.data['note_id'] as String).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'mynotes.sqlite'));
    return NativeDatabase(file);
  });
}
