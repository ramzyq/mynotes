import 'package:drift/drift.dart';

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get encryptedContent => text()();
  TextColumn get encryptedTitle => text()();
  TextColumn get plaintextContent => text().nullable()();
  TextColumn get plaintextTitle => text().nullable()();
  IntColumn get colorIndex => integer()();
  BoolColumn get isPinned => boolean()();
  BoolColumn get isLocked => boolean()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get pinSalt => text().nullable()();
  BoolColumn get localOnly => boolean()();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteFts extends Table {
  TextColumn get noteId => text()();
  TextColumn get ownerId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();

  @override
  Set<Column>? get primaryKey => {noteId};

  String get createTable => '''
    CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
      note_id UNINDEXED,
      owner_id UNINDEXED,
      title,
      content,
      tokenize='porter unicode61'
    )
  ''';
}
