// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $PresetsTable extends Presets with TableInfo<$PresetsTable, Preset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<int> repeat = GeneratedColumn<int>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    stepsJson,
    repeat,
    muted,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Preset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat'],
      )!,
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PresetsTable createAlias(String alias) {
    return $PresetsTable(attachedDatabase, alias);
  }
}

class Preset extends DataClass implements Insertable<Preset> {
  final int id;
  final String name;

  /// JSON: [{"type":"focus"|"rest","seconds":int,"sound"?:string}, ...]
  final String stepsJson;
  final int repeat;

  /// Tắt âm thanh riêng cho session này (thêm ở schema v2).
  final bool muted;

  /// Thứ tự hiển thị trên màn chính, kéo thả để đổi (thêm ở schema v3).
  final int sortOrder;
  const Preset({
    required this.id,
    required this.name,
    required this.stepsJson,
    required this.repeat,
    required this.muted,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['steps_json'] = Variable<String>(stepsJson);
    map['repeat'] = Variable<int>(repeat);
    map['muted'] = Variable<bool>(muted);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PresetsCompanion toCompanion(bool nullToAbsent) {
    return PresetsCompanion(
      id: Value(id),
      name: Value(name),
      stepsJson: Value(stepsJson),
      repeat: Value(repeat),
      muted: Value(muted),
      sortOrder: Value(sortOrder),
    );
  }

  factory Preset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preset(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      repeat: serializer.fromJson<int>(json['repeat']),
      muted: serializer.fromJson<bool>(json['muted']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'repeat': serializer.toJson<int>(repeat),
      'muted': serializer.toJson<bool>(muted),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Preset copyWith({
    int? id,
    String? name,
    String? stepsJson,
    int? repeat,
    bool? muted,
    int? sortOrder,
  }) => Preset(
    id: id ?? this.id,
    name: name ?? this.name,
    stepsJson: stepsJson ?? this.stepsJson,
    repeat: repeat ?? this.repeat,
    muted: muted ?? this.muted,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Preset copyWithCompanion(PresetsCompanion data) {
    return Preset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      muted: data.muted.present ? data.muted.value : this.muted,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('repeat: $repeat, ')
          ..write('muted: $muted, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, stepsJson, repeat, muted, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preset &&
          other.id == this.id &&
          other.name == this.name &&
          other.stepsJson == this.stepsJson &&
          other.repeat == this.repeat &&
          other.muted == this.muted &&
          other.sortOrder == this.sortOrder);
}

class PresetsCompanion extends UpdateCompanion<Preset> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> stepsJson;
  final Value<int> repeat;
  final Value<bool> muted;
  final Value<int> sortOrder;
  const PresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.repeat = const Value.absent(),
    this.muted = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  PresetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String stepsJson,
    this.repeat = const Value.absent(),
    this.muted = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name),
       stepsJson = Value(stepsJson);
  static Insertable<Preset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? stepsJson,
    Expression<int>? repeat,
    Expression<bool>? muted,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (repeat != null) 'repeat': repeat,
      if (muted != null) 'muted': muted,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  PresetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? stepsJson,
    Value<int>? repeat,
    Value<bool>? muted,
    Value<int>? sortOrder,
  }) {
    return PresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      stepsJson: stepsJson ?? this.stepsJson,
      repeat: repeat ?? this.repeat,
      muted: muted ?? this.muted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<int>(repeat.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('repeat: $repeat, ')
          ..write('muted: $muted, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $CompletedSessionsTable extends CompletedSessions
    with TableInfo<$CompletedSessionsTable, CompletedSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletedSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _presetIdMeta = const VerificationMeta(
    'presetId',
  );
  @override
  late final GeneratedColumn<int> presetId = GeneratedColumn<int>(
    'preset_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES presets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusSecondsMeta = const VerificationMeta(
    'focusSeconds',
  );
  @override
  late final GeneratedColumn<int> focusSeconds = GeneratedColumn<int>(
    'focus_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    presetId,
    startedAt,
    endedAt,
    focusSeconds,
    day,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completed_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletedSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('preset_id')) {
      context.handle(
        _presetIdMeta,
        presetId.isAcceptableOrUnknown(data['preset_id']!, _presetIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('focus_seconds')) {
      context.handle(
        _focusSecondsMeta,
        focusSeconds.isAcceptableOrUnknown(
          data['focus_seconds']!,
          _focusSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_focusSecondsMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletedSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletedSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      presetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preset_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      focusSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_seconds'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
    );
  }

  @override
  $CompletedSessionsTable createAlias(String alias) {
    return $CompletedSessionsTable(attachedDatabase, alias);
  }
}

class CompletedSession extends DataClass
    implements Insertable<CompletedSession> {
  final int id;
  final int? presetId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int focusSeconds;

  /// Ngày kết thúc phiên theo giờ máy, dạng yyyy-MM-dd.
  final String day;
  const CompletedSession({
    required this.id,
    this.presetId,
    required this.startedAt,
    required this.endedAt,
    required this.focusSeconds,
    required this.day,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || presetId != null) {
      map['preset_id'] = Variable<int>(presetId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['focus_seconds'] = Variable<int>(focusSeconds);
    map['day'] = Variable<String>(day);
    return map;
  }

  CompletedSessionsCompanion toCompanion(bool nullToAbsent) {
    return CompletedSessionsCompanion(
      id: Value(id),
      presetId: presetId == null && nullToAbsent
          ? const Value.absent()
          : Value(presetId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      focusSeconds: Value(focusSeconds),
      day: Value(day),
    );
  }

  factory CompletedSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletedSession(
      id: serializer.fromJson<int>(json['id']),
      presetId: serializer.fromJson<int?>(json['presetId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      focusSeconds: serializer.fromJson<int>(json['focusSeconds']),
      day: serializer.fromJson<String>(json['day']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'presetId': serializer.toJson<int?>(presetId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'focusSeconds': serializer.toJson<int>(focusSeconds),
      'day': serializer.toJson<String>(day),
    };
  }

  CompletedSession copyWith({
    int? id,
    Value<int?> presetId = const Value.absent(),
    DateTime? startedAt,
    DateTime? endedAt,
    int? focusSeconds,
    String? day,
  }) => CompletedSession(
    id: id ?? this.id,
    presetId: presetId.present ? presetId.value : this.presetId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    focusSeconds: focusSeconds ?? this.focusSeconds,
    day: day ?? this.day,
  );
  CompletedSession copyWithCompanion(CompletedSessionsCompanion data) {
    return CompletedSession(
      id: data.id.present ? data.id.value : this.id,
      presetId: data.presetId.present ? data.presetId.value : this.presetId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      focusSeconds: data.focusSeconds.present
          ? data.focusSeconds.value
          : this.focusSeconds,
      day: data.day.present ? data.day.value : this.day,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletedSession(')
          ..write('id: $id, ')
          ..write('presetId: $presetId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('focusSeconds: $focusSeconds, ')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, presetId, startedAt, endedAt, focusSeconds, day);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedSession &&
          other.id == this.id &&
          other.presetId == this.presetId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.focusSeconds == this.focusSeconds &&
          other.day == this.day);
}

class CompletedSessionsCompanion extends UpdateCompanion<CompletedSession> {
  final Value<int> id;
  final Value<int?> presetId;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> focusSeconds;
  final Value<String> day;
  const CompletedSessionsCompanion({
    this.id = const Value.absent(),
    this.presetId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.focusSeconds = const Value.absent(),
    this.day = const Value.absent(),
  });
  CompletedSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.presetId = const Value.absent(),
    required DateTime startedAt,
    required DateTime endedAt,
    required int focusSeconds,
    required String day,
  }) : startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       focusSeconds = Value(focusSeconds),
       day = Value(day);
  static Insertable<CompletedSession> custom({
    Expression<int>? id,
    Expression<int>? presetId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? focusSeconds,
    Expression<String>? day,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (presetId != null) 'preset_id': presetId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (focusSeconds != null) 'focus_seconds': focusSeconds,
      if (day != null) 'day': day,
    });
  }

  CompletedSessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? presetId,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? focusSeconds,
    Value<String>? day,
  }) {
    return CompletedSessionsCompanion(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      day: day ?? this.day,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (presetId.present) {
      map['preset_id'] = Variable<int>(presetId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (focusSeconds.present) {
      map['focus_seconds'] = Variable<int>(focusSeconds.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletedSessionsCompanion(')
          ..write('id: $id, ')
          ..write('presetId: $presetId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('focusSeconds: $focusSeconds, ')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PresetsTable presets = $PresetsTable(this);
  late final $CompletedSessionsTable completedSessions =
      $CompletedSessionsTable(this);
  late final Index idxCompletedSessionsDay = Index(
    'idx_completed_sessions_day',
    'CREATE INDEX idx_completed_sessions_day ON completed_sessions (day)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    presets,
    completedSessions,
    idxCompletedSessionsDay,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'presets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('completed_sessions', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$PresetsTableCreateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      required String name,
      required String stepsJson,
      Value<int> repeat,
      Value<bool> muted,
      Value<int> sortOrder,
    });
typedef $$PresetsTableUpdateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> stepsJson,
      Value<int> repeat,
      Value<bool> muted,
      Value<int> sortOrder,
    });

final class $$PresetsTableReferences
    extends BaseReferences<_$AppDatabase, $PresetsTable, Preset> {
  $$PresetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CompletedSessionsTable, List<CompletedSession>>
  _completedSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.completedSessions,
        aliasName: 'presets__id__completed_sessions__preset_id',
      );

  $$CompletedSessionsTableProcessedTableManager get completedSessionsRefs {
    final manager = $$CompletedSessionsTableTableManager(
      $_db,
      $_db.completedSessions,
    ).filter((f) => f.presetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _completedSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PresetsTableFilterComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> completedSessionsRefs(
    Expression<bool> Function($$CompletedSessionsTableFilterComposer f) f,
  ) {
    final $$CompletedSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completedSessions,
      getReferencedColumn: (t) => t.presetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletedSessionsTableFilterComposer(
            $db: $db,
            $table: $db.completedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<int> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> completedSessionsRefs<T extends Object>(
    Expression<T> Function($$CompletedSessionsTableAnnotationComposer a) f,
  ) {
    final $$CompletedSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.completedSessions,
          getReferencedColumn: (t) => t.presetId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CompletedSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.completedSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PresetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PresetsTable,
          Preset,
          $$PresetsTableFilterComposer,
          $$PresetsTableOrderingComposer,
          $$PresetsTableAnnotationComposer,
          $$PresetsTableCreateCompanionBuilder,
          $$PresetsTableUpdateCompanionBuilder,
          (Preset, $$PresetsTableReferences),
          Preset,
          PrefetchHooks Function({bool completedSessionsRefs})
        > {
  $$PresetsTableTableManager(_$AppDatabase db, $PresetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<int> repeat = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => PresetsCompanion(
                id: id,
                name: name,
                stepsJson: stepsJson,
                repeat: repeat,
                muted: muted,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String stepsJson,
                Value<int> repeat = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => PresetsCompanion.insert(
                id: id,
                name: name,
                stepsJson: stepsJson,
                repeat: repeat,
                muted: muted,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PresetsTable, Preset>(table),
                  $$PresetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({completedSessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (completedSessionsRefs) db.completedSessions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (completedSessionsRefs)
                    await $_getPrefetchedData<
                      Preset,
                      $PresetsTable,
                      CompletedSession
                    >(
                      currentTable: table,
                      referencedTable: $$PresetsTableReferences
                          ._completedSessionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PresetsTableReferences(
                        db,
                        table,
                        p0,
                      ).completedSessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.presetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PresetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PresetsTable,
      Preset,
      $$PresetsTableFilterComposer,
      $$PresetsTableOrderingComposer,
      $$PresetsTableAnnotationComposer,
      $$PresetsTableCreateCompanionBuilder,
      $$PresetsTableUpdateCompanionBuilder,
      (Preset, $$PresetsTableReferences),
      Preset,
      PrefetchHooks Function({bool completedSessionsRefs})
    >;
typedef $$CompletedSessionsTableCreateCompanionBuilder =
    CompletedSessionsCompanion Function({
      Value<int> id,
      Value<int?> presetId,
      required DateTime startedAt,
      required DateTime endedAt,
      required int focusSeconds,
      required String day,
    });
typedef $$CompletedSessionsTableUpdateCompanionBuilder =
    CompletedSessionsCompanion Function({
      Value<int> id,
      Value<int?> presetId,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> focusSeconds,
      Value<String> day,
    });

final class $$CompletedSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CompletedSessionsTable,
          CompletedSession
        > {
  $$CompletedSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PresetsTable _presetIdTable(_$AppDatabase db) =>
      db.presets.createAlias('completed_sessions__preset_id__presets__id');

  $$PresetsTableProcessedTableManager? get presetId {
    final $_column = $_itemColumn<int>('preset_id');
    if ($_column == null) return null;
    final manager = $$PresetsTableTableManager(
      $_db,
      $_db.presets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_presetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CompletedSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletedSessionsTable> {
  $$CompletedSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusSeconds => $composableBuilder(
    column: $table.focusSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  $$PresetsTableFilterComposer get presetId {
    final $$PresetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.presetId,
      referencedTable: $db.presets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PresetsTableFilterComposer(
            $db: $db,
            $table: $db.presets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletedSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletedSessionsTable> {
  $$CompletedSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusSeconds => $composableBuilder(
    column: $table.focusSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  $$PresetsTableOrderingComposer get presetId {
    final $$PresetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.presetId,
      referencedTable: $db.presets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PresetsTableOrderingComposer(
            $db: $db,
            $table: $db.presets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletedSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletedSessionsTable> {
  $$CompletedSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get focusSeconds => $composableBuilder(
    column: $table.focusSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  $$PresetsTableAnnotationComposer get presetId {
    final $$PresetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.presetId,
      referencedTable: $db.presets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PresetsTableAnnotationComposer(
            $db: $db,
            $table: $db.presets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletedSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletedSessionsTable,
          CompletedSession,
          $$CompletedSessionsTableFilterComposer,
          $$CompletedSessionsTableOrderingComposer,
          $$CompletedSessionsTableAnnotationComposer,
          $$CompletedSessionsTableCreateCompanionBuilder,
          $$CompletedSessionsTableUpdateCompanionBuilder,
          (CompletedSession, $$CompletedSessionsTableReferences),
          CompletedSession,
          PrefetchHooks Function({bool presetId})
        > {
  $$CompletedSessionsTableTableManager(
    _$AppDatabase db,
    $CompletedSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletedSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletedSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletedSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> presetId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> focusSeconds = const Value.absent(),
                Value<String> day = const Value.absent(),
              }) => CompletedSessionsCompanion(
                id: id,
                presetId: presetId,
                startedAt: startedAt,
                endedAt: endedAt,
                focusSeconds: focusSeconds,
                day: day,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> presetId = const Value.absent(),
                required DateTime startedAt,
                required DateTime endedAt,
                required int focusSeconds,
                required String day,
              }) => CompletedSessionsCompanion.insert(
                id: id,
                presetId: presetId,
                startedAt: startedAt,
                endedAt: endedAt,
                focusSeconds: focusSeconds,
                day: day,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CompletedSessionsTable, CompletedSession>(table),
                  $$CompletedSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({presetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (presetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.presetId,
                                referencedTable:
                                    $$CompletedSessionsTableReferences
                                        ._presetIdTable(db),
                                referencedColumn:
                                    $$CompletedSessionsTableReferences
                                        ._presetIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CompletedSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletedSessionsTable,
      CompletedSession,
      $$CompletedSessionsTableFilterComposer,
      $$CompletedSessionsTableOrderingComposer,
      $$CompletedSessionsTableAnnotationComposer,
      $$CompletedSessionsTableCreateCompanionBuilder,
      $$CompletedSessionsTableUpdateCompanionBuilder,
      (CompletedSession, $$CompletedSessionsTableReferences),
      CompletedSession,
      PrefetchHooks Function({bool presetId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PresetsTableTableManager get presets =>
      $$PresetsTableTableManager(_db, _db.presets);
  $$CompletedSessionsTableTableManager get completedSessions =>
      $$CompletedSessionsTableTableManager(_db, _db.completedSessions);
}
