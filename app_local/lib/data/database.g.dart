// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseCurrencyMeta = const VerificationMeta(
    'baseCurrency',
  );
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
    'base_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TWD'),
  );
  static const VerificationMeta _openingDateMeta = const VerificationMeta(
    'openingDate',
  );
  @override
  late final GeneratedColumn<String> openingDate = GeneratedColumn<String>(
    'opening_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Asia/Taipei'),
  );
  static const VerificationMeta _costMethodMeta = const VerificationMeta(
    'costMethod',
  );
  @override
  late final GeneratedColumn<String> costMethod = GeneratedColumn<String>(
    'cost_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('avg'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    archivedAt,
    baseCurrency,
    openingDate,
    timezone,
    costMethod,
    version,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('base_currency')) {
      context.handle(
        _baseCurrencyMeta,
        baseCurrency.isAcceptableOrUnknown(
          data['base_currency']!,
          _baseCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('opening_date')) {
      context.handle(
        _openingDateMeta,
        openingDate.isAcceptableOrUnknown(
          data['opening_date']!,
          _openingDateMeta,
        ),
      );
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    }
    if (data.containsKey('cost_method')) {
      context.handle(
        _costMethodMeta,
        costMethod.isAcceptableOrUnknown(data['cost_method']!, _costMethodMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      baseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_currency'],
      )!,
      openingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opening_date'],
      ),
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      costMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_method'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRow extends DataClass implements Insertable<BookRow> {
  final String id;
  final String name;
  final String? archivedAt;
  final String baseCurrency;
  final String? openingDate;
  final String timezone;
  final String costMethod;
  final int version;
  final String createdAt;
  const BookRow({
    required this.id,
    required this.name,
    this.archivedAt,
    required this.baseCurrency,
    this.openingDate,
    required this.timezone,
    required this.costMethod,
    required this.version,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['base_currency'] = Variable<String>(baseCurrency);
    if (!nullToAbsent || openingDate != null) {
      map['opening_date'] = Variable<String>(openingDate);
    }
    map['timezone'] = Variable<String>(timezone);
    map['cost_method'] = Variable<String>(costMethod);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      name: Value(name),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      baseCurrency: Value(baseCurrency),
      openingDate: openingDate == null && nullToAbsent
          ? const Value.absent()
          : Value(openingDate),
      timezone: Value(timezone),
      costMethod: Value(costMethod),
      version: Value(version),
      createdAt: Value(createdAt),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      openingDate: serializer.fromJson<String?>(json['openingDate']),
      timezone: serializer.fromJson<String>(json['timezone']),
      costMethod: serializer.fromJson<String>(json['costMethod']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'openingDate': serializer.toJson<String?>(openingDate),
      'timezone': serializer.toJson<String>(timezone),
      'costMethod': serializer.toJson<String>(costMethod),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  BookRow copyWith({
    String? id,
    String? name,
    Value<String?> archivedAt = const Value.absent(),
    String? baseCurrency,
    Value<String?> openingDate = const Value.absent(),
    String? timezone,
    String? costMethod,
    int? version,
    String? createdAt,
  }) => BookRow(
    id: id ?? this.id,
    name: name ?? this.name,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    openingDate: openingDate.present ? openingDate.value : this.openingDate,
    timezone: timezone ?? this.timezone,
    costMethod: costMethod ?? this.costMethod,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      openingDate: data.openingDate.present
          ? data.openingDate.value
          : this.openingDate,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      costMethod: data.costMethod.present
          ? data.costMethod.value
          : this.costMethod,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('openingDate: $openingDate, ')
          ..write('timezone: $timezone, ')
          ..write('costMethod: $costMethod, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    archivedAt,
    baseCurrency,
    openingDate,
    timezone,
    costMethod,
    version,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.archivedAt == this.archivedAt &&
          other.baseCurrency == this.baseCurrency &&
          other.openingDate == this.openingDate &&
          other.timezone == this.timezone &&
          other.costMethod == this.costMethod &&
          other.version == this.version &&
          other.createdAt == this.createdAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> archivedAt;
  final Value<String> baseCurrency;
  final Value<String?> openingDate;
  final Value<String> timezone;
  final Value<String> costMethod;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.openingDate = const Value.absent(),
    this.timezone = const Value.absent(),
    this.costMethod = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String name,
    this.archivedAt = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.openingDate = const Value.absent(),
    this.timezone = const Value.absent(),
    this.costMethod = const Value.absent(),
    this.version = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<BookRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? archivedAt,
    Expression<String>? baseCurrency,
    Expression<String>? openingDate,
    Expression<String>? timezone,
    Expression<String>? costMethod,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (openingDate != null) 'opening_date': openingDate,
      if (timezone != null) 'timezone': timezone,
      if (costMethod != null) 'cost_method': costMethod,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? archivedAt,
    Value<String>? baseCurrency,
    Value<String?>? openingDate,
    Value<String>? timezone,
    Value<String>? costMethod,
    Value<int>? version,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      archivedAt: archivedAt ?? this.archivedAt,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      openingDate: openingDate ?? this.openingDate,
      timezone: timezone ?? this.timezone,
      costMethod: costMethod ?? this.costMethod,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (openingDate.present) {
      map['opening_date'] = Variable<String>(openingDate.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (costMethod.present) {
      map['cost_method'] = Variable<String>(costMethod.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('openingDate: $openingDate, ')
          ..write('timezone: $timezone, ')
          ..write('costMethod: $costMethod, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    name,
    type,
    archivedAt,
    createdAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
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
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final String bookId;
  final String name;
  final String type;
  final String? archivedAt;
  final String createdAt;
  final int version;
  const AccountRow({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    this.archivedAt,
    required this.createdAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      type: Value(type),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      version: Value(version),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'version': serializer.toJson<int>(version),
    };
  }

  AccountRow copyWith({
    String? id,
    String? bookId,
    String? name,
    String? type,
    Value<String?> archivedAt = const Value.absent(),
    String? createdAt,
    int? version,
  }) => AccountRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    name: name ?? this.name,
    type: type ?? this.type,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    version: version ?? this.version,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, name, type, archivedAt, createdAt, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.type == this.type &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.version == this.version);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> archivedAt;
  final Value<String> createdAt;
  final Value<int> version;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String bookId,
    required String name,
    required String type,
    this.archivedAt = const Value.absent(),
    required String createdAt,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? archivedAt,
    Expression<String>? createdAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? archivedAt,
    Value<String>? createdAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    name,
    kind,
    isSystem,
    archivedAt,
    sort,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String bookId;
  final String name;
  final String kind;
  final bool isSystem;
  final String? archivedAt;
  final int sort;
  final int version;
  const CategoryRow({
    required this.id,
    required this.bookId,
    required this.name,
    required this.kind,
    required this.isSystem,
    this.archivedAt,
    required this.sort,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['is_system'] = Variable<bool>(isSystem);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['sort'] = Variable<int>(sort);
    map['version'] = Variable<int>(version);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      kind: Value(kind),
      isSystem: Value(isSystem),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      sort: Value(sort),
      version: Value(version),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      sort: serializer.fromJson<int>(json['sort']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'isSystem': serializer.toJson<bool>(isSystem),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'sort': serializer.toJson<int>(sort),
      'version': serializer.toJson<int>(version),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? bookId,
    String? name,
    String? kind,
    bool? isSystem,
    Value<String?> archivedAt = const Value.absent(),
    int? sort,
    int? version,
  }) => CategoryRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    isSystem: isSystem ?? this.isSystem,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    sort: sort ?? this.sort,
    version: version ?? this.version,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      sort: data.sort.present ? data.sort.value : this.sort,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('isSystem: $isSystem, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sort: $sort, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, name, kind, isSystem, archivedAt, sort, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.isSystem == this.isSystem &&
          other.archivedAt == this.archivedAt &&
          other.sort == this.sort &&
          other.version == this.version);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String> kind;
  final Value<bool> isSystem;
  final Value<String?> archivedAt;
  final Value<int> sort;
  final Value<int> version;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sort = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String bookId,
    required String name,
    required String kind,
    this.isSystem = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sort = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<bool>? isSystem,
    Expression<String>? archivedAt,
    Expression<int>? sort,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (isSystem != null) 'is_system': isSystem,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (sort != null) 'sort': sort,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? name,
    Value<String>? kind,
    Value<bool>? isSystem,
    Value<String?>? archivedAt,
    Value<int>? sort,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isSystem: isSystem ?? this.isSystem,
      archivedAt: archivedAt ?? this.archivedAt,
      sort: sort ?? this.sort,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('isSystem: $isSystem, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sort: $sort, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstrumentsTable extends Instruments
    with TableInfo<$InstrumentsTable, InstrumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstrumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _assetClassMeta = const VerificationMeta(
    'assetClass',
  );
  @override
  late final GeneratedColumn<String> assetClass = GeneratedColumn<String>(
    'asset_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    symbol,
    name,
    assetClass,
    quoteCurrency,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'instruments';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstrumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('asset_class')) {
      context.handle(
        _assetClassMeta,
        assetClass.isAcceptableOrUnknown(data['asset_class']!, _assetClassMeta),
      );
    } else if (isInserting) {
      context.missing(_assetClassMeta);
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, assetClass, symbol},
  ];
  @override
  InstrumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstrumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      assetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_class'],
      )!,
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
    );
  }

  @override
  $InstrumentsTable createAlias(String alias) {
    return $InstrumentsTable(attachedDatabase, alias);
  }
}

class InstrumentRow extends DataClass implements Insertable<InstrumentRow> {
  final String id;
  final String bookId;
  final String symbol;
  final String name;
  final String assetClass;
  final String quoteCurrency;
  const InstrumentRow({
    required this.id,
    required this.bookId,
    required this.symbol,
    required this.name,
    required this.assetClass,
    required this.quoteCurrency,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['asset_class'] = Variable<String>(assetClass);
    map['quote_currency'] = Variable<String>(quoteCurrency);
    return map;
  }

  InstrumentsCompanion toCompanion(bool nullToAbsent) {
    return InstrumentsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      symbol: Value(symbol),
      name: Value(name),
      assetClass: Value(assetClass),
      quoteCurrency: Value(quoteCurrency),
    );
  }

  factory InstrumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstrumentRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      assetClass: serializer.fromJson<String>(json['assetClass']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'assetClass': serializer.toJson<String>(assetClass),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
    };
  }

  InstrumentRow copyWith({
    String? id,
    String? bookId,
    String? symbol,
    String? name,
    String? assetClass,
    String? quoteCurrency,
  }) => InstrumentRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    assetClass: assetClass ?? this.assetClass,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
  );
  InstrumentRow copyWithCompanion(InstrumentsCompanion data) {
    return InstrumentRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstrumentRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetClass: $assetClass, ')
          ..write('quoteCurrency: $quoteCurrency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, symbol, name, assetClass, quoteCurrency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstrumentRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.assetClass == this.assetClass &&
          other.quoteCurrency == this.quoteCurrency);
}

class InstrumentsCompanion extends UpdateCompanion<InstrumentRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> symbol;
  final Value<String> name;
  final Value<String> assetClass;
  final Value<String> quoteCurrency;
  final Value<int> rowid;
  const InstrumentsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstrumentsCompanion.insert({
    required String id,
    required String bookId,
    required String symbol,
    this.name = const Value.absent(),
    required String assetClass,
    required String quoteCurrency,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       symbol = Value(symbol),
       assetClass = Value(assetClass),
       quoteCurrency = Value(quoteCurrency);
  static Insertable<InstrumentRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? assetClass,
    Expression<String>? quoteCurrency,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (assetClass != null) 'asset_class': assetClass,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstrumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? symbol,
    Value<String>? name,
    Value<String>? assetClass,
    Value<String>? quoteCurrency,
    Value<int>? rowid,
  }) {
    return InstrumentsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      assetClass: assetClass ?? this.assetClass,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(assetClass.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstrumentsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetClass: $assetClass, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _instrumentIdMeta = const VerificationMeta(
    'instrumentId',
  );
  @override
  late final GeneratedColumn<String> instrumentId = GeneratedColumn<String>(
    'instrument_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    date,
    type,
    amount,
    accountId,
    toAccountId,
    categoryId,
    note,
    instrumentId,
    createdAt,
    updatedAt,
    deletedAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('instrument_id')) {
      context.handle(
        _instrumentIdMeta,
        instrumentId.isAcceptableOrUnknown(
          data['instrument_id']!,
          _instrumentIdMeta,
        ),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      instrumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final String id;
  final String bookId;
  final String date;
  final String type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String note;
  final String? instrumentId;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  const EntryRow({
    required this.id,
    required this.bookId,
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.note,
    this.instrumentId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['date'] = Variable<String>(date);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || instrumentId != null) {
      map['instrument_id'] = Variable<String>(instrumentId);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      date: Value(date),
      type: Value(type),
      amount: Value(amount),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: Value(note),
      instrumentId: instrumentId == null && nullToAbsent
          ? const Value.absent()
          : Value(instrumentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      version: Value(version),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      date: serializer.fromJson<String>(json['date']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      note: serializer.fromJson<String>(json['note']),
      instrumentId: serializer.fromJson<String?>(json['instrumentId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'date': serializer.toJson<String>(date),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'note': serializer.toJson<String>(note),
      'instrumentId': serializer.toJson<String?>(instrumentId),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  EntryRow copyWith({
    String? id,
    String? bookId,
    String? date,
    String? type,
    int? amount,
    String? accountId,
    Value<String?> toAccountId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    String? note,
    Value<String?> instrumentId = const Value.absent(),
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? version,
  }) => EntryRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    date: date ?? this.date,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note ?? this.note,
    instrumentId: instrumentId.present ? instrumentId.value : this.instrumentId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    version: version ?? this.version,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
      instrumentId: data.instrumentId.present
          ? data.instrumentId.value
          : this.instrumentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    date,
    type,
    amount,
    accountId,
    toAccountId,
    categoryId,
    note,
    instrumentId,
    createdAt,
    updatedAt,
    deletedAt,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.date == this.date &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.categoryId == this.categoryId &&
          other.note == this.note &&
          other.instrumentId == this.instrumentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.version == this.version);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> date;
  final Value<String> type;
  final Value<int> amount;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<String?> categoryId;
  final Value<String> note;
  final Value<String?> instrumentId;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> version;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.instrumentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String bookId,
    required String date,
    required String type,
    required int amount,
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.instrumentId = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       date = Value(date),
       type = Value(type),
       amount = Value(amount),
       accountId = Value(accountId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EntryRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? date,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<String>? categoryId,
    Expression<String>? note,
    Expression<String>? instrumentId,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
      if (instrumentId != null) 'instrument_id': instrumentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? date,
    Value<String>? type,
    Value<int>? amount,
    Value<String>? accountId,
    Value<String?>? toAccountId,
    Value<String?>? categoryId,
    Value<String>? note,
    Value<String?>? instrumentId,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      instrumentId: instrumentId ?? this.instrumentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (instrumentId.present) {
      map['instrument_id'] = Variable<String>(instrumentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PositionsTable extends Positions
    with TableInfo<$PositionsTable, PositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentIdMeta = const VerificationMeta(
    'instrumentId',
  );
  @override
  late final GeneratedColumn<String> instrumentId = GeneratedColumn<String>(
    'instrument_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<String> qty = GeneratedColumn<String>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _costTwdMeta = const VerificationMeta(
    'costTwd',
  );
  @override
  late final GeneratedColumn<String> costTwd = GeneratedColumn<String>(
    'cost_twd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _realizedTwdMeta = const VerificationMeta(
    'realizedTwd',
  );
  @override
  late final GeneratedColumn<int> realizedTwd = GeneratedColumn<int>(
    'realized_twd',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _costUnknownMeta = const VerificationMeta(
    'costUnknown',
  );
  @override
  late final GeneratedColumn<bool> costUnknown = GeneratedColumn<bool>(
    'cost_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cost_unknown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    accountId,
    instrumentId,
    qty,
    costTwd,
    realizedTwd,
    costUnknown,
    version,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PositionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('instrument_id')) {
      context.handle(
        _instrumentIdMeta,
        instrumentId.isAcceptableOrUnknown(
          data['instrument_id']!,
          _instrumentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    }
    if (data.containsKey('cost_twd')) {
      context.handle(
        _costTwdMeta,
        costTwd.isAcceptableOrUnknown(data['cost_twd']!, _costTwdMeta),
      );
    }
    if (data.containsKey('realized_twd')) {
      context.handle(
        _realizedTwdMeta,
        realizedTwd.isAcceptableOrUnknown(
          data['realized_twd']!,
          _realizedTwdMeta,
        ),
      );
    }
    if (data.containsKey('cost_unknown')) {
      context.handle(
        _costUnknownMeta,
        costUnknown.isAcceptableOrUnknown(
          data['cost_unknown']!,
          _costUnknownMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, instrumentId},
  ];
  @override
  PositionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PositionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      instrumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qty'],
      )!,
      costTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_twd'],
      )!,
      realizedTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}realized_twd'],
      )!,
      costUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cost_unknown'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PositionsTable createAlias(String alias) {
    return $PositionsTable(attachedDatabase, alias);
  }
}

class PositionRow extends DataClass implements Insertable<PositionRow> {
  final String id;
  final String bookId;
  final String accountId;
  final String instrumentId;
  final String qty;
  final String costTwd;
  final int realizedTwd;
  final bool costUnknown;
  final int version;
  final String updatedAt;
  const PositionRow({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.instrumentId,
    required this.qty,
    required this.costTwd,
    required this.realizedTwd,
    required this.costUnknown,
    required this.version,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['account_id'] = Variable<String>(accountId);
    map['instrument_id'] = Variable<String>(instrumentId);
    map['qty'] = Variable<String>(qty);
    map['cost_twd'] = Variable<String>(costTwd);
    map['realized_twd'] = Variable<int>(realizedTwd);
    map['cost_unknown'] = Variable<bool>(costUnknown);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PositionsCompanion toCompanion(bool nullToAbsent) {
    return PositionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      accountId: Value(accountId),
      instrumentId: Value(instrumentId),
      qty: Value(qty),
      costTwd: Value(costTwd),
      realizedTwd: Value(realizedTwd),
      costUnknown: Value(costUnknown),
      version: Value(version),
      updatedAt: Value(updatedAt),
    );
  }

  factory PositionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PositionRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      instrumentId: serializer.fromJson<String>(json['instrumentId']),
      qty: serializer.fromJson<String>(json['qty']),
      costTwd: serializer.fromJson<String>(json['costTwd']),
      realizedTwd: serializer.fromJson<int>(json['realizedTwd']),
      costUnknown: serializer.fromJson<bool>(json['costUnknown']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'accountId': serializer.toJson<String>(accountId),
      'instrumentId': serializer.toJson<String>(instrumentId),
      'qty': serializer.toJson<String>(qty),
      'costTwd': serializer.toJson<String>(costTwd),
      'realizedTwd': serializer.toJson<int>(realizedTwd),
      'costUnknown': serializer.toJson<bool>(costUnknown),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PositionRow copyWith({
    String? id,
    String? bookId,
    String? accountId,
    String? instrumentId,
    String? qty,
    String? costTwd,
    int? realizedTwd,
    bool? costUnknown,
    int? version,
    String? updatedAt,
  }) => PositionRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    accountId: accountId ?? this.accountId,
    instrumentId: instrumentId ?? this.instrumentId,
    qty: qty ?? this.qty,
    costTwd: costTwd ?? this.costTwd,
    realizedTwd: realizedTwd ?? this.realizedTwd,
    costUnknown: costUnknown ?? this.costUnknown,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PositionRow copyWithCompanion(PositionsCompanion data) {
    return PositionRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      instrumentId: data.instrumentId.present
          ? data.instrumentId.value
          : this.instrumentId,
      qty: data.qty.present ? data.qty.value : this.qty,
      costTwd: data.costTwd.present ? data.costTwd.value : this.costTwd,
      realizedTwd: data.realizedTwd.present
          ? data.realizedTwd.value
          : this.realizedTwd,
      costUnknown: data.costUnknown.present
          ? data.costUnknown.value
          : this.costUnknown,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PositionRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('qty: $qty, ')
          ..write('costTwd: $costTwd, ')
          ..write('realizedTwd: $realizedTwd, ')
          ..write('costUnknown: $costUnknown, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    accountId,
    instrumentId,
    qty,
    costTwd,
    realizedTwd,
    costUnknown,
    version,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PositionRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.accountId == this.accountId &&
          other.instrumentId == this.instrumentId &&
          other.qty == this.qty &&
          other.costTwd == this.costTwd &&
          other.realizedTwd == this.realizedTwd &&
          other.costUnknown == this.costUnknown &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt);
}

class PositionsCompanion extends UpdateCompanion<PositionRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> accountId;
  final Value<String> instrumentId;
  final Value<String> qty;
  final Value<String> costTwd;
  final Value<int> realizedTwd;
  final Value<bool> costUnknown;
  final Value<int> version;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PositionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.instrumentId = const Value.absent(),
    this.qty = const Value.absent(),
    this.costTwd = const Value.absent(),
    this.realizedTwd = const Value.absent(),
    this.costUnknown = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PositionsCompanion.insert({
    required String id,
    required String bookId,
    required String accountId,
    required String instrumentId,
    this.qty = const Value.absent(),
    this.costTwd = const Value.absent(),
    this.realizedTwd = const Value.absent(),
    this.costUnknown = const Value.absent(),
    this.version = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       accountId = Value(accountId),
       instrumentId = Value(instrumentId),
       updatedAt = Value(updatedAt);
  static Insertable<PositionRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? accountId,
    Expression<String>? instrumentId,
    Expression<String>? qty,
    Expression<String>? costTwd,
    Expression<int>? realizedTwd,
    Expression<bool>? costUnknown,
    Expression<int>? version,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (accountId != null) 'account_id': accountId,
      if (instrumentId != null) 'instrument_id': instrumentId,
      if (qty != null) 'qty': qty,
      if (costTwd != null) 'cost_twd': costTwd,
      if (realizedTwd != null) 'realized_twd': realizedTwd,
      if (costUnknown != null) 'cost_unknown': costUnknown,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PositionsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? accountId,
    Value<String>? instrumentId,
    Value<String>? qty,
    Value<String>? costTwd,
    Value<int>? realizedTwd,
    Value<bool>? costUnknown,
    Value<int>? version,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return PositionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      accountId: accountId ?? this.accountId,
      instrumentId: instrumentId ?? this.instrumentId,
      qty: qty ?? this.qty,
      costTwd: costTwd ?? this.costTwd,
      realizedTwd: realizedTwd ?? this.realizedTwd,
      costUnknown: costUnknown ?? this.costUnknown,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (instrumentId.present) {
      map['instrument_id'] = Variable<String>(instrumentId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<String>(qty.value);
    }
    if (costTwd.present) {
      map['cost_twd'] = Variable<String>(costTwd.value);
    }
    if (realizedTwd.present) {
      map['realized_twd'] = Variable<int>(realizedTwd.value);
    }
    if (costUnknown.present) {
      map['cost_unknown'] = Variable<bool>(costUnknown.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PositionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('qty: $qty, ')
          ..write('costTwd: $costTwd, ')
          ..write('realizedTwd: $realizedTwd, ')
          ..write('costUnknown: $costUnknown, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TradesTable extends Trades with TableInfo<$TradesTable, TradeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentIdMeta = const VerificationMeta(
    'instrumentId',
  );
  @override
  late final GeneratedColumn<String> instrumentId = GeneratedColumn<String>(
    'instrument_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<String> qty = GeneratedColumn<String>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<String> price = GeneratedColumn<String>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceCcyMeta = const VerificationMeta(
    'priceCcy',
  );
  @override
  late final GeneratedColumn<String> priceCcy = GeneratedColumn<String>(
    'price_ccy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feeTwdMeta = const VerificationMeta('feeTwd');
  @override
  late final GeneratedColumn<int> feeTwd = GeneratedColumn<int>(
    'fee_twd',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _proceedsOrCostTwdMeta = const VerificationMeta(
    'proceedsOrCostTwd',
  );
  @override
  late final GeneratedColumn<int> proceedsOrCostTwd = GeneratedColumn<int>(
    'proceeds_or_cost_twd',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fxUsdTwdMeta = const VerificationMeta(
    'fxUsdTwd',
  );
  @override
  late final GeneratedColumn<String> fxUsdTwd = GeneratedColumn<String>(
    'fx_usd_twd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1'),
  );
  static const VerificationMeta _realizedTwdMeta = const VerificationMeta(
    'realizedTwd',
  );
  @override
  late final GeneratedColumn<int> realizedTwd = GeneratedColumn<int>(
    'realized_twd',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairIdMeta = const VerificationMeta('pairId');
  @override
  late final GeneratedColumn<String> pairId = GeneratedColumn<String>(
    'pair_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    date,
    accountId,
    instrumentId,
    side,
    qty,
    price,
    priceCcy,
    feeTwd,
    proceedsOrCostTwd,
    fxUsdTwd,
    realizedTwd,
    pairId,
    note,
    createdAt,
    updatedAt,
    deletedAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trades';
  @override
  VerificationContext validateIntegrity(
    Insertable<TradeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('instrument_id')) {
      context.handle(
        _instrumentIdMeta,
        instrumentId.isAcceptableOrUnknown(
          data['instrument_id']!,
          _instrumentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentIdMeta);
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    } else if (isInserting) {
      context.missing(_sideMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('price_ccy')) {
      context.handle(
        _priceCcyMeta,
        priceCcy.isAcceptableOrUnknown(data['price_ccy']!, _priceCcyMeta),
      );
    }
    if (data.containsKey('fee_twd')) {
      context.handle(
        _feeTwdMeta,
        feeTwd.isAcceptableOrUnknown(data['fee_twd']!, _feeTwdMeta),
      );
    }
    if (data.containsKey('proceeds_or_cost_twd')) {
      context.handle(
        _proceedsOrCostTwdMeta,
        proceedsOrCostTwd.isAcceptableOrUnknown(
          data['proceeds_or_cost_twd']!,
          _proceedsOrCostTwdMeta,
        ),
      );
    }
    if (data.containsKey('fx_usd_twd')) {
      context.handle(
        _fxUsdTwdMeta,
        fxUsdTwd.isAcceptableOrUnknown(data['fx_usd_twd']!, _fxUsdTwdMeta),
      );
    }
    if (data.containsKey('realized_twd')) {
      context.handle(
        _realizedTwdMeta,
        realizedTwd.isAcceptableOrUnknown(
          data['realized_twd']!,
          _realizedTwdMeta,
        ),
      );
    }
    if (data.containsKey('pair_id')) {
      context.handle(
        _pairIdMeta,
        pairId.isAcceptableOrUnknown(data['pair_id']!, _pairIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TradeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TradeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      instrumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_id'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qty'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price'],
      ),
      priceCcy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_ccy'],
      ),
      feeTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fee_twd'],
      )!,
      proceedsOrCostTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proceeds_or_cost_twd'],
      )!,
      fxUsdTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_usd_twd'],
      )!,
      realizedTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}realized_twd'],
      ),
      pairId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pair_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $TradesTable createAlias(String alias) {
    return $TradesTable(attachedDatabase, alias);
  }
}

class TradeRow extends DataClass implements Insertable<TradeRow> {
  final String id;
  final String bookId;
  final String date;
  final String accountId;
  final String instrumentId;
  final String side;
  final String qty;
  final String? price;
  final String? priceCcy;
  final int feeTwd;
  final int proceedsOrCostTwd;
  final String fxUsdTwd;
  final int? realizedTwd;
  final String? pairId;
  final String note;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  const TradeRow({
    required this.id,
    required this.bookId,
    required this.date,
    required this.accountId,
    required this.instrumentId,
    required this.side,
    required this.qty,
    this.price,
    this.priceCcy,
    required this.feeTwd,
    required this.proceedsOrCostTwd,
    required this.fxUsdTwd,
    this.realizedTwd,
    this.pairId,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['date'] = Variable<String>(date);
    map['account_id'] = Variable<String>(accountId);
    map['instrument_id'] = Variable<String>(instrumentId);
    map['side'] = Variable<String>(side);
    map['qty'] = Variable<String>(qty);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<String>(price);
    }
    if (!nullToAbsent || priceCcy != null) {
      map['price_ccy'] = Variable<String>(priceCcy);
    }
    map['fee_twd'] = Variable<int>(feeTwd);
    map['proceeds_or_cost_twd'] = Variable<int>(proceedsOrCostTwd);
    map['fx_usd_twd'] = Variable<String>(fxUsdTwd);
    if (!nullToAbsent || realizedTwd != null) {
      map['realized_twd'] = Variable<int>(realizedTwd);
    }
    if (!nullToAbsent || pairId != null) {
      map['pair_id'] = Variable<String>(pairId);
    }
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  TradesCompanion toCompanion(bool nullToAbsent) {
    return TradesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      date: Value(date),
      accountId: Value(accountId),
      instrumentId: Value(instrumentId),
      side: Value(side),
      qty: Value(qty),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      priceCcy: priceCcy == null && nullToAbsent
          ? const Value.absent()
          : Value(priceCcy),
      feeTwd: Value(feeTwd),
      proceedsOrCostTwd: Value(proceedsOrCostTwd),
      fxUsdTwd: Value(fxUsdTwd),
      realizedTwd: realizedTwd == null && nullToAbsent
          ? const Value.absent()
          : Value(realizedTwd),
      pairId: pairId == null && nullToAbsent
          ? const Value.absent()
          : Value(pairId),
      note: Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      version: Value(version),
    );
  }

  factory TradeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TradeRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      date: serializer.fromJson<String>(json['date']),
      accountId: serializer.fromJson<String>(json['accountId']),
      instrumentId: serializer.fromJson<String>(json['instrumentId']),
      side: serializer.fromJson<String>(json['side']),
      qty: serializer.fromJson<String>(json['qty']),
      price: serializer.fromJson<String?>(json['price']),
      priceCcy: serializer.fromJson<String?>(json['priceCcy']),
      feeTwd: serializer.fromJson<int>(json['feeTwd']),
      proceedsOrCostTwd: serializer.fromJson<int>(json['proceedsOrCostTwd']),
      fxUsdTwd: serializer.fromJson<String>(json['fxUsdTwd']),
      realizedTwd: serializer.fromJson<int?>(json['realizedTwd']),
      pairId: serializer.fromJson<String?>(json['pairId']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'date': serializer.toJson<String>(date),
      'accountId': serializer.toJson<String>(accountId),
      'instrumentId': serializer.toJson<String>(instrumentId),
      'side': serializer.toJson<String>(side),
      'qty': serializer.toJson<String>(qty),
      'price': serializer.toJson<String?>(price),
      'priceCcy': serializer.toJson<String?>(priceCcy),
      'feeTwd': serializer.toJson<int>(feeTwd),
      'proceedsOrCostTwd': serializer.toJson<int>(proceedsOrCostTwd),
      'fxUsdTwd': serializer.toJson<String>(fxUsdTwd),
      'realizedTwd': serializer.toJson<int?>(realizedTwd),
      'pairId': serializer.toJson<String?>(pairId),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  TradeRow copyWith({
    String? id,
    String? bookId,
    String? date,
    String? accountId,
    String? instrumentId,
    String? side,
    String? qty,
    Value<String?> price = const Value.absent(),
    Value<String?> priceCcy = const Value.absent(),
    int? feeTwd,
    int? proceedsOrCostTwd,
    String? fxUsdTwd,
    Value<int?> realizedTwd = const Value.absent(),
    Value<String?> pairId = const Value.absent(),
    String? note,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    int? version,
  }) => TradeRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    date: date ?? this.date,
    accountId: accountId ?? this.accountId,
    instrumentId: instrumentId ?? this.instrumentId,
    side: side ?? this.side,
    qty: qty ?? this.qty,
    price: price.present ? price.value : this.price,
    priceCcy: priceCcy.present ? priceCcy.value : this.priceCcy,
    feeTwd: feeTwd ?? this.feeTwd,
    proceedsOrCostTwd: proceedsOrCostTwd ?? this.proceedsOrCostTwd,
    fxUsdTwd: fxUsdTwd ?? this.fxUsdTwd,
    realizedTwd: realizedTwd.present ? realizedTwd.value : this.realizedTwd,
    pairId: pairId.present ? pairId.value : this.pairId,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    version: version ?? this.version,
  );
  TradeRow copyWithCompanion(TradesCompanion data) {
    return TradeRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      date: data.date.present ? data.date.value : this.date,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      instrumentId: data.instrumentId.present
          ? data.instrumentId.value
          : this.instrumentId,
      side: data.side.present ? data.side.value : this.side,
      qty: data.qty.present ? data.qty.value : this.qty,
      price: data.price.present ? data.price.value : this.price,
      priceCcy: data.priceCcy.present ? data.priceCcy.value : this.priceCcy,
      feeTwd: data.feeTwd.present ? data.feeTwd.value : this.feeTwd,
      proceedsOrCostTwd: data.proceedsOrCostTwd.present
          ? data.proceedsOrCostTwd.value
          : this.proceedsOrCostTwd,
      fxUsdTwd: data.fxUsdTwd.present ? data.fxUsdTwd.value : this.fxUsdTwd,
      realizedTwd: data.realizedTwd.present
          ? data.realizedTwd.value
          : this.realizedTwd,
      pairId: data.pairId.present ? data.pairId.value : this.pairId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TradeRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('side: $side, ')
          ..write('qty: $qty, ')
          ..write('price: $price, ')
          ..write('priceCcy: $priceCcy, ')
          ..write('feeTwd: $feeTwd, ')
          ..write('proceedsOrCostTwd: $proceedsOrCostTwd, ')
          ..write('fxUsdTwd: $fxUsdTwd, ')
          ..write('realizedTwd: $realizedTwd, ')
          ..write('pairId: $pairId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    date,
    accountId,
    instrumentId,
    side,
    qty,
    price,
    priceCcy,
    feeTwd,
    proceedsOrCostTwd,
    fxUsdTwd,
    realizedTwd,
    pairId,
    note,
    createdAt,
    updatedAt,
    deletedAt,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TradeRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.date == this.date &&
          other.accountId == this.accountId &&
          other.instrumentId == this.instrumentId &&
          other.side == this.side &&
          other.qty == this.qty &&
          other.price == this.price &&
          other.priceCcy == this.priceCcy &&
          other.feeTwd == this.feeTwd &&
          other.proceedsOrCostTwd == this.proceedsOrCostTwd &&
          other.fxUsdTwd == this.fxUsdTwd &&
          other.realizedTwd == this.realizedTwd &&
          other.pairId == this.pairId &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.version == this.version);
}

class TradesCompanion extends UpdateCompanion<TradeRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> date;
  final Value<String> accountId;
  final Value<String> instrumentId;
  final Value<String> side;
  final Value<String> qty;
  final Value<String?> price;
  final Value<String?> priceCcy;
  final Value<int> feeTwd;
  final Value<int> proceedsOrCostTwd;
  final Value<String> fxUsdTwd;
  final Value<int?> realizedTwd;
  final Value<String?> pairId;
  final Value<String> note;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> version;
  final Value<int> rowid;
  const TradesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.date = const Value.absent(),
    this.accountId = const Value.absent(),
    this.instrumentId = const Value.absent(),
    this.side = const Value.absent(),
    this.qty = const Value.absent(),
    this.price = const Value.absent(),
    this.priceCcy = const Value.absent(),
    this.feeTwd = const Value.absent(),
    this.proceedsOrCostTwd = const Value.absent(),
    this.fxUsdTwd = const Value.absent(),
    this.realizedTwd = const Value.absent(),
    this.pairId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradesCompanion.insert({
    required String id,
    required String bookId,
    required String date,
    required String accountId,
    required String instrumentId,
    required String side,
    required String qty,
    this.price = const Value.absent(),
    this.priceCcy = const Value.absent(),
    this.feeTwd = const Value.absent(),
    this.proceedsOrCostTwd = const Value.absent(),
    this.fxUsdTwd = const Value.absent(),
    this.realizedTwd = const Value.absent(),
    this.pairId = const Value.absent(),
    this.note = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       date = Value(date),
       accountId = Value(accountId),
       instrumentId = Value(instrumentId),
       side = Value(side),
       qty = Value(qty),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TradeRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? date,
    Expression<String>? accountId,
    Expression<String>? instrumentId,
    Expression<String>? side,
    Expression<String>? qty,
    Expression<String>? price,
    Expression<String>? priceCcy,
    Expression<int>? feeTwd,
    Expression<int>? proceedsOrCostTwd,
    Expression<String>? fxUsdTwd,
    Expression<int>? realizedTwd,
    Expression<String>? pairId,
    Expression<String>? note,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (date != null) 'date': date,
      if (accountId != null) 'account_id': accountId,
      if (instrumentId != null) 'instrument_id': instrumentId,
      if (side != null) 'side': side,
      if (qty != null) 'qty': qty,
      if (price != null) 'price': price,
      if (priceCcy != null) 'price_ccy': priceCcy,
      if (feeTwd != null) 'fee_twd': feeTwd,
      if (proceedsOrCostTwd != null) 'proceeds_or_cost_twd': proceedsOrCostTwd,
      if (fxUsdTwd != null) 'fx_usd_twd': fxUsdTwd,
      if (realizedTwd != null) 'realized_twd': realizedTwd,
      if (pairId != null) 'pair_id': pairId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? date,
    Value<String>? accountId,
    Value<String>? instrumentId,
    Value<String>? side,
    Value<String>? qty,
    Value<String?>? price,
    Value<String?>? priceCcy,
    Value<int>? feeTwd,
    Value<int>? proceedsOrCostTwd,
    Value<String>? fxUsdTwd,
    Value<int?>? realizedTwd,
    Value<String?>? pairId,
    Value<String>? note,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return TradesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      instrumentId: instrumentId ?? this.instrumentId,
      side: side ?? this.side,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      priceCcy: priceCcy ?? this.priceCcy,
      feeTwd: feeTwd ?? this.feeTwd,
      proceedsOrCostTwd: proceedsOrCostTwd ?? this.proceedsOrCostTwd,
      fxUsdTwd: fxUsdTwd ?? this.fxUsdTwd,
      realizedTwd: realizedTwd ?? this.realizedTwd,
      pairId: pairId ?? this.pairId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (instrumentId.present) {
      map['instrument_id'] = Variable<String>(instrumentId.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (qty.present) {
      map['qty'] = Variable<String>(qty.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(price.value);
    }
    if (priceCcy.present) {
      map['price_ccy'] = Variable<String>(priceCcy.value);
    }
    if (feeTwd.present) {
      map['fee_twd'] = Variable<int>(feeTwd.value);
    }
    if (proceedsOrCostTwd.present) {
      map['proceeds_or_cost_twd'] = Variable<int>(proceedsOrCostTwd.value);
    }
    if (fxUsdTwd.present) {
      map['fx_usd_twd'] = Variable<String>(fxUsdTwd.value);
    }
    if (realizedTwd.present) {
      map['realized_twd'] = Variable<int>(realizedTwd.value);
    }
    if (pairId.present) {
      map['pair_id'] = Variable<String>(pairId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('side: $side, ')
          ..write('qty: $qty, ')
          ..write('price: $price, ')
          ..write('priceCcy: $priceCcy, ')
          ..write('feeTwd: $feeTwd, ')
          ..write('proceedsOrCostTwd: $proceedsOrCostTwd, ')
          ..write('fxUsdTwd: $fxUsdTwd, ')
          ..write('realizedTwd: $realizedTwd, ')
          ..write('pairId: $pairId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuotesTable extends Quotes with TableInfo<$QuotesTable, QuoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instrumentIdMeta = const VerificationMeta(
    'instrumentId',
  );
  @override
  late final GeneratedColumn<String> instrumentId = GeneratedColumn<String>(
    'instrument_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<String> price = GeneratedColumn<String>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ccyMeta = const VerificationMeta('ccy');
  @override
  late final GeneratedColumn<String> ccy = GeneratedColumn<String>(
    'ccy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asOfMeta = const VerificationMeta('asOf');
  @override
  late final GeneratedColumn<String> asOf = GeneratedColumn<String>(
    'as_of',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    instrumentId,
    price,
    ccy,
    asOf,
    source,
    locked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quotes';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instrument_id')) {
      context.handle(
        _instrumentIdMeta,
        instrumentId.isAcceptableOrUnknown(
          data['instrument_id']!,
          _instrumentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentIdMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('ccy')) {
      context.handle(
        _ccyMeta,
        ccy.isAcceptableOrUnknown(data['ccy']!, _ccyMeta),
      );
    } else if (isInserting) {
      context.missing(_ccyMeta);
    }
    if (data.containsKey('as_of')) {
      context.handle(
        _asOfMeta,
        asOf.isAcceptableOrUnknown(data['as_of']!, _asOfMeta),
      );
    } else if (isInserting) {
      context.missing(_asOfMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instrumentId};
  @override
  QuoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuoteRow(
      instrumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_id'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price'],
      )!,
      ccy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ccy'],
      )!,
      asOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}as_of'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
    );
  }

  @override
  $QuotesTable createAlias(String alias) {
    return $QuotesTable(attachedDatabase, alias);
  }
}

class QuoteRow extends DataClass implements Insertable<QuoteRow> {
  final String instrumentId;
  final String price;
  final String ccy;
  final String asOf;
  final String source;
  final bool locked;
  const QuoteRow({
    required this.instrumentId,
    required this.price,
    required this.ccy,
    required this.asOf,
    required this.source,
    required this.locked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instrument_id'] = Variable<String>(instrumentId);
    map['price'] = Variable<String>(price);
    map['ccy'] = Variable<String>(ccy);
    map['as_of'] = Variable<String>(asOf);
    map['source'] = Variable<String>(source);
    map['locked'] = Variable<bool>(locked);
    return map;
  }

  QuotesCompanion toCompanion(bool nullToAbsent) {
    return QuotesCompanion(
      instrumentId: Value(instrumentId),
      price: Value(price),
      ccy: Value(ccy),
      asOf: Value(asOf),
      source: Value(source),
      locked: Value(locked),
    );
  }

  factory QuoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuoteRow(
      instrumentId: serializer.fromJson<String>(json['instrumentId']),
      price: serializer.fromJson<String>(json['price']),
      ccy: serializer.fromJson<String>(json['ccy']),
      asOf: serializer.fromJson<String>(json['asOf']),
      source: serializer.fromJson<String>(json['source']),
      locked: serializer.fromJson<bool>(json['locked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instrumentId': serializer.toJson<String>(instrumentId),
      'price': serializer.toJson<String>(price),
      'ccy': serializer.toJson<String>(ccy),
      'asOf': serializer.toJson<String>(asOf),
      'source': serializer.toJson<String>(source),
      'locked': serializer.toJson<bool>(locked),
    };
  }

  QuoteRow copyWith({
    String? instrumentId,
    String? price,
    String? ccy,
    String? asOf,
    String? source,
    bool? locked,
  }) => QuoteRow(
    instrumentId: instrumentId ?? this.instrumentId,
    price: price ?? this.price,
    ccy: ccy ?? this.ccy,
    asOf: asOf ?? this.asOf,
    source: source ?? this.source,
    locked: locked ?? this.locked,
  );
  QuoteRow copyWithCompanion(QuotesCompanion data) {
    return QuoteRow(
      instrumentId: data.instrumentId.present
          ? data.instrumentId.value
          : this.instrumentId,
      price: data.price.present ? data.price.value : this.price,
      ccy: data.ccy.present ? data.ccy.value : this.ccy,
      asOf: data.asOf.present ? data.asOf.value : this.asOf,
      source: data.source.present ? data.source.value : this.source,
      locked: data.locked.present ? data.locked.value : this.locked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuoteRow(')
          ..write('instrumentId: $instrumentId, ')
          ..write('price: $price, ')
          ..write('ccy: $ccy, ')
          ..write('asOf: $asOf, ')
          ..write('source: $source, ')
          ..write('locked: $locked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(instrumentId, price, ccy, asOf, source, locked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuoteRow &&
          other.instrumentId == this.instrumentId &&
          other.price == this.price &&
          other.ccy == this.ccy &&
          other.asOf == this.asOf &&
          other.source == this.source &&
          other.locked == this.locked);
}

class QuotesCompanion extends UpdateCompanion<QuoteRow> {
  final Value<String> instrumentId;
  final Value<String> price;
  final Value<String> ccy;
  final Value<String> asOf;
  final Value<String> source;
  final Value<bool> locked;
  final Value<int> rowid;
  const QuotesCompanion({
    this.instrumentId = const Value.absent(),
    this.price = const Value.absent(),
    this.ccy = const Value.absent(),
    this.asOf = const Value.absent(),
    this.source = const Value.absent(),
    this.locked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuotesCompanion.insert({
    required String instrumentId,
    required String price,
    required String ccy,
    required String asOf,
    this.source = const Value.absent(),
    this.locked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : instrumentId = Value(instrumentId),
       price = Value(price),
       ccy = Value(ccy),
       asOf = Value(asOf);
  static Insertable<QuoteRow> custom({
    Expression<String>? instrumentId,
    Expression<String>? price,
    Expression<String>? ccy,
    Expression<String>? asOf,
    Expression<String>? source,
    Expression<bool>? locked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instrumentId != null) 'instrument_id': instrumentId,
      if (price != null) 'price': price,
      if (ccy != null) 'ccy': ccy,
      if (asOf != null) 'as_of': asOf,
      if (source != null) 'source': source,
      if (locked != null) 'locked': locked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuotesCompanion copyWith({
    Value<String>? instrumentId,
    Value<String>? price,
    Value<String>? ccy,
    Value<String>? asOf,
    Value<String>? source,
    Value<bool>? locked,
    Value<int>? rowid,
  }) {
    return QuotesCompanion(
      instrumentId: instrumentId ?? this.instrumentId,
      price: price ?? this.price,
      ccy: ccy ?? this.ccy,
      asOf: asOf ?? this.asOf,
      source: source ?? this.source,
      locked: locked ?? this.locked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instrumentId.present) {
      map['instrument_id'] = Variable<String>(instrumentId.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(price.value);
    }
    if (ccy.present) {
      map['ccy'] = Variable<String>(ccy.value);
    }
    if (asOf.present) {
      map['as_of'] = Variable<String>(asOf.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuotesCompanion(')
          ..write('instrumentId: $instrumentId, ')
          ..write('price: $price, ')
          ..write('ccy: $ccy, ')
          ..write('asOf: $asOf, ')
          ..write('source: $source, ')
          ..write('locked: $locked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FxRatesTable extends FxRates with TableInfo<$FxRatesTable, FxRateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FxRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usdTwdMeta = const VerificationMeta('usdTwd');
  @override
  late final GeneratedColumn<String> usdTwd = GeneratedColumn<String>(
    'usd_twd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asOfMeta = const VerificationMeta('asOf');
  @override
  late final GeneratedColumn<String> asOf = GeneratedColumn<String>(
    'as_of',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, usdTwd, asOf, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fx_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<FxRateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('usd_twd')) {
      context.handle(
        _usdTwdMeta,
        usdTwd.isAcceptableOrUnknown(data['usd_twd']!, _usdTwdMeta),
      );
    } else if (isInserting) {
      context.missing(_usdTwdMeta);
    }
    if (data.containsKey('as_of')) {
      context.handle(
        _asOfMeta,
        asOf.isAcceptableOrUnknown(data['as_of']!, _asOfMeta),
      );
    } else if (isInserting) {
      context.missing(_asOfMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  FxRateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FxRateRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      usdTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usd_twd'],
      )!,
      asOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}as_of'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $FxRatesTable createAlias(String alias) {
    return $FxRatesTable(attachedDatabase, alias);
  }
}

class FxRateRow extends DataClass implements Insertable<FxRateRow> {
  final String bookId;
  final String usdTwd;
  final String asOf;
  final String source;
  const FxRateRow({
    required this.bookId,
    required this.usdTwd,
    required this.asOf,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['usd_twd'] = Variable<String>(usdTwd);
    map['as_of'] = Variable<String>(asOf);
    map['source'] = Variable<String>(source);
    return map;
  }

  FxRatesCompanion toCompanion(bool nullToAbsent) {
    return FxRatesCompanion(
      bookId: Value(bookId),
      usdTwd: Value(usdTwd),
      asOf: Value(asOf),
      source: Value(source),
    );
  }

  factory FxRateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FxRateRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      usdTwd: serializer.fromJson<String>(json['usdTwd']),
      asOf: serializer.fromJson<String>(json['asOf']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'usdTwd': serializer.toJson<String>(usdTwd),
      'asOf': serializer.toJson<String>(asOf),
      'source': serializer.toJson<String>(source),
    };
  }

  FxRateRow copyWith({
    String? bookId,
    String? usdTwd,
    String? asOf,
    String? source,
  }) => FxRateRow(
    bookId: bookId ?? this.bookId,
    usdTwd: usdTwd ?? this.usdTwd,
    asOf: asOf ?? this.asOf,
    source: source ?? this.source,
  );
  FxRateRow copyWithCompanion(FxRatesCompanion data) {
    return FxRateRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      usdTwd: data.usdTwd.present ? data.usdTwd.value : this.usdTwd,
      asOf: data.asOf.present ? data.asOf.value : this.asOf,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FxRateRow(')
          ..write('bookId: $bookId, ')
          ..write('usdTwd: $usdTwd, ')
          ..write('asOf: $asOf, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, usdTwd, asOf, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FxRateRow &&
          other.bookId == this.bookId &&
          other.usdTwd == this.usdTwd &&
          other.asOf == this.asOf &&
          other.source == this.source);
}

class FxRatesCompanion extends UpdateCompanion<FxRateRow> {
  final Value<String> bookId;
  final Value<String> usdTwd;
  final Value<String> asOf;
  final Value<String> source;
  final Value<int> rowid;
  const FxRatesCompanion({
    this.bookId = const Value.absent(),
    this.usdTwd = const Value.absent(),
    this.asOf = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FxRatesCompanion.insert({
    required String bookId,
    required String usdTwd,
    required String asOf,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       usdTwd = Value(usdTwd),
       asOf = Value(asOf);
  static Insertable<FxRateRow> custom({
    Expression<String>? bookId,
    Expression<String>? usdTwd,
    Expression<String>? asOf,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (usdTwd != null) 'usd_twd': usdTwd,
      if (asOf != null) 'as_of': asOf,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FxRatesCompanion copyWith({
    Value<String>? bookId,
    Value<String>? usdTwd,
    Value<String>? asOf,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return FxRatesCompanion(
      bookId: bookId ?? this.bookId,
      usdTwd: usdTwd ?? this.usdTwd,
      asOf: asOf ?? this.asOf,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (usdTwd.present) {
      map['usd_twd'] = Variable<String>(usdTwd.value);
    }
    if (asOf.present) {
      map['as_of'] = Variable<String>(asOf.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FxRatesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('usdTwd: $usdTwd, ')
          ..write('asOf: $asOf, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpeningCashDraftsTable extends OpeningCashDrafts
    with TableInfo<$OpeningCashDraftsTable, OpeningCashDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpeningCashDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, accountId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'opening_cash_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpeningCashDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, accountId};
  @override
  OpeningCashDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpeningCashDraftRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $OpeningCashDraftsTable createAlias(String alias) {
    return $OpeningCashDraftsTable(attachedDatabase, alias);
  }
}

class OpeningCashDraftRow extends DataClass
    implements Insertable<OpeningCashDraftRow> {
  final String bookId;
  final String accountId;
  final int amount;
  const OpeningCashDraftRow({
    required this.bookId,
    required this.accountId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['account_id'] = Variable<String>(accountId);
    map['amount'] = Variable<int>(amount);
    return map;
  }

  OpeningCashDraftsCompanion toCompanion(bool nullToAbsent) {
    return OpeningCashDraftsCompanion(
      bookId: Value(bookId),
      accountId: Value(accountId),
      amount: Value(amount),
    );
  }

  factory OpeningCashDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpeningCashDraftRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      amount: serializer.fromJson<int>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'accountId': serializer.toJson<String>(accountId),
      'amount': serializer.toJson<int>(amount),
    };
  }

  OpeningCashDraftRow copyWith({
    String? bookId,
    String? accountId,
    int? amount,
  }) => OpeningCashDraftRow(
    bookId: bookId ?? this.bookId,
    accountId: accountId ?? this.accountId,
    amount: amount ?? this.amount,
  );
  OpeningCashDraftRow copyWithCompanion(OpeningCashDraftsCompanion data) {
    return OpeningCashDraftRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpeningCashDraftRow(')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, accountId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpeningCashDraftRow &&
          other.bookId == this.bookId &&
          other.accountId == this.accountId &&
          other.amount == this.amount);
}

class OpeningCashDraftsCompanion extends UpdateCompanion<OpeningCashDraftRow> {
  final Value<String> bookId;
  final Value<String> accountId;
  final Value<int> amount;
  final Value<int> rowid;
  const OpeningCashDraftsCompanion({
    this.bookId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpeningCashDraftsCompanion.insert({
    required String bookId,
    required String accountId,
    required int amount,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       accountId = Value(accountId),
       amount = Value(amount);
  static Insertable<OpeningCashDraftRow> custom({
    Expression<String>? bookId,
    Expression<String>? accountId,
    Expression<int>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (accountId != null) 'account_id': accountId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpeningCashDraftsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? accountId,
    Value<int>? amount,
    Value<int>? rowid,
  }) {
    return OpeningCashDraftsCompanion(
      bookId: bookId ?? this.bookId,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpeningCashDraftsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpeningPositionDraftsTable extends OpeningPositionDrafts
    with TableInfo<$OpeningPositionDraftsTable, OpeningPositionDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpeningPositionDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentIdMeta = const VerificationMeta(
    'instrumentId',
  );
  @override
  late final GeneratedColumn<String> instrumentId = GeneratedColumn<String>(
    'instrument_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _assetClassMeta = const VerificationMeta(
    'assetClass',
  );
  @override
  late final GeneratedColumn<String> assetClass = GeneratedColumn<String>(
    'asset_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<String> qty = GeneratedColumn<String>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costTwdMeta = const VerificationMeta(
    'costTwd',
  );
  @override
  late final GeneratedColumn<String> costTwd = GeneratedColumn<String>(
    'cost_twd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _costUnknownMeta = const VerificationMeta(
    'costUnknown',
  );
  @override
  late final GeneratedColumn<bool> costUnknown = GeneratedColumn<bool>(
    'cost_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cost_unknown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    accountId,
    instrumentId,
    symbol,
    name,
    assetClass,
    quoteCurrency,
    qty,
    costTwd,
    costUnknown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'opening_position_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpeningPositionDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('instrument_id')) {
      context.handle(
        _instrumentIdMeta,
        instrumentId.isAcceptableOrUnknown(
          data['instrument_id']!,
          _instrumentIdMeta,
        ),
      );
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('asset_class')) {
      context.handle(
        _assetClassMeta,
        assetClass.isAcceptableOrUnknown(data['asset_class']!, _assetClassMeta),
      );
    } else if (isInserting) {
      context.missing(_assetClassMeta);
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('cost_twd')) {
      context.handle(
        _costTwdMeta,
        costTwd.isAcceptableOrUnknown(data['cost_twd']!, _costTwdMeta),
      );
    }
    if (data.containsKey('cost_unknown')) {
      context.handle(
        _costUnknownMeta,
        costUnknown.isAcceptableOrUnknown(
          data['cost_unknown']!,
          _costUnknownMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OpeningPositionDraftRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpeningPositionDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      instrumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_id'],
      ),
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      assetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_class'],
      )!,
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qty'],
      )!,
      costTwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_twd'],
      )!,
      costUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cost_unknown'],
      )!,
    );
  }

  @override
  $OpeningPositionDraftsTable createAlias(String alias) {
    return $OpeningPositionDraftsTable(attachedDatabase, alias);
  }
}

class OpeningPositionDraftRow extends DataClass
    implements Insertable<OpeningPositionDraftRow> {
  final String id;
  final String bookId;
  final String accountId;
  final String? instrumentId;
  final String symbol;
  final String name;
  final String assetClass;
  final String quoteCurrency;
  final String qty;
  final String costTwd;
  final bool costUnknown;
  const OpeningPositionDraftRow({
    required this.id,
    required this.bookId,
    required this.accountId,
    this.instrumentId,
    required this.symbol,
    required this.name,
    required this.assetClass,
    required this.quoteCurrency,
    required this.qty,
    required this.costTwd,
    required this.costUnknown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || instrumentId != null) {
      map['instrument_id'] = Variable<String>(instrumentId);
    }
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['asset_class'] = Variable<String>(assetClass);
    map['quote_currency'] = Variable<String>(quoteCurrency);
    map['qty'] = Variable<String>(qty);
    map['cost_twd'] = Variable<String>(costTwd);
    map['cost_unknown'] = Variable<bool>(costUnknown);
    return map;
  }

  OpeningPositionDraftsCompanion toCompanion(bool nullToAbsent) {
    return OpeningPositionDraftsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      accountId: Value(accountId),
      instrumentId: instrumentId == null && nullToAbsent
          ? const Value.absent()
          : Value(instrumentId),
      symbol: Value(symbol),
      name: Value(name),
      assetClass: Value(assetClass),
      quoteCurrency: Value(quoteCurrency),
      qty: Value(qty),
      costTwd: Value(costTwd),
      costUnknown: Value(costUnknown),
    );
  }

  factory OpeningPositionDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpeningPositionDraftRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      instrumentId: serializer.fromJson<String?>(json['instrumentId']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      assetClass: serializer.fromJson<String>(json['assetClass']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
      qty: serializer.fromJson<String>(json['qty']),
      costTwd: serializer.fromJson<String>(json['costTwd']),
      costUnknown: serializer.fromJson<bool>(json['costUnknown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'accountId': serializer.toJson<String>(accountId),
      'instrumentId': serializer.toJson<String?>(instrumentId),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'assetClass': serializer.toJson<String>(assetClass),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
      'qty': serializer.toJson<String>(qty),
      'costTwd': serializer.toJson<String>(costTwd),
      'costUnknown': serializer.toJson<bool>(costUnknown),
    };
  }

  OpeningPositionDraftRow copyWith({
    String? id,
    String? bookId,
    String? accountId,
    Value<String?> instrumentId = const Value.absent(),
    String? symbol,
    String? name,
    String? assetClass,
    String? quoteCurrency,
    String? qty,
    String? costTwd,
    bool? costUnknown,
  }) => OpeningPositionDraftRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    accountId: accountId ?? this.accountId,
    instrumentId: instrumentId.present ? instrumentId.value : this.instrumentId,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    assetClass: assetClass ?? this.assetClass,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    qty: qty ?? this.qty,
    costTwd: costTwd ?? this.costTwd,
    costUnknown: costUnknown ?? this.costUnknown,
  );
  OpeningPositionDraftRow copyWithCompanion(
    OpeningPositionDraftsCompanion data,
  ) {
    return OpeningPositionDraftRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      instrumentId: data.instrumentId.present
          ? data.instrumentId.value
          : this.instrumentId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
      qty: data.qty.present ? data.qty.value : this.qty,
      costTwd: data.costTwd.present ? data.costTwd.value : this.costTwd,
      costUnknown: data.costUnknown.present
          ? data.costUnknown.value
          : this.costUnknown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpeningPositionDraftRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetClass: $assetClass, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('qty: $qty, ')
          ..write('costTwd: $costTwd, ')
          ..write('costUnknown: $costUnknown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    accountId,
    instrumentId,
    symbol,
    name,
    assetClass,
    quoteCurrency,
    qty,
    costTwd,
    costUnknown,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpeningPositionDraftRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.accountId == this.accountId &&
          other.instrumentId == this.instrumentId &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.assetClass == this.assetClass &&
          other.quoteCurrency == this.quoteCurrency &&
          other.qty == this.qty &&
          other.costTwd == this.costTwd &&
          other.costUnknown == this.costUnknown);
}

class OpeningPositionDraftsCompanion
    extends UpdateCompanion<OpeningPositionDraftRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> accountId;
  final Value<String?> instrumentId;
  final Value<String> symbol;
  final Value<String> name;
  final Value<String> assetClass;
  final Value<String> quoteCurrency;
  final Value<String> qty;
  final Value<String> costTwd;
  final Value<bool> costUnknown;
  final Value<int> rowid;
  const OpeningPositionDraftsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.instrumentId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.qty = const Value.absent(),
    this.costTwd = const Value.absent(),
    this.costUnknown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpeningPositionDraftsCompanion.insert({
    required String id,
    required String bookId,
    required String accountId,
    this.instrumentId = const Value.absent(),
    required String symbol,
    this.name = const Value.absent(),
    required String assetClass,
    required String quoteCurrency,
    required String qty,
    this.costTwd = const Value.absent(),
    this.costUnknown = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       accountId = Value(accountId),
       symbol = Value(symbol),
       assetClass = Value(assetClass),
       quoteCurrency = Value(quoteCurrency),
       qty = Value(qty);
  static Insertable<OpeningPositionDraftRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? accountId,
    Expression<String>? instrumentId,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? assetClass,
    Expression<String>? quoteCurrency,
    Expression<String>? qty,
    Expression<String>? costTwd,
    Expression<bool>? costUnknown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (accountId != null) 'account_id': accountId,
      if (instrumentId != null) 'instrument_id': instrumentId,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (assetClass != null) 'asset_class': assetClass,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (qty != null) 'qty': qty,
      if (costTwd != null) 'cost_twd': costTwd,
      if (costUnknown != null) 'cost_unknown': costUnknown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpeningPositionDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? accountId,
    Value<String?>? instrumentId,
    Value<String>? symbol,
    Value<String>? name,
    Value<String>? assetClass,
    Value<String>? quoteCurrency,
    Value<String>? qty,
    Value<String>? costTwd,
    Value<bool>? costUnknown,
    Value<int>? rowid,
  }) {
    return OpeningPositionDraftsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      accountId: accountId ?? this.accountId,
      instrumentId: instrumentId ?? this.instrumentId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      assetClass: assetClass ?? this.assetClass,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      qty: qty ?? this.qty,
      costTwd: costTwd ?? this.costTwd,
      costUnknown: costUnknown ?? this.costUnknown,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (instrumentId.present) {
      map['instrument_id'] = Variable<String>(instrumentId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(assetClass.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (qty.present) {
      map['qty'] = Variable<String>(qty.value);
    }
    if (costTwd.present) {
      map['cost_twd'] = Variable<String>(costTwd.value);
    }
    if (costUnknown.present) {
      map['cost_unknown'] = Variable<bool>(costUnknown.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpeningPositionDraftsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('accountId: $accountId, ')
          ..write('instrumentId: $instrumentId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetClass: $assetClass, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('qty: $qty, ')
          ..write('costTwd: $costTwd, ')
          ..write('costUnknown: $costUnknown, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPrefsTable extends AppPrefs
    with TableInfo<$AppPrefsTable, AppPrefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPrefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPrefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPrefRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppPrefsTable createAlias(String alias) {
    return $AppPrefsTable(attachedDatabase, alias);
  }
}

class AppPrefRow extends DataClass implements Insertable<AppPrefRow> {
  final String key;
  final String? value;
  const AppPrefRow({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppPrefsCompanion toCompanion(bool nullToAbsent) {
    return AppPrefsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppPrefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPrefRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppPrefRow copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppPrefRow(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppPrefRow copyWithCompanion(AppPrefsCompanion data) {
    return AppPrefRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPrefRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPrefRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPrefsCompanion extends UpdateCompanion<AppPrefRow> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppPrefsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPrefsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppPrefRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPrefsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppPrefsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPrefsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdempotencyKeysTable extends IdempotencyKeys
    with TableInfo<$IdempotencyKeysTable, IdempotencyKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdempotencyKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseStatusMeta = const VerificationMeta(
    'responseStatus',
  );
  @override
  late final GeneratedColumn<int> responseStatus = GeneratedColumn<int>(
    'response_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseBodyMeta = const VerificationMeta(
    'responseBody',
  );
  @override
  late final GeneratedColumn<String> responseBody = GeneratedColumn<String>(
    'response_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    method,
    path,
    responseStatus,
    responseBody,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idempotency_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdempotencyKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('response_status')) {
      context.handle(
        _responseStatusMeta,
        responseStatus.isAcceptableOrUnknown(
          data['response_status']!,
          _responseStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseStatusMeta);
    }
    if (data.containsKey('response_body')) {
      context.handle(
        _responseBodyMeta,
        responseBody.isAcceptableOrUnknown(
          data['response_body']!,
          _responseBodyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseBodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  IdempotencyKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdempotencyKeyRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      responseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}response_status'],
      )!,
      responseBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $IdempotencyKeysTable createAlias(String alias) {
    return $IdempotencyKeysTable(attachedDatabase, alias);
  }
}

class IdempotencyKeyRow extends DataClass
    implements Insertable<IdempotencyKeyRow> {
  final String key;
  final String method;
  final String path;
  final int responseStatus;
  final String responseBody;
  final String createdAt;
  const IdempotencyKeyRow({
    required this.key,
    required this.method,
    required this.path,
    required this.responseStatus,
    required this.responseBody,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['response_status'] = Variable<int>(responseStatus);
    map['response_body'] = Variable<String>(responseBody);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  IdempotencyKeysCompanion toCompanion(bool nullToAbsent) {
    return IdempotencyKeysCompanion(
      key: Value(key),
      method: Value(method),
      path: Value(path),
      responseStatus: Value(responseStatus),
      responseBody: Value(responseBody),
      createdAt: Value(createdAt),
    );
  }

  factory IdempotencyKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdempotencyKeyRow(
      key: serializer.fromJson<String>(json['key']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      responseStatus: serializer.fromJson<int>(json['responseStatus']),
      responseBody: serializer.fromJson<String>(json['responseBody']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'responseStatus': serializer.toJson<int>(responseStatus),
      'responseBody': serializer.toJson<String>(responseBody),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  IdempotencyKeyRow copyWith({
    String? key,
    String? method,
    String? path,
    int? responseStatus,
    String? responseBody,
    String? createdAt,
  }) => IdempotencyKeyRow(
    key: key ?? this.key,
    method: method ?? this.method,
    path: path ?? this.path,
    responseStatus: responseStatus ?? this.responseStatus,
    responseBody: responseBody ?? this.responseBody,
    createdAt: createdAt ?? this.createdAt,
  );
  IdempotencyKeyRow copyWithCompanion(IdempotencyKeysCompanion data) {
    return IdempotencyKeyRow(
      key: data.key.present ? data.key.value : this.key,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      responseStatus: data.responseStatus.present
          ? data.responseStatus.value
          : this.responseStatus,
      responseBody: data.responseBody.present
          ? data.responseBody.value
          : this.responseBody,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdempotencyKeyRow(')
          ..write('key: $key, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('responseBody: $responseBody, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, method, path, responseStatus, responseBody, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdempotencyKeyRow &&
          other.key == this.key &&
          other.method == this.method &&
          other.path == this.path &&
          other.responseStatus == this.responseStatus &&
          other.responseBody == this.responseBody &&
          other.createdAt == this.createdAt);
}

class IdempotencyKeysCompanion extends UpdateCompanion<IdempotencyKeyRow> {
  final Value<String> key;
  final Value<String> method;
  final Value<String> path;
  final Value<int> responseStatus;
  final Value<String> responseBody;
  final Value<String> createdAt;
  final Value<int> rowid;
  const IdempotencyKeysCompanion({
    this.key = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.responseStatus = const Value.absent(),
    this.responseBody = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdempotencyKeysCompanion.insert({
    required String key,
    required String method,
    required String path,
    required int responseStatus,
    required String responseBody,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       method = Value(method),
       path = Value(path),
       responseStatus = Value(responseStatus),
       responseBody = Value(responseBody),
       createdAt = Value(createdAt);
  static Insertable<IdempotencyKeyRow> custom({
    Expression<String>? key,
    Expression<String>? method,
    Expression<String>? path,
    Expression<int>? responseStatus,
    Expression<String>? responseBody,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (responseStatus != null) 'response_status': responseStatus,
      if (responseBody != null) 'response_body': responseBody,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdempotencyKeysCompanion copyWith({
    Value<String>? key,
    Value<String>? method,
    Value<String>? path,
    Value<int>? responseStatus,
    Value<String>? responseBody,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return IdempotencyKeysCompanion(
      key: key ?? this.key,
      method: method ?? this.method,
      path: path ?? this.path,
      responseStatus: responseStatus ?? this.responseStatus,
      responseBody: responseBody ?? this.responseBody,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (responseStatus.present) {
      map['response_status'] = Variable<int>(responseStatus.value);
    }
    if (responseBody.present) {
      map['response_body'] = Variable<String>(responseBody.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdempotencyKeysCompanion(')
          ..write('key: $key, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('responseBody: $responseBody, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportKeysTable extends ImportKeys
    with TableInfo<$ImportKeysTable, ImportKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importKeyMeta = const VerificationMeta(
    'importKey',
  );
  @override
  late final GeneratedColumn<String> importKey = GeneratedColumn<String>(
    'import_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, importKey, entryId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('import_key')) {
      context.handle(
        _importKeyMeta,
        importKey.isAcceptableOrUnknown(data['import_key']!, _importKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_importKeyMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, importKey};
  @override
  ImportKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportKeyRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      importKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_key'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImportKeysTable createAlias(String alias) {
    return $ImportKeysTable(attachedDatabase, alias);
  }
}

class ImportKeyRow extends DataClass implements Insertable<ImportKeyRow> {
  final String bookId;
  final String importKey;
  final String? entryId;
  final String createdAt;
  const ImportKeyRow({
    required this.bookId,
    required this.importKey,
    this.entryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['import_key'] = Variable<String>(importKey);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ImportKeysCompanion toCompanion(bool nullToAbsent) {
    return ImportKeysCompanion(
      bookId: Value(bookId),
      importKey: Value(importKey),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      createdAt: Value(createdAt),
    );
  }

  factory ImportKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportKeyRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      importKey: serializer.fromJson<String>(json['importKey']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'importKey': serializer.toJson<String>(importKey),
      'entryId': serializer.toJson<String?>(entryId),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ImportKeyRow copyWith({
    String? bookId,
    String? importKey,
    Value<String?> entryId = const Value.absent(),
    String? createdAt,
  }) => ImportKeyRow(
    bookId: bookId ?? this.bookId,
    importKey: importKey ?? this.importKey,
    entryId: entryId.present ? entryId.value : this.entryId,
    createdAt: createdAt ?? this.createdAt,
  );
  ImportKeyRow copyWithCompanion(ImportKeysCompanion data) {
    return ImportKeyRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      importKey: data.importKey.present ? data.importKey.value : this.importKey,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportKeyRow(')
          ..write('bookId: $bookId, ')
          ..write('importKey: $importKey, ')
          ..write('entryId: $entryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, importKey, entryId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportKeyRow &&
          other.bookId == this.bookId &&
          other.importKey == this.importKey &&
          other.entryId == this.entryId &&
          other.createdAt == this.createdAt);
}

class ImportKeysCompanion extends UpdateCompanion<ImportKeyRow> {
  final Value<String> bookId;
  final Value<String> importKey;
  final Value<String?> entryId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ImportKeysCompanion({
    this.bookId = const Value.absent(),
    this.importKey = const Value.absent(),
    this.entryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportKeysCompanion.insert({
    required String bookId,
    required String importKey,
    this.entryId = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       importKey = Value(importKey),
       createdAt = Value(createdAt);
  static Insertable<ImportKeyRow> custom({
    Expression<String>? bookId,
    Expression<String>? importKey,
    Expression<String>? entryId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (importKey != null) 'import_key': importKey,
      if (entryId != null) 'entry_id': entryId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportKeysCompanion copyWith({
    Value<String>? bookId,
    Value<String>? importKey,
    Value<String?>? entryId,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ImportKeysCompanion(
      bookId: bookId ?? this.bookId,
      importKey: importKey ?? this.importKey,
      entryId: entryId ?? this.entryId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (importKey.present) {
      map['import_key'] = Variable<String>(importKey.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportKeysCompanion(')
          ..write('bookId: $bookId, ')
          ..write('importKey: $importKey, ')
          ..write('entryId: $entryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantCategoryMapsTable extends MerchantCategoryMaps
    with TableInfo<$MerchantCategoryMapsTable, MerchantCategoryMapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantCategoryMapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, merchant, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_category_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantCategoryMapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, merchant};
  @override
  MerchantCategoryMapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantCategoryMapRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
    );
  }

  @override
  $MerchantCategoryMapsTable createAlias(String alias) {
    return $MerchantCategoryMapsTable(attachedDatabase, alias);
  }
}

class MerchantCategoryMapRow extends DataClass
    implements Insertable<MerchantCategoryMapRow> {
  final String bookId;
  final String merchant;
  final String categoryId;
  const MerchantCategoryMapRow({
    required this.bookId,
    required this.merchant,
    required this.categoryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['merchant'] = Variable<String>(merchant);
    map['category_id'] = Variable<String>(categoryId);
    return map;
  }

  MerchantCategoryMapsCompanion toCompanion(bool nullToAbsent) {
    return MerchantCategoryMapsCompanion(
      bookId: Value(bookId),
      merchant: Value(merchant),
      categoryId: Value(categoryId),
    );
  }

  factory MerchantCategoryMapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantCategoryMapRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      merchant: serializer.fromJson<String>(json['merchant']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'merchant': serializer.toJson<String>(merchant),
      'categoryId': serializer.toJson<String>(categoryId),
    };
  }

  MerchantCategoryMapRow copyWith({
    String? bookId,
    String? merchant,
    String? categoryId,
  }) => MerchantCategoryMapRow(
    bookId: bookId ?? this.bookId,
    merchant: merchant ?? this.merchant,
    categoryId: categoryId ?? this.categoryId,
  );
  MerchantCategoryMapRow copyWithCompanion(MerchantCategoryMapsCompanion data) {
    return MerchantCategoryMapRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantCategoryMapRow(')
          ..write('bookId: $bookId, ')
          ..write('merchant: $merchant, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, merchant, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantCategoryMapRow &&
          other.bookId == this.bookId &&
          other.merchant == this.merchant &&
          other.categoryId == this.categoryId);
}

class MerchantCategoryMapsCompanion
    extends UpdateCompanion<MerchantCategoryMapRow> {
  final Value<String> bookId;
  final Value<String> merchant;
  final Value<String> categoryId;
  final Value<int> rowid;
  const MerchantCategoryMapsCompanion({
    this.bookId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantCategoryMapsCompanion.insert({
    required String bookId,
    required String merchant,
    required String categoryId,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       merchant = Value(merchant),
       categoryId = Value(categoryId);
  static Insertable<MerchantCategoryMapRow> custom({
    Expression<String>? bookId,
    Expression<String>? merchant,
    Expression<String>? categoryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (merchant != null) 'merchant': merchant,
      if (categoryId != null) 'category_id': categoryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantCategoryMapsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? merchant,
    Value<String>? categoryId,
    Value<int>? rowid,
  }) {
    return MerchantCategoryMapsCompanion(
      bookId: bookId ?? this.bookId,
      merchant: merchant ?? this.merchant,
      categoryId: categoryId ?? this.categoryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantCategoryMapsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('merchant: $merchant, ')
          ..write('categoryId: $categoryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardAccountMapsTable extends CardAccountMaps
    with TableInfo<$CardAccountMapsTable, CardAccountMapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardAccountMapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardLast4Meta = const VerificationMeta(
    'cardLast4',
  );
  @override
  late final GeneratedColumn<String> cardLast4 = GeneratedColumn<String>(
    'card_last4',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, cardLast4, accountId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_account_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardAccountMapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('card_last4')) {
      context.handle(
        _cardLast4Meta,
        cardLast4.isAcceptableOrUnknown(data['card_last4']!, _cardLast4Meta),
      );
    } else if (isInserting) {
      context.missing(_cardLast4Meta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, cardLast4};
  @override
  CardAccountMapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardAccountMapRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      cardLast4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_last4'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
    );
  }

  @override
  $CardAccountMapsTable createAlias(String alias) {
    return $CardAccountMapsTable(attachedDatabase, alias);
  }
}

class CardAccountMapRow extends DataClass
    implements Insertable<CardAccountMapRow> {
  final String bookId;
  final String cardLast4;
  final String accountId;
  const CardAccountMapRow({
    required this.bookId,
    required this.cardLast4,
    required this.accountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['card_last4'] = Variable<String>(cardLast4);
    map['account_id'] = Variable<String>(accountId);
    return map;
  }

  CardAccountMapsCompanion toCompanion(bool nullToAbsent) {
    return CardAccountMapsCompanion(
      bookId: Value(bookId),
      cardLast4: Value(cardLast4),
      accountId: Value(accountId),
    );
  }

  factory CardAccountMapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardAccountMapRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      cardLast4: serializer.fromJson<String>(json['cardLast4']),
      accountId: serializer.fromJson<String>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'cardLast4': serializer.toJson<String>(cardLast4),
      'accountId': serializer.toJson<String>(accountId),
    };
  }

  CardAccountMapRow copyWith({
    String? bookId,
    String? cardLast4,
    String? accountId,
  }) => CardAccountMapRow(
    bookId: bookId ?? this.bookId,
    cardLast4: cardLast4 ?? this.cardLast4,
    accountId: accountId ?? this.accountId,
  );
  CardAccountMapRow copyWithCompanion(CardAccountMapsCompanion data) {
    return CardAccountMapRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      cardLast4: data.cardLast4.present ? data.cardLast4.value : this.cardLast4,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardAccountMapRow(')
          ..write('bookId: $bookId, ')
          ..write('cardLast4: $cardLast4, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, cardLast4, accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardAccountMapRow &&
          other.bookId == this.bookId &&
          other.cardLast4 == this.cardLast4 &&
          other.accountId == this.accountId);
}

class CardAccountMapsCompanion extends UpdateCompanion<CardAccountMapRow> {
  final Value<String> bookId;
  final Value<String> cardLast4;
  final Value<String> accountId;
  final Value<int> rowid;
  const CardAccountMapsCompanion({
    this.bookId = const Value.absent(),
    this.cardLast4 = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardAccountMapsCompanion.insert({
    required String bookId,
    required String cardLast4,
    required String accountId,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       cardLast4 = Value(cardLast4),
       accountId = Value(accountId);
  static Insertable<CardAccountMapRow> custom({
    Expression<String>? bookId,
    Expression<String>? cardLast4,
    Expression<String>? accountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (cardLast4 != null) 'card_last4': cardLast4,
      if (accountId != null) 'account_id': accountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardAccountMapsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? cardLast4,
    Value<String>? accountId,
    Value<int>? rowid,
  }) {
    return CardAccountMapsCompanion(
      bookId: bookId ?? this.bookId,
      cardLast4: cardLast4 ?? this.cardLast4,
      accountId: accountId ?? this.accountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (cardLast4.present) {
      map['card_last4'] = Variable<String>(cardLast4.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardAccountMapsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('cardLast4: $cardLast4, ')
          ..write('accountId: $accountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $InstrumentsTable instruments = $InstrumentsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PositionsTable positions = $PositionsTable(this);
  late final $TradesTable trades = $TradesTable(this);
  late final $QuotesTable quotes = $QuotesTable(this);
  late final $FxRatesTable fxRates = $FxRatesTable(this);
  late final $OpeningCashDraftsTable openingCashDrafts =
      $OpeningCashDraftsTable(this);
  late final $OpeningPositionDraftsTable openingPositionDrafts =
      $OpeningPositionDraftsTable(this);
  late final $AppPrefsTable appPrefs = $AppPrefsTable(this);
  late final $IdempotencyKeysTable idempotencyKeys = $IdempotencyKeysTable(
    this,
  );
  late final $ImportKeysTable importKeys = $ImportKeysTable(this);
  late final $MerchantCategoryMapsTable merchantCategoryMaps =
      $MerchantCategoryMapsTable(this);
  late final $CardAccountMapsTable cardAccountMaps = $CardAccountMapsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    accounts,
    categories,
    instruments,
    entries,
    positions,
    trades,
    quotes,
    fxRates,
    openingCashDrafts,
    openingPositionDrafts,
    appPrefs,
    idempotencyKeys,
    importKeys,
    merchantCategoryMaps,
    cardAccountMaps,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String name,
      Value<String?> archivedAt,
      Value<String> baseCurrency,
      Value<String?> openingDate,
      Value<String> timezone,
      Value<String> costMethod,
      Value<int> version,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> archivedAt,
      Value<String> baseCurrency,
      Value<String?> openingDate,
      Value<String> timezone,
      Value<String> costMethod,
      Value<int> version,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costMethod => $composableBuilder(
    column: $table.costMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costMethod => $composableBuilder(
    column: $table.costMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get costMethod => $composableBuilder(
    column: $table.costMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
          BookRow,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String> baseCurrency = const Value.absent(),
                Value<String?> openingDate = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> costMethod = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                name: name,
                archivedAt: archivedAt,
                baseCurrency: baseCurrency,
                openingDate: openingDate,
                timezone: timezone,
                costMethod: costMethod,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> archivedAt = const Value.absent(),
                Value<String> baseCurrency = const Value.absent(),
                Value<String?> openingDate = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> costMethod = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                name: name,
                archivedAt: archivedAt,
                baseCurrency: baseCurrency,
                openingDate: openingDate,
                timezone: timezone,
                costMethod: costMethod,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
      BookRow,
      PrefetchHooks Function()
    >;
typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String bookId,
      required String name,
      required String type,
      Value<String?> archivedAt,
      required String createdAt,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> name,
      Value<String> type,
      Value<String?> archivedAt,
      Value<String> createdAt,
      Value<int> version,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                bookId: bookId,
                name: name,
                type: type,
                archivedAt: archivedAt,
                createdAt: createdAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String name,
                required String type,
                Value<String?> archivedAt = const Value.absent(),
                required String createdAt,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                bookId: bookId,
                name: name,
                type: type,
                archivedAt: archivedAt,
                createdAt: createdAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String bookId,
      required String name,
      required String kind,
      Value<bool> isSystem,
      Value<String?> archivedAt,
      Value<int> sort,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> name,
      Value<String> kind,
      Value<bool> isSystem,
      Value<String?> archivedAt,
      Value<int> sort,
      Value<int> version,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                bookId: bookId,
                name: name,
                kind: kind,
                isSystem: isSystem,
                archivedAt: archivedAt,
                sort: sort,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String name,
                required String kind,
                Value<bool> isSystem = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                bookId: bookId,
                name: name,
                kind: kind,
                isSystem: isSystem,
                archivedAt: archivedAt,
                sort: sort,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$InstrumentsTableCreateCompanionBuilder =
    InstrumentsCompanion Function({
      required String id,
      required String bookId,
      required String symbol,
      Value<String> name,
      required String assetClass,
      required String quoteCurrency,
      Value<int> rowid,
    });
typedef $$InstrumentsTableUpdateCompanionBuilder =
    InstrumentsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> symbol,
      Value<String> name,
      Value<String> assetClass,
      Value<String> quoteCurrency,
      Value<int> rowid,
    });

class $$InstrumentsTableFilterComposer
    extends Composer<_$AppDatabase, $InstrumentsTable> {
  $$InstrumentsTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstrumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstrumentsTable> {
  $$InstrumentsTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstrumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstrumentsTable> {
  $$InstrumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );
}

class $$InstrumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstrumentsTable,
          InstrumentRow,
          $$InstrumentsTableFilterComposer,
          $$InstrumentsTableOrderingComposer,
          $$InstrumentsTableAnnotationComposer,
          $$InstrumentsTableCreateCompanionBuilder,
          $$InstrumentsTableUpdateCompanionBuilder,
          (
            InstrumentRow,
            BaseReferences<_$AppDatabase, $InstrumentsTable, InstrumentRow>,
          ),
          InstrumentRow,
          PrefetchHooks Function()
        > {
  $$InstrumentsTableTableManager(_$AppDatabase db, $InstrumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstrumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstrumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstrumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> assetClass = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstrumentsCompanion(
                id: id,
                bookId: bookId,
                symbol: symbol,
                name: name,
                assetClass: assetClass,
                quoteCurrency: quoteCurrency,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String symbol,
                Value<String> name = const Value.absent(),
                required String assetClass,
                required String quoteCurrency,
                Value<int> rowid = const Value.absent(),
              }) => InstrumentsCompanion.insert(
                id: id,
                bookId: bookId,
                symbol: symbol,
                name: name,
                assetClass: assetClass,
                quoteCurrency: quoteCurrency,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstrumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstrumentsTable,
      InstrumentRow,
      $$InstrumentsTableFilterComposer,
      $$InstrumentsTableOrderingComposer,
      $$InstrumentsTableAnnotationComposer,
      $$InstrumentsTableCreateCompanionBuilder,
      $$InstrumentsTableUpdateCompanionBuilder,
      (
        InstrumentRow,
        BaseReferences<_$AppDatabase, $InstrumentsTable, InstrumentRow>,
      ),
      InstrumentRow,
      PrefetchHooks Function()
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String bookId,
      required String date,
      required String type,
      required int amount,
      required String accountId,
      Value<String?> toAccountId,
      Value<String?> categoryId,
      Value<String> note,
      Value<String?> instrumentId,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> date,
      Value<String> type,
      Value<int> amount,
      Value<String> accountId,
      Value<String?> toAccountId,
      Value<String?> categoryId,
      Value<String> note,
      Value<String?> instrumentId,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> version,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> instrumentId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                bookId: bookId,
                date: date,
                type: type,
                amount: amount,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                note: note,
                instrumentId: instrumentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String date,
                required String type,
                required int amount,
                required String accountId,
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> instrumentId = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                bookId: bookId,
                date: date,
                type: type,
                amount: amount,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                note: note,
                instrumentId: instrumentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$PositionsTableCreateCompanionBuilder =
    PositionsCompanion Function({
      required String id,
      required String bookId,
      required String accountId,
      required String instrumentId,
      Value<String> qty,
      Value<String> costTwd,
      Value<int> realizedTwd,
      Value<bool> costUnknown,
      Value<int> version,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$PositionsTableUpdateCompanionBuilder =
    PositionsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> accountId,
      Value<String> instrumentId,
      Value<String> qty,
      Value<String> costTwd,
      Value<int> realizedTwd,
      Value<bool> costUnknown,
      Value<int> version,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$PositionsTableFilterComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costTwd => $composableBuilder(
    column: $table.costTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costTwd => $composableBuilder(
    column: $table.costTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get costTwd =>
      $composableBuilder(column: $table.costTwd, builder: (column) => column);

  GeneratedColumn<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PositionsTable,
          PositionRow,
          $$PositionsTableFilterComposer,
          $$PositionsTableOrderingComposer,
          $$PositionsTableAnnotationComposer,
          $$PositionsTableCreateCompanionBuilder,
          $$PositionsTableUpdateCompanionBuilder,
          (
            PositionRow,
            BaseReferences<_$AppDatabase, $PositionsTable, PositionRow>,
          ),
          PositionRow,
          PrefetchHooks Function()
        > {
  $$PositionsTableTableManager(_$AppDatabase db, $PositionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> instrumentId = const Value.absent(),
                Value<String> qty = const Value.absent(),
                Value<String> costTwd = const Value.absent(),
                Value<int> realizedTwd = const Value.absent(),
                Value<bool> costUnknown = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PositionsCompanion(
                id: id,
                bookId: bookId,
                accountId: accountId,
                instrumentId: instrumentId,
                qty: qty,
                costTwd: costTwd,
                realizedTwd: realizedTwd,
                costUnknown: costUnknown,
                version: version,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String accountId,
                required String instrumentId,
                Value<String> qty = const Value.absent(),
                Value<String> costTwd = const Value.absent(),
                Value<int> realizedTwd = const Value.absent(),
                Value<bool> costUnknown = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PositionsCompanion.insert(
                id: id,
                bookId: bookId,
                accountId: accountId,
                instrumentId: instrumentId,
                qty: qty,
                costTwd: costTwd,
                realizedTwd: realizedTwd,
                costUnknown: costUnknown,
                version: version,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PositionsTable,
      PositionRow,
      $$PositionsTableFilterComposer,
      $$PositionsTableOrderingComposer,
      $$PositionsTableAnnotationComposer,
      $$PositionsTableCreateCompanionBuilder,
      $$PositionsTableUpdateCompanionBuilder,
      (
        PositionRow,
        BaseReferences<_$AppDatabase, $PositionsTable, PositionRow>,
      ),
      PositionRow,
      PrefetchHooks Function()
    >;
typedef $$TradesTableCreateCompanionBuilder =
    TradesCompanion Function({
      required String id,
      required String bookId,
      required String date,
      required String accountId,
      required String instrumentId,
      required String side,
      required String qty,
      Value<String?> price,
      Value<String?> priceCcy,
      Value<int> feeTwd,
      Value<int> proceedsOrCostTwd,
      Value<String> fxUsdTwd,
      Value<int?> realizedTwd,
      Value<String?> pairId,
      Value<String> note,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$TradesTableUpdateCompanionBuilder =
    TradesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> date,
      Value<String> accountId,
      Value<String> instrumentId,
      Value<String> side,
      Value<String> qty,
      Value<String?> price,
      Value<String?> priceCcy,
      Value<int> feeTwd,
      Value<int> proceedsOrCostTwd,
      Value<String> fxUsdTwd,
      Value<int?> realizedTwd,
      Value<String?> pairId,
      Value<String> note,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> version,
      Value<int> rowid,
    });

class $$TradesTableFilterComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceCcy => $composableBuilder(
    column: $table.priceCcy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feeTwd => $composableBuilder(
    column: $table.feeTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proceedsOrCostTwd => $composableBuilder(
    column: $table.proceedsOrCostTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fxUsdTwd => $composableBuilder(
    column: $table.fxUsdTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TradesTableOrderingComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceCcy => $composableBuilder(
    column: $table.priceCcy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feeTwd => $composableBuilder(
    column: $table.feeTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proceedsOrCostTwd => $composableBuilder(
    column: $table.proceedsOrCostTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fxUsdTwd => $composableBuilder(
    column: $table.fxUsdTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<String> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get priceCcy =>
      $composableBuilder(column: $table.priceCcy, builder: (column) => column);

  GeneratedColumn<int> get feeTwd =>
      $composableBuilder(column: $table.feeTwd, builder: (column) => column);

  GeneratedColumn<int> get proceedsOrCostTwd => $composableBuilder(
    column: $table.proceedsOrCostTwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fxUsdTwd =>
      $composableBuilder(column: $table.fxUsdTwd, builder: (column) => column);

  GeneratedColumn<int> get realizedTwd => $composableBuilder(
    column: $table.realizedTwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pairId =>
      $composableBuilder(column: $table.pairId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$TradesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradesTable,
          TradeRow,
          $$TradesTableFilterComposer,
          $$TradesTableOrderingComposer,
          $$TradesTableAnnotationComposer,
          $$TradesTableCreateCompanionBuilder,
          $$TradesTableUpdateCompanionBuilder,
          (TradeRow, BaseReferences<_$AppDatabase, $TradesTable, TradeRow>),
          TradeRow,
          PrefetchHooks Function()
        > {
  $$TradesTableTableManager(_$AppDatabase db, $TradesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> instrumentId = const Value.absent(),
                Value<String> side = const Value.absent(),
                Value<String> qty = const Value.absent(),
                Value<String?> price = const Value.absent(),
                Value<String?> priceCcy = const Value.absent(),
                Value<int> feeTwd = const Value.absent(),
                Value<int> proceedsOrCostTwd = const Value.absent(),
                Value<String> fxUsdTwd = const Value.absent(),
                Value<int?> realizedTwd = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradesCompanion(
                id: id,
                bookId: bookId,
                date: date,
                accountId: accountId,
                instrumentId: instrumentId,
                side: side,
                qty: qty,
                price: price,
                priceCcy: priceCcy,
                feeTwd: feeTwd,
                proceedsOrCostTwd: proceedsOrCostTwd,
                fxUsdTwd: fxUsdTwd,
                realizedTwd: realizedTwd,
                pairId: pairId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String date,
                required String accountId,
                required String instrumentId,
                required String side,
                required String qty,
                Value<String?> price = const Value.absent(),
                Value<String?> priceCcy = const Value.absent(),
                Value<int> feeTwd = const Value.absent(),
                Value<int> proceedsOrCostTwd = const Value.absent(),
                Value<String> fxUsdTwd = const Value.absent(),
                Value<int?> realizedTwd = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String> note = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradesCompanion.insert(
                id: id,
                bookId: bookId,
                date: date,
                accountId: accountId,
                instrumentId: instrumentId,
                side: side,
                qty: qty,
                price: price,
                priceCcy: priceCcy,
                feeTwd: feeTwd,
                proceedsOrCostTwd: proceedsOrCostTwd,
                fxUsdTwd: fxUsdTwd,
                realizedTwd: realizedTwd,
                pairId: pairId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TradesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradesTable,
      TradeRow,
      $$TradesTableFilterComposer,
      $$TradesTableOrderingComposer,
      $$TradesTableAnnotationComposer,
      $$TradesTableCreateCompanionBuilder,
      $$TradesTableUpdateCompanionBuilder,
      (TradeRow, BaseReferences<_$AppDatabase, $TradesTable, TradeRow>),
      TradeRow,
      PrefetchHooks Function()
    >;
typedef $$QuotesTableCreateCompanionBuilder =
    QuotesCompanion Function({
      required String instrumentId,
      required String price,
      required String ccy,
      required String asOf,
      Value<String> source,
      Value<bool> locked,
      Value<int> rowid,
    });
typedef $$QuotesTableUpdateCompanionBuilder =
    QuotesCompanion Function({
      Value<String> instrumentId,
      Value<String> price,
      Value<String> ccy,
      Value<String> asOf,
      Value<String> source,
      Value<bool> locked,
      Value<int> rowid,
    });

class $$QuotesTableFilterComposer
    extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccy => $composableBuilder(
    column: $table.ccy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuotesTableOrderingComposer
    extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccy => $composableBuilder(
    column: $table.ccy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get ccy =>
      $composableBuilder(column: $table.ccy, builder: (column) => column);

  GeneratedColumn<String> get asOf =>
      $composableBuilder(column: $table.asOf, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);
}

class $$QuotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuotesTable,
          QuoteRow,
          $$QuotesTableFilterComposer,
          $$QuotesTableOrderingComposer,
          $$QuotesTableAnnotationComposer,
          $$QuotesTableCreateCompanionBuilder,
          $$QuotesTableUpdateCompanionBuilder,
          (QuoteRow, BaseReferences<_$AppDatabase, $QuotesTable, QuoteRow>),
          QuoteRow,
          PrefetchHooks Function()
        > {
  $$QuotesTableTableManager(_$AppDatabase db, $QuotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> instrumentId = const Value.absent(),
                Value<String> price = const Value.absent(),
                Value<String> ccy = const Value.absent(),
                Value<String> asOf = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuotesCompanion(
                instrumentId: instrumentId,
                price: price,
                ccy: ccy,
                asOf: asOf,
                source: source,
                locked: locked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String instrumentId,
                required String price,
                required String ccy,
                required String asOf,
                Value<String> source = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuotesCompanion.insert(
                instrumentId: instrumentId,
                price: price,
                ccy: ccy,
                asOf: asOf,
                source: source,
                locked: locked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuotesTable,
      QuoteRow,
      $$QuotesTableFilterComposer,
      $$QuotesTableOrderingComposer,
      $$QuotesTableAnnotationComposer,
      $$QuotesTableCreateCompanionBuilder,
      $$QuotesTableUpdateCompanionBuilder,
      (QuoteRow, BaseReferences<_$AppDatabase, $QuotesTable, QuoteRow>),
      QuoteRow,
      PrefetchHooks Function()
    >;
typedef $$FxRatesTableCreateCompanionBuilder =
    FxRatesCompanion Function({
      required String bookId,
      required String usdTwd,
      required String asOf,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$FxRatesTableUpdateCompanionBuilder =
    FxRatesCompanion Function({
      Value<String> bookId,
      Value<String> usdTwd,
      Value<String> asOf,
      Value<String> source,
      Value<int> rowid,
    });

class $$FxRatesTableFilterComposer
    extends Composer<_$AppDatabase, $FxRatesTable> {
  $$FxRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usdTwd => $composableBuilder(
    column: $table.usdTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FxRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $FxRatesTable> {
  $$FxRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usdTwd => $composableBuilder(
    column: $table.usdTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FxRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FxRatesTable> {
  $$FxRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get usdTwd =>
      $composableBuilder(column: $table.usdTwd, builder: (column) => column);

  GeneratedColumn<String> get asOf =>
      $composableBuilder(column: $table.asOf, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$FxRatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FxRatesTable,
          FxRateRow,
          $$FxRatesTableFilterComposer,
          $$FxRatesTableOrderingComposer,
          $$FxRatesTableAnnotationComposer,
          $$FxRatesTableCreateCompanionBuilder,
          $$FxRatesTableUpdateCompanionBuilder,
          (FxRateRow, BaseReferences<_$AppDatabase, $FxRatesTable, FxRateRow>),
          FxRateRow,
          PrefetchHooks Function()
        > {
  $$FxRatesTableTableManager(_$AppDatabase db, $FxRatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FxRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FxRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FxRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> usdTwd = const Value.absent(),
                Value<String> asOf = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FxRatesCompanion(
                bookId: bookId,
                usdTwd: usdTwd,
                asOf: asOf,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String usdTwd,
                required String asOf,
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FxRatesCompanion.insert(
                bookId: bookId,
                usdTwd: usdTwd,
                asOf: asOf,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FxRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FxRatesTable,
      FxRateRow,
      $$FxRatesTableFilterComposer,
      $$FxRatesTableOrderingComposer,
      $$FxRatesTableAnnotationComposer,
      $$FxRatesTableCreateCompanionBuilder,
      $$FxRatesTableUpdateCompanionBuilder,
      (FxRateRow, BaseReferences<_$AppDatabase, $FxRatesTable, FxRateRow>),
      FxRateRow,
      PrefetchHooks Function()
    >;
typedef $$OpeningCashDraftsTableCreateCompanionBuilder =
    OpeningCashDraftsCompanion Function({
      required String bookId,
      required String accountId,
      required int amount,
      Value<int> rowid,
    });
typedef $$OpeningCashDraftsTableUpdateCompanionBuilder =
    OpeningCashDraftsCompanion Function({
      Value<String> bookId,
      Value<String> accountId,
      Value<int> amount,
      Value<int> rowid,
    });

class $$OpeningCashDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $OpeningCashDraftsTable> {
  $$OpeningCashDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpeningCashDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $OpeningCashDraftsTable> {
  $$OpeningCashDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpeningCashDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpeningCashDraftsTable> {
  $$OpeningCashDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);
}

class $$OpeningCashDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpeningCashDraftsTable,
          OpeningCashDraftRow,
          $$OpeningCashDraftsTableFilterComposer,
          $$OpeningCashDraftsTableOrderingComposer,
          $$OpeningCashDraftsTableAnnotationComposer,
          $$OpeningCashDraftsTableCreateCompanionBuilder,
          $$OpeningCashDraftsTableUpdateCompanionBuilder,
          (
            OpeningCashDraftRow,
            BaseReferences<
              _$AppDatabase,
              $OpeningCashDraftsTable,
              OpeningCashDraftRow
            >,
          ),
          OpeningCashDraftRow,
          PrefetchHooks Function()
        > {
  $$OpeningCashDraftsTableTableManager(
    _$AppDatabase db,
    $OpeningCashDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpeningCashDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpeningCashDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpeningCashDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpeningCashDraftsCompanion(
                bookId: bookId,
                accountId: accountId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String accountId,
                required int amount,
                Value<int> rowid = const Value.absent(),
              }) => OpeningCashDraftsCompanion.insert(
                bookId: bookId,
                accountId: accountId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpeningCashDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpeningCashDraftsTable,
      OpeningCashDraftRow,
      $$OpeningCashDraftsTableFilterComposer,
      $$OpeningCashDraftsTableOrderingComposer,
      $$OpeningCashDraftsTableAnnotationComposer,
      $$OpeningCashDraftsTableCreateCompanionBuilder,
      $$OpeningCashDraftsTableUpdateCompanionBuilder,
      (
        OpeningCashDraftRow,
        BaseReferences<
          _$AppDatabase,
          $OpeningCashDraftsTable,
          OpeningCashDraftRow
        >,
      ),
      OpeningCashDraftRow,
      PrefetchHooks Function()
    >;
typedef $$OpeningPositionDraftsTableCreateCompanionBuilder =
    OpeningPositionDraftsCompanion Function({
      required String id,
      required String bookId,
      required String accountId,
      Value<String?> instrumentId,
      required String symbol,
      Value<String> name,
      required String assetClass,
      required String quoteCurrency,
      required String qty,
      Value<String> costTwd,
      Value<bool> costUnknown,
      Value<int> rowid,
    });
typedef $$OpeningPositionDraftsTableUpdateCompanionBuilder =
    OpeningPositionDraftsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> accountId,
      Value<String?> instrumentId,
      Value<String> symbol,
      Value<String> name,
      Value<String> assetClass,
      Value<String> quoteCurrency,
      Value<String> qty,
      Value<String> costTwd,
      Value<bool> costUnknown,
      Value<int> rowid,
    });

class $$OpeningPositionDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $OpeningPositionDraftsTable> {
  $$OpeningPositionDraftsTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costTwd => $composableBuilder(
    column: $table.costTwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpeningPositionDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $OpeningPositionDraftsTable> {
  $$OpeningPositionDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costTwd => $composableBuilder(
    column: $table.costTwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpeningPositionDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpeningPositionDraftsTable> {
  $$OpeningPositionDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get instrumentId => $composableBuilder(
    column: $table.instrumentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get costTwd =>
      $composableBuilder(column: $table.costTwd, builder: (column) => column);

  GeneratedColumn<bool> get costUnknown => $composableBuilder(
    column: $table.costUnknown,
    builder: (column) => column,
  );
}

class $$OpeningPositionDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpeningPositionDraftsTable,
          OpeningPositionDraftRow,
          $$OpeningPositionDraftsTableFilterComposer,
          $$OpeningPositionDraftsTableOrderingComposer,
          $$OpeningPositionDraftsTableAnnotationComposer,
          $$OpeningPositionDraftsTableCreateCompanionBuilder,
          $$OpeningPositionDraftsTableUpdateCompanionBuilder,
          (
            OpeningPositionDraftRow,
            BaseReferences<
              _$AppDatabase,
              $OpeningPositionDraftsTable,
              OpeningPositionDraftRow
            >,
          ),
          OpeningPositionDraftRow,
          PrefetchHooks Function()
        > {
  $$OpeningPositionDraftsTableTableManager(
    _$AppDatabase db,
    $OpeningPositionDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpeningPositionDraftsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OpeningPositionDraftsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OpeningPositionDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> instrumentId = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> assetClass = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<String> qty = const Value.absent(),
                Value<String> costTwd = const Value.absent(),
                Value<bool> costUnknown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpeningPositionDraftsCompanion(
                id: id,
                bookId: bookId,
                accountId: accountId,
                instrumentId: instrumentId,
                symbol: symbol,
                name: name,
                assetClass: assetClass,
                quoteCurrency: quoteCurrency,
                qty: qty,
                costTwd: costTwd,
                costUnknown: costUnknown,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String accountId,
                Value<String?> instrumentId = const Value.absent(),
                required String symbol,
                Value<String> name = const Value.absent(),
                required String assetClass,
                required String quoteCurrency,
                required String qty,
                Value<String> costTwd = const Value.absent(),
                Value<bool> costUnknown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpeningPositionDraftsCompanion.insert(
                id: id,
                bookId: bookId,
                accountId: accountId,
                instrumentId: instrumentId,
                symbol: symbol,
                name: name,
                assetClass: assetClass,
                quoteCurrency: quoteCurrency,
                qty: qty,
                costTwd: costTwd,
                costUnknown: costUnknown,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpeningPositionDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpeningPositionDraftsTable,
      OpeningPositionDraftRow,
      $$OpeningPositionDraftsTableFilterComposer,
      $$OpeningPositionDraftsTableOrderingComposer,
      $$OpeningPositionDraftsTableAnnotationComposer,
      $$OpeningPositionDraftsTableCreateCompanionBuilder,
      $$OpeningPositionDraftsTableUpdateCompanionBuilder,
      (
        OpeningPositionDraftRow,
        BaseReferences<
          _$AppDatabase,
          $OpeningPositionDraftsTable,
          OpeningPositionDraftRow
        >,
      ),
      OpeningPositionDraftRow,
      PrefetchHooks Function()
    >;
typedef $$AppPrefsTableCreateCompanionBuilder =
    AppPrefsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppPrefsTableUpdateCompanionBuilder =
    AppPrefsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppPrefsTableFilterComposer
    extends Composer<_$AppDatabase, $AppPrefsTable> {
  $$AppPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPrefsTable> {
  $$AppPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPrefsTable> {
  $$AppPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPrefsTable,
          AppPrefRow,
          $$AppPrefsTableFilterComposer,
          $$AppPrefsTableOrderingComposer,
          $$AppPrefsTableAnnotationComposer,
          $$AppPrefsTableCreateCompanionBuilder,
          $$AppPrefsTableUpdateCompanionBuilder,
          (
            AppPrefRow,
            BaseReferences<_$AppDatabase, $AppPrefsTable, AppPrefRow>,
          ),
          AppPrefRow,
          PrefetchHooks Function()
        > {
  $$AppPrefsTableTableManager(_$AppDatabase db, $AppPrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPrefsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPrefsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPrefsTable,
      AppPrefRow,
      $$AppPrefsTableFilterComposer,
      $$AppPrefsTableOrderingComposer,
      $$AppPrefsTableAnnotationComposer,
      $$AppPrefsTableCreateCompanionBuilder,
      $$AppPrefsTableUpdateCompanionBuilder,
      (AppPrefRow, BaseReferences<_$AppDatabase, $AppPrefsTable, AppPrefRow>),
      AppPrefRow,
      PrefetchHooks Function()
    >;
typedef $$IdempotencyKeysTableCreateCompanionBuilder =
    IdempotencyKeysCompanion Function({
      required String key,
      required String method,
      required String path,
      required int responseStatus,
      required String responseBody,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$IdempotencyKeysTableUpdateCompanionBuilder =
    IdempotencyKeysCompanion Function({
      Value<String> key,
      Value<String> method,
      Value<String> path,
      Value<int> responseStatus,
      Value<String> responseBody,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$IdempotencyKeysTableFilterComposer
    extends Composer<_$AppDatabase, $IdempotencyKeysTable> {
  $$IdempotencyKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdempotencyKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $IdempotencyKeysTable> {
  $$IdempotencyKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdempotencyKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdempotencyKeysTable> {
  $$IdempotencyKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$IdempotencyKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdempotencyKeysTable,
          IdempotencyKeyRow,
          $$IdempotencyKeysTableFilterComposer,
          $$IdempotencyKeysTableOrderingComposer,
          $$IdempotencyKeysTableAnnotationComposer,
          $$IdempotencyKeysTableCreateCompanionBuilder,
          $$IdempotencyKeysTableUpdateCompanionBuilder,
          (
            IdempotencyKeyRow,
            BaseReferences<
              _$AppDatabase,
              $IdempotencyKeysTable,
              IdempotencyKeyRow
            >,
          ),
          IdempotencyKeyRow,
          PrefetchHooks Function()
        > {
  $$IdempotencyKeysTableTableManager(
    _$AppDatabase db,
    $IdempotencyKeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdempotencyKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdempotencyKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdempotencyKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> responseStatus = const Value.absent(),
                Value<String> responseBody = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdempotencyKeysCompanion(
                key: key,
                method: method,
                path: path,
                responseStatus: responseStatus,
                responseBody: responseBody,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String method,
                required String path,
                required int responseStatus,
                required String responseBody,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => IdempotencyKeysCompanion.insert(
                key: key,
                method: method,
                path: path,
                responseStatus: responseStatus,
                responseBody: responseBody,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdempotencyKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdempotencyKeysTable,
      IdempotencyKeyRow,
      $$IdempotencyKeysTableFilterComposer,
      $$IdempotencyKeysTableOrderingComposer,
      $$IdempotencyKeysTableAnnotationComposer,
      $$IdempotencyKeysTableCreateCompanionBuilder,
      $$IdempotencyKeysTableUpdateCompanionBuilder,
      (
        IdempotencyKeyRow,
        BaseReferences<_$AppDatabase, $IdempotencyKeysTable, IdempotencyKeyRow>,
      ),
      IdempotencyKeyRow,
      PrefetchHooks Function()
    >;
typedef $$ImportKeysTableCreateCompanionBuilder =
    ImportKeysCompanion Function({
      required String bookId,
      required String importKey,
      Value<String?> entryId,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ImportKeysTableUpdateCompanionBuilder =
    ImportKeysCompanion Function({
      Value<String> bookId,
      Value<String> importKey,
      Value<String?> entryId,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ImportKeysTableFilterComposer
    extends Composer<_$AppDatabase, $ImportKeysTable> {
  $$ImportKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportKeysTable> {
  $$ImportKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportKeysTable> {
  $$ImportKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get importKey =>
      $composableBuilder(column: $table.importKey, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ImportKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportKeysTable,
          ImportKeyRow,
          $$ImportKeysTableFilterComposer,
          $$ImportKeysTableOrderingComposer,
          $$ImportKeysTableAnnotationComposer,
          $$ImportKeysTableCreateCompanionBuilder,
          $$ImportKeysTableUpdateCompanionBuilder,
          (
            ImportKeyRow,
            BaseReferences<_$AppDatabase, $ImportKeysTable, ImportKeyRow>,
          ),
          ImportKeyRow,
          PrefetchHooks Function()
        > {
  $$ImportKeysTableTableManager(_$AppDatabase db, $ImportKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> importKey = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportKeysCompanion(
                bookId: bookId,
                importKey: importKey,
                entryId: entryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String importKey,
                Value<String?> entryId = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportKeysCompanion.insert(
                bookId: bookId,
                importKey: importKey,
                entryId: entryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportKeysTable,
      ImportKeyRow,
      $$ImportKeysTableFilterComposer,
      $$ImportKeysTableOrderingComposer,
      $$ImportKeysTableAnnotationComposer,
      $$ImportKeysTableCreateCompanionBuilder,
      $$ImportKeysTableUpdateCompanionBuilder,
      (
        ImportKeyRow,
        BaseReferences<_$AppDatabase, $ImportKeysTable, ImportKeyRow>,
      ),
      ImportKeyRow,
      PrefetchHooks Function()
    >;
typedef $$MerchantCategoryMapsTableCreateCompanionBuilder =
    MerchantCategoryMapsCompanion Function({
      required String bookId,
      required String merchant,
      required String categoryId,
      Value<int> rowid,
    });
typedef $$MerchantCategoryMapsTableUpdateCompanionBuilder =
    MerchantCategoryMapsCompanion Function({
      Value<String> bookId,
      Value<String> merchant,
      Value<String> categoryId,
      Value<int> rowid,
    });

class $$MerchantCategoryMapsTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantCategoryMapsTable> {
  $$MerchantCategoryMapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MerchantCategoryMapsTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantCategoryMapsTable> {
  $$MerchantCategoryMapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MerchantCategoryMapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantCategoryMapsTable> {
  $$MerchantCategoryMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );
}

class $$MerchantCategoryMapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantCategoryMapsTable,
          MerchantCategoryMapRow,
          $$MerchantCategoryMapsTableFilterComposer,
          $$MerchantCategoryMapsTableOrderingComposer,
          $$MerchantCategoryMapsTableAnnotationComposer,
          $$MerchantCategoryMapsTableCreateCompanionBuilder,
          $$MerchantCategoryMapsTableUpdateCompanionBuilder,
          (
            MerchantCategoryMapRow,
            BaseReferences<
              _$AppDatabase,
              $MerchantCategoryMapsTable,
              MerchantCategoryMapRow
            >,
          ),
          MerchantCategoryMapRow,
          PrefetchHooks Function()
        > {
  $$MerchantCategoryMapsTableTableManager(
    _$AppDatabase db,
    $MerchantCategoryMapsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantCategoryMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantCategoryMapsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MerchantCategoryMapsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> merchant = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantCategoryMapsCompanion(
                bookId: bookId,
                merchant: merchant,
                categoryId: categoryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String merchant,
                required String categoryId,
                Value<int> rowid = const Value.absent(),
              }) => MerchantCategoryMapsCompanion.insert(
                bookId: bookId,
                merchant: merchant,
                categoryId: categoryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MerchantCategoryMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantCategoryMapsTable,
      MerchantCategoryMapRow,
      $$MerchantCategoryMapsTableFilterComposer,
      $$MerchantCategoryMapsTableOrderingComposer,
      $$MerchantCategoryMapsTableAnnotationComposer,
      $$MerchantCategoryMapsTableCreateCompanionBuilder,
      $$MerchantCategoryMapsTableUpdateCompanionBuilder,
      (
        MerchantCategoryMapRow,
        BaseReferences<
          _$AppDatabase,
          $MerchantCategoryMapsTable,
          MerchantCategoryMapRow
        >,
      ),
      MerchantCategoryMapRow,
      PrefetchHooks Function()
    >;
typedef $$CardAccountMapsTableCreateCompanionBuilder =
    CardAccountMapsCompanion Function({
      required String bookId,
      required String cardLast4,
      required String accountId,
      Value<int> rowid,
    });
typedef $$CardAccountMapsTableUpdateCompanionBuilder =
    CardAccountMapsCompanion Function({
      Value<String> bookId,
      Value<String> cardLast4,
      Value<String> accountId,
      Value<int> rowid,
    });

class $$CardAccountMapsTableFilterComposer
    extends Composer<_$AppDatabase, $CardAccountMapsTable> {
  $$CardAccountMapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardLast4 => $composableBuilder(
    column: $table.cardLast4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardAccountMapsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardAccountMapsTable> {
  $$CardAccountMapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardLast4 => $composableBuilder(
    column: $table.cardLast4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardAccountMapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardAccountMapsTable> {
  $$CardAccountMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get cardLast4 =>
      $composableBuilder(column: $table.cardLast4, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);
}

class $$CardAccountMapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardAccountMapsTable,
          CardAccountMapRow,
          $$CardAccountMapsTableFilterComposer,
          $$CardAccountMapsTableOrderingComposer,
          $$CardAccountMapsTableAnnotationComposer,
          $$CardAccountMapsTableCreateCompanionBuilder,
          $$CardAccountMapsTableUpdateCompanionBuilder,
          (
            CardAccountMapRow,
            BaseReferences<
              _$AppDatabase,
              $CardAccountMapsTable,
              CardAccountMapRow
            >,
          ),
          CardAccountMapRow,
          PrefetchHooks Function()
        > {
  $$CardAccountMapsTableTableManager(
    _$AppDatabase db,
    $CardAccountMapsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardAccountMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardAccountMapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardAccountMapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> cardLast4 = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardAccountMapsCompanion(
                bookId: bookId,
                cardLast4: cardLast4,
                accountId: accountId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String cardLast4,
                required String accountId,
                Value<int> rowid = const Value.absent(),
              }) => CardAccountMapsCompanion.insert(
                bookId: bookId,
                cardLast4: cardLast4,
                accountId: accountId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardAccountMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardAccountMapsTable,
      CardAccountMapRow,
      $$CardAccountMapsTableFilterComposer,
      $$CardAccountMapsTableOrderingComposer,
      $$CardAccountMapsTableAnnotationComposer,
      $$CardAccountMapsTableCreateCompanionBuilder,
      $$CardAccountMapsTableUpdateCompanionBuilder,
      (
        CardAccountMapRow,
        BaseReferences<_$AppDatabase, $CardAccountMapsTable, CardAccountMapRow>,
      ),
      CardAccountMapRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$InstrumentsTableTableManager get instruments =>
      $$InstrumentsTableTableManager(_db, _db.instruments);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PositionsTableTableManager get positions =>
      $$PositionsTableTableManager(_db, _db.positions);
  $$TradesTableTableManager get trades =>
      $$TradesTableTableManager(_db, _db.trades);
  $$QuotesTableTableManager get quotes =>
      $$QuotesTableTableManager(_db, _db.quotes);
  $$FxRatesTableTableManager get fxRates =>
      $$FxRatesTableTableManager(_db, _db.fxRates);
  $$OpeningCashDraftsTableTableManager get openingCashDrafts =>
      $$OpeningCashDraftsTableTableManager(_db, _db.openingCashDrafts);
  $$OpeningPositionDraftsTableTableManager get openingPositionDrafts =>
      $$OpeningPositionDraftsTableTableManager(_db, _db.openingPositionDrafts);
  $$AppPrefsTableTableManager get appPrefs =>
      $$AppPrefsTableTableManager(_db, _db.appPrefs);
  $$IdempotencyKeysTableTableManager get idempotencyKeys =>
      $$IdempotencyKeysTableTableManager(_db, _db.idempotencyKeys);
  $$ImportKeysTableTableManager get importKeys =>
      $$ImportKeysTableTableManager(_db, _db.importKeys);
  $$MerchantCategoryMapsTableTableManager get merchantCategoryMaps =>
      $$MerchantCategoryMapsTableTableManager(_db, _db.merchantCategoryMaps);
  $$CardAccountMapsTableTableManager get cardAccountMaps =>
      $$CardAccountMapsTableTableManager(_db, _db.cardAccountMaps);
}
