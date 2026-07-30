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
