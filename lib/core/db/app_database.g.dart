// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedContentMeta = const VerificationMeta(
    'encryptedContent',
  );
  @override
  late final GeneratedColumn<String> encryptedContent = GeneratedColumn<String>(
    'encrypted_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedTitleMeta = const VerificationMeta(
    'encryptedTitle',
  );
  @override
  late final GeneratedColumn<String> encryptedTitle = GeneratedColumn<String>(
    'encrypted_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plaintextContentMeta = const VerificationMeta(
    'plaintextContent',
  );
  @override
  late final GeneratedColumn<String> plaintextContent = GeneratedColumn<String>(
    'plaintext_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plaintextTitleMeta = const VerificationMeta(
    'plaintextTitle',
  );
  @override
  late final GeneratedColumn<String> plaintextTitle = GeneratedColumn<String>(
    'plaintext_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinSaltMeta = const VerificationMeta(
    'pinSalt',
  );
  @override
  late final GeneratedColumn<String> pinSalt = GeneratedColumn<String>(
    'pin_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localOnlyMeta = const VerificationMeta(
    'localOnly',
  );
  @override
  late final GeneratedColumn<bool> localOnly = GeneratedColumn<bool>(
    'local_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_only" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    encryptedContent,
    encryptedTitle,
    plaintextContent,
    plaintextTitle,
    colorIndex,
    isPinned,
    isLocked,
    pinHash,
    pinSalt,
    localOnly,
    tags,
    createdAt,
    updatedAt,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('encrypted_content')) {
      context.handle(
        _encryptedContentMeta,
        encryptedContent.isAcceptableOrUnknown(
          data['encrypted_content']!,
          _encryptedContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedContentMeta);
    }
    if (data.containsKey('encrypted_title')) {
      context.handle(
        _encryptedTitleMeta,
        encryptedTitle.isAcceptableOrUnknown(
          data['encrypted_title']!,
          _encryptedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedTitleMeta);
    }
    if (data.containsKey('plaintext_content')) {
      context.handle(
        _plaintextContentMeta,
        plaintextContent.isAcceptableOrUnknown(
          data['plaintext_content']!,
          _plaintextContentMeta,
        ),
      );
    }
    if (data.containsKey('plaintext_title')) {
      context.handle(
        _plaintextTitleMeta,
        plaintextTitle.isAcceptableOrUnknown(
          data['plaintext_title']!,
          _plaintextTitleMeta,
        ),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    } else if (isInserting) {
      context.missing(_isPinnedMeta);
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    } else if (isInserting) {
      context.missing(_isLockedMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('pin_salt')) {
      context.handle(
        _pinSaltMeta,
        pinSalt.isAcceptableOrUnknown(data['pin_salt']!, _pinSaltMeta),
      );
    }
    if (data.containsKey('local_only')) {
      context.handle(
        _localOnlyMeta,
        localOnly.isAcceptableOrUnknown(data['local_only']!, _localOnlyMeta),
      );
    } else if (isInserting) {
      context.missing(_localOnlyMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    } else if (isInserting) {
      context.missing(_isSyncedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      encryptedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_content'],
      )!,
      encryptedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_title'],
      )!,
      plaintextContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plaintext_content'],
      ),
      plaintextTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plaintext_title'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      pinSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_salt'],
      ),
      localOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_only'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String ownerId;
  final String encryptedContent;
  final String encryptedTitle;
  final String? plaintextContent;
  final String? plaintextTitle;
  final int colorIndex;
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;
  final String? pinSalt;
  final bool localOnly;
  final String? tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  const LocalNote({
    required this.id,
    required this.ownerId,
    required this.encryptedContent,
    required this.encryptedTitle,
    this.plaintextContent,
    this.plaintextTitle,
    required this.colorIndex,
    required this.isPinned,
    required this.isLocked,
    this.pinHash,
    this.pinSalt,
    required this.localOnly,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['encrypted_content'] = Variable<String>(encryptedContent);
    map['encrypted_title'] = Variable<String>(encryptedTitle);
    if (!nullToAbsent || plaintextContent != null) {
      map['plaintext_content'] = Variable<String>(plaintextContent);
    }
    if (!nullToAbsent || plaintextTitle != null) {
      map['plaintext_title'] = Variable<String>(plaintextTitle);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_locked'] = Variable<bool>(isLocked);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    if (!nullToAbsent || pinSalt != null) {
      map['pin_salt'] = Variable<String>(pinSalt);
    }
    map['local_only'] = Variable<bool>(localOnly);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      encryptedContent: Value(encryptedContent),
      encryptedTitle: Value(encryptedTitle),
      plaintextContent: plaintextContent == null && nullToAbsent
          ? const Value.absent()
          : Value(plaintextContent),
      plaintextTitle: plaintextTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(plaintextTitle),
      colorIndex: Value(colorIndex),
      isPinned: Value(isPinned),
      isLocked: Value(isLocked),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      pinSalt: pinSalt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinSalt),
      localOnly: Value(localOnly),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      encryptedContent: serializer.fromJson<String>(json['encryptedContent']),
      encryptedTitle: serializer.fromJson<String>(json['encryptedTitle']),
      plaintextContent: serializer.fromJson<String?>(json['plaintextContent']),
      plaintextTitle: serializer.fromJson<String?>(json['plaintextTitle']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      pinSalt: serializer.fromJson<String?>(json['pinSalt']),
      localOnly: serializer.fromJson<bool>(json['localOnly']),
      tags: serializer.fromJson<String?>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'encryptedContent': serializer.toJson<String>(encryptedContent),
      'encryptedTitle': serializer.toJson<String>(encryptedTitle),
      'plaintextContent': serializer.toJson<String?>(plaintextContent),
      'plaintextTitle': serializer.toJson<String?>(plaintextTitle),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isLocked': serializer.toJson<bool>(isLocked),
      'pinHash': serializer.toJson<String?>(pinHash),
      'pinSalt': serializer.toJson<String?>(pinSalt),
      'localOnly': serializer.toJson<bool>(localOnly),
      'tags': serializer.toJson<String?>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  LocalNote copyWith({
    String? id,
    String? ownerId,
    String? encryptedContent,
    String? encryptedTitle,
    Value<String?> plaintextContent = const Value.absent(),
    Value<String?> plaintextTitle = const Value.absent(),
    int? colorIndex,
    bool? isPinned,
    bool? isLocked,
    Value<String?> pinHash = const Value.absent(),
    Value<String?> pinSalt = const Value.absent(),
    bool? localOnly,
    Value<String?> tags = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) => LocalNote(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    encryptedContent: encryptedContent ?? this.encryptedContent,
    encryptedTitle: encryptedTitle ?? this.encryptedTitle,
    plaintextContent: plaintextContent.present
        ? plaintextContent.value
        : this.plaintextContent,
    plaintextTitle: plaintextTitle.present
        ? plaintextTitle.value
        : this.plaintextTitle,
    colorIndex: colorIndex ?? this.colorIndex,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    pinSalt: pinSalt.present ? pinSalt.value : this.pinSalt,
    localOnly: localOnly ?? this.localOnly,
    tags: tags.present ? tags.value : this.tags,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      encryptedContent: data.encryptedContent.present
          ? data.encryptedContent.value
          : this.encryptedContent,
      encryptedTitle: data.encryptedTitle.present
          ? data.encryptedTitle.value
          : this.encryptedTitle,
      plaintextContent: data.plaintextContent.present
          ? data.plaintextContent.value
          : this.plaintextContent,
      plaintextTitle: data.plaintextTitle.present
          ? data.plaintextTitle.value
          : this.plaintextTitle,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinSalt: data.pinSalt.present ? data.pinSalt.value : this.pinSalt,
      localOnly: data.localOnly.present ? data.localOnly.value : this.localOnly,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('encryptedTitle: $encryptedTitle, ')
          ..write('plaintextContent: $plaintextContent, ')
          ..write('plaintextTitle: $plaintextTitle, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('isPinned: $isPinned, ')
          ..write('isLocked: $isLocked, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('localOnly: $localOnly, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    encryptedContent,
    encryptedTitle,
    plaintextContent,
    plaintextTitle,
    colorIndex,
    isPinned,
    isLocked,
    pinHash,
    pinSalt,
    localOnly,
    tags,
    createdAt,
    updatedAt,
    isSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.encryptedContent == this.encryptedContent &&
          other.encryptedTitle == this.encryptedTitle &&
          other.plaintextContent == this.plaintextContent &&
          other.plaintextTitle == this.plaintextTitle &&
          other.colorIndex == this.colorIndex &&
          other.isPinned == this.isPinned &&
          other.isLocked == this.isLocked &&
          other.pinHash == this.pinHash &&
          other.pinSalt == this.pinSalt &&
          other.localOnly == this.localOnly &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> encryptedContent;
  final Value<String> encryptedTitle;
  final Value<String?> plaintextContent;
  final Value<String?> plaintextTitle;
  final Value<int> colorIndex;
  final Value<bool> isPinned;
  final Value<bool> isLocked;
  final Value<String?> pinHash;
  final Value<String?> pinSalt;
  final Value<bool> localOnly;
  final Value<String?> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.encryptedContent = const Value.absent(),
    this.encryptedTitle = const Value.absent(),
    this.plaintextContent = const Value.absent(),
    this.plaintextTitle = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.localOnly = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    required String ownerId,
    required String encryptedContent,
    required String encryptedTitle,
    this.plaintextContent = const Value.absent(),
    this.plaintextTitle = const Value.absent(),
    required int colorIndex,
    required bool isPinned,
    required bool isLocked,
    this.pinHash = const Value.absent(),
    this.pinSalt = const Value.absent(),
    required bool localOnly,
    this.tags = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isSynced,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       encryptedContent = Value(encryptedContent),
       encryptedTitle = Value(encryptedTitle),
       colorIndex = Value(colorIndex),
       isPinned = Value(isPinned),
       isLocked = Value(isLocked),
       localOnly = Value(localOnly),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       isSynced = Value(isSynced);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? encryptedContent,
    Expression<String>? encryptedTitle,
    Expression<String>? plaintextContent,
    Expression<String>? plaintextTitle,
    Expression<int>? colorIndex,
    Expression<bool>? isPinned,
    Expression<bool>? isLocked,
    Expression<String>? pinHash,
    Expression<String>? pinSalt,
    Expression<bool>? localOnly,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (encryptedContent != null) 'encrypted_content': encryptedContent,
      if (encryptedTitle != null) 'encrypted_title': encryptedTitle,
      if (plaintextContent != null) 'plaintext_content': plaintextContent,
      if (plaintextTitle != null) 'plaintext_title': plaintextTitle,
      if (colorIndex != null) 'color_index': colorIndex,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isLocked != null) 'is_locked': isLocked,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinSalt != null) 'pin_salt': pinSalt,
      if (localOnly != null) 'local_only': localOnly,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? encryptedContent,
    Value<String>? encryptedTitle,
    Value<String?>? plaintextContent,
    Value<String?>? plaintextTitle,
    Value<int>? colorIndex,
    Value<bool>? isPinned,
    Value<bool>? isLocked,
    Value<String?>? pinHash,
    Value<String?>? pinSalt,
    Value<bool>? localOnly,
    Value<String?>? tags,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isSynced,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      encryptedTitle: encryptedTitle ?? this.encryptedTitle,
      plaintextContent: plaintextContent ?? this.plaintextContent,
      plaintextTitle: plaintextTitle ?? this.plaintextTitle,
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      localOnly: localOnly ?? this.localOnly,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (encryptedContent.present) {
      map['encrypted_content'] = Variable<String>(encryptedContent.value);
    }
    if (encryptedTitle.present) {
      map['encrypted_title'] = Variable<String>(encryptedTitle.value);
    }
    if (plaintextContent.present) {
      map['plaintext_content'] = Variable<String>(plaintextContent.value);
    }
    if (plaintextTitle.present) {
      map['plaintext_title'] = Variable<String>(plaintextTitle.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinSalt.present) {
      map['pin_salt'] = Variable<String>(pinSalt.value);
    }
    if (localOnly.present) {
      map['local_only'] = Variable<bool>(localOnly.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('encryptedTitle: $encryptedTitle, ')
          ..write('plaintextContent: $plaintextContent, ')
          ..write('plaintextTitle: $plaintextTitle, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('isPinned: $isPinned, ')
          ..write('isLocked: $isLocked, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('localOnly: $localOnly, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localNotes];
}

typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String id,
      required String ownerId,
      required String encryptedContent,
      required String encryptedTitle,
      Value<String?> plaintextContent,
      Value<String?> plaintextTitle,
      required int colorIndex,
      required bool isPinned,
      required bool isLocked,
      Value<String?> pinHash,
      Value<String?> pinSalt,
      required bool localOnly,
      Value<String?> tags,
      required DateTime createdAt,
      required DateTime updatedAt,
      required bool isSynced,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> encryptedContent,
      Value<String> encryptedTitle,
      Value<String?> plaintextContent,
      Value<String?> plaintextTitle,
      Value<int> colorIndex,
      Value<bool> isPinned,
      Value<bool> isLocked,
      Value<String?> pinHash,
      Value<String?> pinSalt,
      Value<bool> localOnly,
      Value<String?> tags,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<int> rowid,
    });

class $$LocalNotesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedTitle => $composableBuilder(
    column: $table.encryptedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plaintextContent => $composableBuilder(
    column: $table.plaintextContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plaintextTitle => $composableBuilder(
    column: $table.plaintextTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedTitle => $composableBuilder(
    column: $table.encryptedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plaintextContent => $composableBuilder(
    column: $table.plaintextContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plaintextTitle => $composableBuilder(
    column: $table.plaintextTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedTitle => $composableBuilder(
    column: $table.encryptedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plaintextContent => $composableBuilder(
    column: $table.plaintextContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plaintextTitle => $composableBuilder(
    column: $table.plaintextTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => column);

  GeneratedColumn<bool> get localOnly =>
      $composableBuilder(column: $table.localOnly, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (
            LocalNote,
            BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>,
          ),
          LocalNote,
          PrefetchHooks Function()
        > {
  $$LocalNotesTableTableManager(_$AppDatabase db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> encryptedContent = const Value.absent(),
                Value<String> encryptedTitle = const Value.absent(),
                Value<String?> plaintextContent = const Value.absent(),
                Value<String?> plaintextTitle = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                ownerId: ownerId,
                encryptedContent: encryptedContent,
                encryptedTitle: encryptedTitle,
                plaintextContent: plaintextContent,
                plaintextTitle: plaintextTitle,
                colorIndex: colorIndex,
                isPinned: isPinned,
                isLocked: isLocked,
                pinHash: pinHash,
                pinSalt: pinSalt,
                localOnly: localOnly,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String encryptedContent,
                required String encryptedTitle,
                Value<String?> plaintextContent = const Value.absent(),
                Value<String?> plaintextTitle = const Value.absent(),
                required int colorIndex,
                required bool isPinned,
                required bool isLocked,
                Value<String?> pinHash = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                required bool localOnly,
                Value<String?> tags = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required bool isSynced,
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                ownerId: ownerId,
                encryptedContent: encryptedContent,
                encryptedTitle: encryptedTitle,
                plaintextContent: plaintextContent,
                plaintextTitle: plaintextTitle,
                colorIndex: colorIndex,
                isPinned: isPinned,
                isLocked: isLocked,
                pinHash: pinHash,
                pinSalt: pinSalt,
                localOnly: localOnly,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>),
      LocalNote,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
}
