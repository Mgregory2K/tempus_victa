// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This file is intentionally checked in to keep Tempus Victa builds reproducible
// without requiring build_runner on every machine.
//
// Minimal schema for Phase 0/1:
//  - SignalTable
//  - TimeSavingsTable
//
// ignore_for_file: type=lint, unnecessary_brace_in_string_interps, non_constant_identifier_names

part of 'app_db.dart';

class SignalTableData extends DataClass implements Insertable<SignalTableData> {
  final String id;
  final DateTime receivedAt;
  final String sourcePackage;
  final String? title;
  final String? body;
  final String rawJson;
  final int dayKey;

  const SignalTableData({
    required this.id,
    required this.receivedAt,
    required this.sourcePackage,
    this.title,
    this.body,
    required this.rawJson,
    required this.dayKey,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['source_package'] = Variable<String>(sourcePackage);
    if (title != null) map['title'] = Variable<String>(title);
    if (body != null) map['body'] = Variable<String>(body);
    map['raw_json'] = Variable<String>(rawJson);
    map['day_key'] = Variable<int>(dayKey);
    return map;
  }

  SignalTableCompanion toCompanion(bool nullToAbsent) => SignalTableCompanion(
        id: Value(id),
        receivedAt: Value(receivedAt),
        sourcePackage: Value(sourcePackage),
        title: title == null && nullToAbsent ? const Value.absent() : Value(title),
        body: body == null && nullToAbsent ? const Value.absent() : Value(body),
        rawJson: Value(rawJson),
        dayKey: Value(dayKey),
      );
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    return <String, dynamic>{
      'id': id,
      'receivedAt': receivedAt.toIso8601String(),
      'sourcePackage': sourcePackage,
      'title': title,
      'body': body,
      'rawJson': rawJson,
      'dayKey': dayKey,
    };
  }

}

class SignalTableCompanion extends UpdateCompanion<SignalTableData> {
  final Value<String> id;
  final Value<DateTime> receivedAt;
  final Value<String> sourcePackage;
  final Value<String?> title;
  final Value<String?> body;
  final Value<String> rawJson;
  final Value<int> dayKey;

  const SignalTableCompanion({
    this.id = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.sourcePackage = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.dayKey = const Value.absent(),
  });

  SignalTableCompanion.insert({
    required String id,
    required DateTime receivedAt,
    required String sourcePackage,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    required String rawJson,
    required int dayKey,
  })  : id = Value(id),
        receivedAt = Value(receivedAt),
        sourcePackage = Value(sourcePackage),
        rawJson = Value(rawJson),
        dayKey = Value(dayKey);

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (receivedAt.present) map['received_at'] = Variable<DateTime>(receivedAt.value);
    if (sourcePackage.present) map['source_package'] = Variable<String>(sourcePackage.value);
    if (title.present && title.value != null) map['title'] = Variable<String>(title.value!);
    if (body.present && body.value != null) map['body'] = Variable<String>(body.value!);
    if (rawJson.present) map['raw_json'] = Variable<String>(rawJson.value);
    if (dayKey.present) map['day_key'] = Variable<int>(dayKey.value);
    return map;
  }
}

class $SignalTableTable extends SignalTable with TableInfo<$SignalTableTable, SignalTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  $SignalTableTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _receivedAtMeta = VerificationMeta('receivedAt');
  static const VerificationMeta _sourcePackageMeta = VerificationMeta('sourcePackage');
  static const VerificationMeta _titleMeta = VerificationMeta('title');
  static const VerificationMeta _bodyMeta = VerificationMeta('body');
  static const VerificationMeta _rawJsonMeta = VerificationMeta('rawJson');
  static const VerificationMeta _dayKeyMeta = VerificationMeta('dayKey');

  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<String> sourcePackage = GeneratedColumn<String>(
    'source_package',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );

  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );

  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<int> dayKey = GeneratedColumn<int>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );

  @override
  List<GeneratedColumn> get $columns => [id, receivedAt, sourcePackage, title, body, rawJson, dayKey];

  @override
  String get aliasedName => _alias ?? 'signal_table';

  @override
  String get actualTableName => 'signal_table';

  @override
  VerificationContext validateIntegrity(Insertable<SignalTableData> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(_receivedAtMeta, receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('source_package')) {
      context.handle(_sourcePackageMeta, sourcePackage.isAcceptableOrUnknown(data['source_package']!, _sourcePackageMeta));
    } else if (isInserting) {
      context.missing(_sourcePackageMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta, rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(_dayKeyMeta, dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta));
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  SignalTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '${tablePrefix}.' : '';
    return SignalTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      receivedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      sourcePackage: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_package'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title']),
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body']),
      rawJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}raw_json'])!,
      dayKey: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}day_key'])!,
    );
  }

  @override
  $SignalTableTable createAlias(String alias) => $SignalTableTable(attachedDatabase, alias);
}

class TimeSavingsTableData extends DataClass implements Insertable<TimeSavingsTableData> {
  final String id;
  final String category;
  final int secondsSaved;
  final double confidence;
  final String? traceId;
  final DateTime createdAt;

  const TimeSavingsTableData({
    required this.id,
    required this.category,
    required this.secondsSaved,
    required this.confidence,
    this.traceId,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['seconds_saved'] = Variable<int>(secondsSaved);
    map['confidence'] = Variable<double>(confidence);
    if (traceId != null) map['trace_id'] = Variable<String>(traceId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TimeSavingsTableCompanion toCompanion(bool nullToAbsent) => TimeSavingsTableCompanion(
        id: Value(id),
        category: Value(category),
        secondsSaved: Value(secondsSaved),
        confidence: Value(confidence),
        traceId: traceId == null && nullToAbsent ? const Value.absent() : Value(traceId),
        createdAt: Value(createdAt),
      );
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'secondsSaved': secondsSaved,
      'confidence': confidence,
      'traceId': traceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

}

class TimeSavingsTableCompanion extends UpdateCompanion<TimeSavingsTableData> {
  final Value<String> id;
  final Value<String> category;
  final Value<int> secondsSaved;
  final Value<double> confidence;
  final Value<String?> traceId;
  final Value<DateTime> createdAt;

  const TimeSavingsTableCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.secondsSaved = const Value.absent(),
    this.confidence = const Value.absent(),
    this.traceId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  TimeSavingsTableCompanion.insert({
    required String id,
    required String category,
    required int secondsSaved,
    this.confidence = const Value.absent(),
    this.traceId = const Value.absent(),
    required DateTime createdAt,
  })  : id = Value(id),
        category = Value(category),
        secondsSaved = Value(secondsSaved),
        createdAt = Value(createdAt);

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (category.present) map['category'] = Variable<String>(category.value);
    if (secondsSaved.present) map['seconds_saved'] = Variable<int>(secondsSaved.value);
    if (confidence.present) map['confidence'] = Variable<double>(confidence.value);
    if (traceId.present && traceId.value != null) map['trace_id'] = Variable<String>(traceId.value!);
    if (createdAt.present) map['created_at'] = Variable<DateTime>(createdAt.value);
    return map;
  }
}

class $TimeSavingsTableTable extends TimeSavingsTable
    with TableInfo<$TimeSavingsTableTable, TimeSavingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  $TimeSavingsTableTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _categoryMeta = VerificationMeta('category');
  static const VerificationMeta _secondsSavedMeta = VerificationMeta('secondsSaved');
  static const VerificationMeta _confidenceMeta = VerificationMeta('confidence');
  static const VerificationMeta _traceIdMeta = VerificationMeta('traceId');
  static const VerificationMeta _createdAtMeta = VerificationMeta('createdAt');

  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<int> secondsSaved = GeneratedColumn<int>(
    'seconds_saved',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );

  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );

  @override
  late final GeneratedColumn<String> traceId = GeneratedColumn<String>(
    'trace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );

  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );

  @override
  List<GeneratedColumn> get $columns => [id, category, secondsSaved, confidence, traceId, createdAt];

  @override
  String get aliasedName => _alias ?? 'time_savings_table';

  @override
  String get actualTableName => 'time_savings_table';

  @override
  VerificationContext validateIntegrity(Insertable<TimeSavingsTableData> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta, category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('seconds_saved')) {
      context.handle(_secondsSavedMeta, secondsSaved.isAcceptableOrUnknown(data['seconds_saved']!, _secondsSavedMeta));
    } else if (isInserting) {
      context.missing(_secondsSavedMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(_confidenceMeta, confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta));
    }
    if (data.containsKey('trace_id')) {
      context.handle(_traceIdMeta, traceId.isAcceptableOrUnknown(data['trace_id']!, _traceIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  TimeSavingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '${tablePrefix}.' : '';
    return TimeSavingsTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      category: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      secondsSaved: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seconds_saved'])!,
      confidence: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}confidence'])!,
      traceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}trace_id']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TimeSavingsTableTable createAlias(String alias) => $TimeSavingsTableTable(attachedDatabase, alias);
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);

  late final $SignalTableTable signalTable = $SignalTableTable(this);
  late final $TimeSavingsTableTable timeSavingsTable = $TimeSavingsTableTable(this);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [signalTable, timeSavingsTable];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [signalTable, timeSavingsTable];
}
