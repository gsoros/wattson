// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RidesTable extends Rides with TableInfo<$RidesTable, Ride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RidesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeInMotionMeta = const VerificationMeta(
    'timeInMotion',
  );
  @override
  late final GeneratedColumn<double> timeInMotion = GeneratedColumn<double>(
    'time_in_motion',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanceKmMeta = const VerificationMeta(
    'distanceKm',
  );
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
    'distance_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _elevationGainMMeta = const VerificationMeta(
    'elevationGainM',
  );
  @override
  late final GeneratedColumn<double> elevationGainM = GeneratedColumn<double>(
    'elevation_gain_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgHumanPowerWMeta = const VerificationMeta(
    'avgHumanPowerW',
  );
  @override
  late final GeneratedColumn<double> avgHumanPowerW = GeneratedColumn<double>(
    'avg_human_power_w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxHumanPowerWMeta = const VerificationMeta(
    'maxHumanPowerW',
  );
  @override
  late final GeneratedColumn<double> maxHumanPowerW = GeneratedColumn<double>(
    'max_human_power_w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgMotorPowerWMeta = const VerificationMeta(
    'avgMotorPowerW',
  );
  @override
  late final GeneratedColumn<double> avgMotorPowerW = GeneratedColumn<double>(
    'avg_motor_power_w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgCadenceRpmMeta = const VerificationMeta(
    'avgCadenceRpm',
  );
  @override
  late final GeneratedColumn<double> avgCadenceRpm = GeneratedColumn<double>(
    'avg_cadence_rpm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgHrBpmMeta = const VerificationMeta(
    'avgHrBpm',
  );
  @override
  late final GeneratedColumn<double> avgHrBpm = GeneratedColumn<double>(
    'avg_hr_bpm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistRatioMeta = const VerificationMeta(
    'assistRatio',
  );
  @override
  late final GeneratedColumn<double> assistRatio = GeneratedColumn<double>(
    'assist_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startTime,
    endTime,
    timeInMotion,
    distanceKm,
    elevationGainM,
    avgHumanPowerW,
    maxHumanPowerW,
    avgMotorPowerW,
    avgCadenceRpm,
    avgHrBpm,
    assistRatio,
    notes,
    title,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rides';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('time_in_motion')) {
      context.handle(
        _timeInMotionMeta,
        timeInMotion.isAcceptableOrUnknown(
          data['time_in_motion']!,
          _timeInMotionMeta,
        ),
      );
    }
    if (data.containsKey('distance_km')) {
      context.handle(
        _distanceKmMeta,
        distanceKm.isAcceptableOrUnknown(data['distance_km']!, _distanceKmMeta),
      );
    }
    if (data.containsKey('elevation_gain_m')) {
      context.handle(
        _elevationGainMMeta,
        elevationGainM.isAcceptableOrUnknown(
          data['elevation_gain_m']!,
          _elevationGainMMeta,
        ),
      );
    }
    if (data.containsKey('avg_human_power_w')) {
      context.handle(
        _avgHumanPowerWMeta,
        avgHumanPowerW.isAcceptableOrUnknown(
          data['avg_human_power_w']!,
          _avgHumanPowerWMeta,
        ),
      );
    }
    if (data.containsKey('max_human_power_w')) {
      context.handle(
        _maxHumanPowerWMeta,
        maxHumanPowerW.isAcceptableOrUnknown(
          data['max_human_power_w']!,
          _maxHumanPowerWMeta,
        ),
      );
    }
    if (data.containsKey('avg_motor_power_w')) {
      context.handle(
        _avgMotorPowerWMeta,
        avgMotorPowerW.isAcceptableOrUnknown(
          data['avg_motor_power_w']!,
          _avgMotorPowerWMeta,
        ),
      );
    }
    if (data.containsKey('avg_cadence_rpm')) {
      context.handle(
        _avgCadenceRpmMeta,
        avgCadenceRpm.isAcceptableOrUnknown(
          data['avg_cadence_rpm']!,
          _avgCadenceRpmMeta,
        ),
      );
    }
    if (data.containsKey('avg_hr_bpm')) {
      context.handle(
        _avgHrBpmMeta,
        avgHrBpm.isAcceptableOrUnknown(data['avg_hr_bpm']!, _avgHrBpmMeta),
      );
    }
    if (data.containsKey('assist_ratio')) {
      context.handle(
        _assistRatioMeta,
        assistRatio.isAcceptableOrUnknown(
          data['assist_ratio']!,
          _assistRatioMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ride(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      timeInMotion: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}time_in_motion'],
      )!,
      distanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_km'],
      )!,
      elevationGainM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_gain_m'],
      )!,
      avgHumanPowerW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_human_power_w'],
      ),
      maxHumanPowerW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_human_power_w'],
      ),
      avgMotorPowerW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_motor_power_w'],
      ),
      avgCadenceRpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_cadence_rpm'],
      ),
      avgHrBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_hr_bpm'],
      ),
      assistRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}assist_ratio'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
    );
  }

  @override
  $RidesTable createAlias(String alias) {
    return $RidesTable(attachedDatabase, alias);
  }
}

class Ride extends DataClass implements Insertable<Ride> {
  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double timeInMotion;
  final double distanceKm;
  final double elevationGainM;
  final double? avgHumanPowerW;
  final double? maxHumanPowerW;
  final double? avgMotorPowerW;
  final double? avgCadenceRpm;
  final double? avgHrBpm;
  final double? assistRatio;
  final String? notes;

  /// User-editable name for the ride. Null/empty falls back to a date label.
  final String? title;
  const Ride({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.timeInMotion,
    required this.distanceKm,
    required this.elevationGainM,
    this.avgHumanPowerW,
    this.maxHumanPowerW,
    this.avgMotorPowerW,
    this.avgCadenceRpm,
    this.avgHrBpm,
    this.assistRatio,
    this.notes,
    this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['time_in_motion'] = Variable<double>(timeInMotion);
    map['distance_km'] = Variable<double>(distanceKm);
    map['elevation_gain_m'] = Variable<double>(elevationGainM);
    if (!nullToAbsent || avgHumanPowerW != null) {
      map['avg_human_power_w'] = Variable<double>(avgHumanPowerW);
    }
    if (!nullToAbsent || maxHumanPowerW != null) {
      map['max_human_power_w'] = Variable<double>(maxHumanPowerW);
    }
    if (!nullToAbsent || avgMotorPowerW != null) {
      map['avg_motor_power_w'] = Variable<double>(avgMotorPowerW);
    }
    if (!nullToAbsent || avgCadenceRpm != null) {
      map['avg_cadence_rpm'] = Variable<double>(avgCadenceRpm);
    }
    if (!nullToAbsent || avgHrBpm != null) {
      map['avg_hr_bpm'] = Variable<double>(avgHrBpm);
    }
    if (!nullToAbsent || assistRatio != null) {
      map['assist_ratio'] = Variable<double>(assistRatio);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    return map;
  }

  RidesCompanion toCompanion(bool nullToAbsent) {
    return RidesCompanion(
      id: Value(id),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      timeInMotion: Value(timeInMotion),
      distanceKm: Value(distanceKm),
      elevationGainM: Value(elevationGainM),
      avgHumanPowerW: avgHumanPowerW == null && nullToAbsent
          ? const Value.absent()
          : Value(avgHumanPowerW),
      maxHumanPowerW: maxHumanPowerW == null && nullToAbsent
          ? const Value.absent()
          : Value(maxHumanPowerW),
      avgMotorPowerW: avgMotorPowerW == null && nullToAbsent
          ? const Value.absent()
          : Value(avgMotorPowerW),
      avgCadenceRpm: avgCadenceRpm == null && nullToAbsent
          ? const Value.absent()
          : Value(avgCadenceRpm),
      avgHrBpm: avgHrBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(avgHrBpm),
      assistRatio: assistRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(assistRatio),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
    );
  }

  factory Ride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ride(
      id: serializer.fromJson<int>(json['id']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      timeInMotion: serializer.fromJson<double>(json['timeInMotion']),
      distanceKm: serializer.fromJson<double>(json['distanceKm']),
      elevationGainM: serializer.fromJson<double>(json['elevationGainM']),
      avgHumanPowerW: serializer.fromJson<double?>(json['avgHumanPowerW']),
      maxHumanPowerW: serializer.fromJson<double?>(json['maxHumanPowerW']),
      avgMotorPowerW: serializer.fromJson<double?>(json['avgMotorPowerW']),
      avgCadenceRpm: serializer.fromJson<double?>(json['avgCadenceRpm']),
      avgHrBpm: serializer.fromJson<double?>(json['avgHrBpm']),
      assistRatio: serializer.fromJson<double?>(json['assistRatio']),
      notes: serializer.fromJson<String?>(json['notes']),
      title: serializer.fromJson<String?>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'timeInMotion': serializer.toJson<double>(timeInMotion),
      'distanceKm': serializer.toJson<double>(distanceKm),
      'elevationGainM': serializer.toJson<double>(elevationGainM),
      'avgHumanPowerW': serializer.toJson<double?>(avgHumanPowerW),
      'maxHumanPowerW': serializer.toJson<double?>(maxHumanPowerW),
      'avgMotorPowerW': serializer.toJson<double?>(avgMotorPowerW),
      'avgCadenceRpm': serializer.toJson<double?>(avgCadenceRpm),
      'avgHrBpm': serializer.toJson<double?>(avgHrBpm),
      'assistRatio': serializer.toJson<double?>(assistRatio),
      'notes': serializer.toJson<String?>(notes),
      'title': serializer.toJson<String?>(title),
    };
  }

  Ride copyWith({
    int? id,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    double? timeInMotion,
    double? distanceKm,
    double? elevationGainM,
    Value<double?> avgHumanPowerW = const Value.absent(),
    Value<double?> maxHumanPowerW = const Value.absent(),
    Value<double?> avgMotorPowerW = const Value.absent(),
    Value<double?> avgCadenceRpm = const Value.absent(),
    Value<double?> avgHrBpm = const Value.absent(),
    Value<double?> assistRatio = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> title = const Value.absent(),
  }) => Ride(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    timeInMotion: timeInMotion ?? this.timeInMotion,
    distanceKm: distanceKm ?? this.distanceKm,
    elevationGainM: elevationGainM ?? this.elevationGainM,
    avgHumanPowerW: avgHumanPowerW.present
        ? avgHumanPowerW.value
        : this.avgHumanPowerW,
    maxHumanPowerW: maxHumanPowerW.present
        ? maxHumanPowerW.value
        : this.maxHumanPowerW,
    avgMotorPowerW: avgMotorPowerW.present
        ? avgMotorPowerW.value
        : this.avgMotorPowerW,
    avgCadenceRpm: avgCadenceRpm.present
        ? avgCadenceRpm.value
        : this.avgCadenceRpm,
    avgHrBpm: avgHrBpm.present ? avgHrBpm.value : this.avgHrBpm,
    assistRatio: assistRatio.present ? assistRatio.value : this.assistRatio,
    notes: notes.present ? notes.value : this.notes,
    title: title.present ? title.value : this.title,
  );
  Ride copyWithCompanion(RidesCompanion data) {
    return Ride(
      id: data.id.present ? data.id.value : this.id,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      timeInMotion: data.timeInMotion.present
          ? data.timeInMotion.value
          : this.timeInMotion,
      distanceKm: data.distanceKm.present
          ? data.distanceKm.value
          : this.distanceKm,
      elevationGainM: data.elevationGainM.present
          ? data.elevationGainM.value
          : this.elevationGainM,
      avgHumanPowerW: data.avgHumanPowerW.present
          ? data.avgHumanPowerW.value
          : this.avgHumanPowerW,
      maxHumanPowerW: data.maxHumanPowerW.present
          ? data.maxHumanPowerW.value
          : this.maxHumanPowerW,
      avgMotorPowerW: data.avgMotorPowerW.present
          ? data.avgMotorPowerW.value
          : this.avgMotorPowerW,
      avgCadenceRpm: data.avgCadenceRpm.present
          ? data.avgCadenceRpm.value
          : this.avgCadenceRpm,
      avgHrBpm: data.avgHrBpm.present ? data.avgHrBpm.value : this.avgHrBpm,
      assistRatio: data.assistRatio.present
          ? data.assistRatio.value
          : this.assistRatio,
      notes: data.notes.present ? data.notes.value : this.notes,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ride(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('timeInMotion: $timeInMotion, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('avgHumanPowerW: $avgHumanPowerW, ')
          ..write('maxHumanPowerW: $maxHumanPowerW, ')
          ..write('avgMotorPowerW: $avgMotorPowerW, ')
          ..write('avgCadenceRpm: $avgCadenceRpm, ')
          ..write('avgHrBpm: $avgHrBpm, ')
          ..write('assistRatio: $assistRatio, ')
          ..write('notes: $notes, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startTime,
    endTime,
    timeInMotion,
    distanceKm,
    elevationGainM,
    avgHumanPowerW,
    maxHumanPowerW,
    avgMotorPowerW,
    avgCadenceRpm,
    avgHrBpm,
    assistRatio,
    notes,
    title,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ride &&
          other.id == this.id &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.timeInMotion == this.timeInMotion &&
          other.distanceKm == this.distanceKm &&
          other.elevationGainM == this.elevationGainM &&
          other.avgHumanPowerW == this.avgHumanPowerW &&
          other.maxHumanPowerW == this.maxHumanPowerW &&
          other.avgMotorPowerW == this.avgMotorPowerW &&
          other.avgCadenceRpm == this.avgCadenceRpm &&
          other.avgHrBpm == this.avgHrBpm &&
          other.assistRatio == this.assistRatio &&
          other.notes == this.notes &&
          other.title == this.title);
}

class RidesCompanion extends UpdateCompanion<Ride> {
  final Value<int> id;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<double> timeInMotion;
  final Value<double> distanceKm;
  final Value<double> elevationGainM;
  final Value<double?> avgHumanPowerW;
  final Value<double?> maxHumanPowerW;
  final Value<double?> avgMotorPowerW;
  final Value<double?> avgCadenceRpm;
  final Value<double?> avgHrBpm;
  final Value<double?> assistRatio;
  final Value<String?> notes;
  final Value<String?> title;
  const RidesCompanion({
    this.id = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.timeInMotion = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.avgHumanPowerW = const Value.absent(),
    this.maxHumanPowerW = const Value.absent(),
    this.avgMotorPowerW = const Value.absent(),
    this.avgCadenceRpm = const Value.absent(),
    this.avgHrBpm = const Value.absent(),
    this.assistRatio = const Value.absent(),
    this.notes = const Value.absent(),
    this.title = const Value.absent(),
  });
  RidesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startTime,
    this.endTime = const Value.absent(),
    this.timeInMotion = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.avgHumanPowerW = const Value.absent(),
    this.maxHumanPowerW = const Value.absent(),
    this.avgMotorPowerW = const Value.absent(),
    this.avgCadenceRpm = const Value.absent(),
    this.avgHrBpm = const Value.absent(),
    this.assistRatio = const Value.absent(),
    this.notes = const Value.absent(),
    this.title = const Value.absent(),
  }) : startTime = Value(startTime);
  static Insertable<Ride> custom({
    Expression<int>? id,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<double>? timeInMotion,
    Expression<double>? distanceKm,
    Expression<double>? elevationGainM,
    Expression<double>? avgHumanPowerW,
    Expression<double>? maxHumanPowerW,
    Expression<double>? avgMotorPowerW,
    Expression<double>? avgCadenceRpm,
    Expression<double>? avgHrBpm,
    Expression<double>? assistRatio,
    Expression<String>? notes,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (timeInMotion != null) 'time_in_motion': timeInMotion,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (avgHumanPowerW != null) 'avg_human_power_w': avgHumanPowerW,
      if (maxHumanPowerW != null) 'max_human_power_w': maxHumanPowerW,
      if (avgMotorPowerW != null) 'avg_motor_power_w': avgMotorPowerW,
      if (avgCadenceRpm != null) 'avg_cadence_rpm': avgCadenceRpm,
      if (avgHrBpm != null) 'avg_hr_bpm': avgHrBpm,
      if (assistRatio != null) 'assist_ratio': assistRatio,
      if (notes != null) 'notes': notes,
      if (title != null) 'title': title,
    });
  }

  RidesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<double>? timeInMotion,
    Value<double>? distanceKm,
    Value<double>? elevationGainM,
    Value<double?>? avgHumanPowerW,
    Value<double?>? maxHumanPowerW,
    Value<double?>? avgMotorPowerW,
    Value<double?>? avgCadenceRpm,
    Value<double?>? avgHrBpm,
    Value<double?>? assistRatio,
    Value<String?>? notes,
    Value<String?>? title,
  }) {
    return RidesCompanion(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timeInMotion: timeInMotion ?? this.timeInMotion,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgHumanPowerW: avgHumanPowerW ?? this.avgHumanPowerW,
      maxHumanPowerW: maxHumanPowerW ?? this.maxHumanPowerW,
      avgMotorPowerW: avgMotorPowerW ?? this.avgMotorPowerW,
      avgCadenceRpm: avgCadenceRpm ?? this.avgCadenceRpm,
      avgHrBpm: avgHrBpm ?? this.avgHrBpm,
      assistRatio: assistRatio ?? this.assistRatio,
      notes: notes ?? this.notes,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (timeInMotion.present) {
      map['time_in_motion'] = Variable<double>(timeInMotion.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (elevationGainM.present) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM.value);
    }
    if (avgHumanPowerW.present) {
      map['avg_human_power_w'] = Variable<double>(avgHumanPowerW.value);
    }
    if (maxHumanPowerW.present) {
      map['max_human_power_w'] = Variable<double>(maxHumanPowerW.value);
    }
    if (avgMotorPowerW.present) {
      map['avg_motor_power_w'] = Variable<double>(avgMotorPowerW.value);
    }
    if (avgCadenceRpm.present) {
      map['avg_cadence_rpm'] = Variable<double>(avgCadenceRpm.value);
    }
    if (avgHrBpm.present) {
      map['avg_hr_bpm'] = Variable<double>(avgHrBpm.value);
    }
    if (assistRatio.present) {
      map['assist_ratio'] = Variable<double>(assistRatio.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RidesCompanion(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('timeInMotion: $timeInMotion, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('avgHumanPowerW: $avgHumanPowerW, ')
          ..write('maxHumanPowerW: $maxHumanPowerW, ')
          ..write('avgMotorPowerW: $avgMotorPowerW, ')
          ..write('avgCadenceRpm: $avgCadenceRpm, ')
          ..write('avgHrBpm: $avgHrBpm, ')
          ..write('assistRatio: $assistRatio, ')
          ..write('notes: $notes, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $SamplesTable extends Samples with TableInfo<$SamplesTable, Sample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SamplesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<int> rideId = GeneratedColumn<int>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rides (id)',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<DateTime> ts = GeneratedColumn<DateTime>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationMeta = const VerificationMeta(
    'elevation',
  );
  @override
  late final GeneratedColumn<double> elevation = GeneratedColumn<double>(
    'elevation',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedKmhMeta = const VerificationMeta(
    'speedKmh',
  );
  @override
  late final GeneratedColumn<double> speedKmh = GeneratedColumn<double>(
    'speed_kmh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _humanPowerWMeta = const VerificationMeta(
    'humanPowerW',
  );
  @override
  late final GeneratedColumn<double> humanPowerW = GeneratedColumn<double>(
    'human_power_w',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _motorPowerWMeta = const VerificationMeta(
    'motorPowerW',
  );
  @override
  late final GeneratedColumn<double> motorPowerW = GeneratedColumn<double>(
    'motor_power_w',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cadenceRpmMeta = const VerificationMeta(
    'cadenceRpm',
  );
  @override
  late final GeneratedColumn<int> cadenceRpm = GeneratedColumn<int>(
    'cadence_rpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pasLevelMeta = const VerificationMeta(
    'pasLevel',
  );
  @override
  late final GeneratedColumn<int> pasLevel = GeneratedColumn<int>(
    'pas_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hrBpmMeta = const VerificationMeta('hrBpm');
  @override
  late final GeneratedColumn<int> hrBpm = GeneratedColumn<int>(
    'hr_bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batteryVMeta = const VerificationMeta(
    'batteryV',
  );
  @override
  late final GeneratedColumn<double> batteryV = GeneratedColumn<double>(
    'battery_v',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batteryAMeta = const VerificationMeta(
    'batteryA',
  );
  @override
  late final GeneratedColumn<double> batteryA = GeneratedColumn<double>(
    'battery_a',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _socMeta = const VerificationMeta('soc');
  @override
  late final GeneratedColumn<int> soc = GeneratedColumn<int>(
    'soc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rangeKmMeta = const VerificationMeta(
    'rangeKm',
  );
  @override
  late final GeneratedColumn<double> rangeKm = GeneratedColumn<double>(
    'range_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rideId,
    ts,
    lat,
    lon,
    elevation,
    speedKmh,
    humanPowerW,
    motorPowerW,
    cadenceRpm,
    pasLevel,
    hrBpm,
    batteryV,
    batteryA,
    soc,
    rangeKm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('elevation')) {
      context.handle(
        _elevationMeta,
        elevation.isAcceptableOrUnknown(data['elevation']!, _elevationMeta),
      );
    }
    if (data.containsKey('speed_kmh')) {
      context.handle(
        _speedKmhMeta,
        speedKmh.isAcceptableOrUnknown(data['speed_kmh']!, _speedKmhMeta),
      );
    } else if (isInserting) {
      context.missing(_speedKmhMeta);
    }
    if (data.containsKey('human_power_w')) {
      context.handle(
        _humanPowerWMeta,
        humanPowerW.isAcceptableOrUnknown(
          data['human_power_w']!,
          _humanPowerWMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_humanPowerWMeta);
    }
    if (data.containsKey('motor_power_w')) {
      context.handle(
        _motorPowerWMeta,
        motorPowerW.isAcceptableOrUnknown(
          data['motor_power_w']!,
          _motorPowerWMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_motorPowerWMeta);
    }
    if (data.containsKey('cadence_rpm')) {
      context.handle(
        _cadenceRpmMeta,
        cadenceRpm.isAcceptableOrUnknown(data['cadence_rpm']!, _cadenceRpmMeta),
      );
    } else if (isInserting) {
      context.missing(_cadenceRpmMeta);
    }
    if (data.containsKey('pas_level')) {
      context.handle(
        _pasLevelMeta,
        pasLevel.isAcceptableOrUnknown(data['pas_level']!, _pasLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_pasLevelMeta);
    }
    if (data.containsKey('hr_bpm')) {
      context.handle(
        _hrBpmMeta,
        hrBpm.isAcceptableOrUnknown(data['hr_bpm']!, _hrBpmMeta),
      );
    } else if (isInserting) {
      context.missing(_hrBpmMeta);
    }
    if (data.containsKey('battery_v')) {
      context.handle(
        _batteryVMeta,
        batteryV.isAcceptableOrUnknown(data['battery_v']!, _batteryVMeta),
      );
    } else if (isInserting) {
      context.missing(_batteryVMeta);
    }
    if (data.containsKey('battery_a')) {
      context.handle(
        _batteryAMeta,
        batteryA.isAcceptableOrUnknown(data['battery_a']!, _batteryAMeta),
      );
    } else if (isInserting) {
      context.missing(_batteryAMeta);
    }
    if (data.containsKey('soc')) {
      context.handle(
        _socMeta,
        soc.isAcceptableOrUnknown(data['soc']!, _socMeta),
      );
    } else if (isInserting) {
      context.missing(_socMeta);
    }
    if (data.containsKey('range_km')) {
      context.handle(
        _rangeKmMeta,
        rangeKm.isAcceptableOrUnknown(data['range_km']!, _rangeKmMeta),
      );
    } else if (isInserting) {
      context.missing(_rangeKmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ride_id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ts'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      elevation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation'],
      ),
      speedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_kmh'],
      )!,
      humanPowerW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}human_power_w'],
      )!,
      motorPowerW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}motor_power_w'],
      )!,
      cadenceRpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadence_rpm'],
      )!,
      pasLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pas_level'],
      )!,
      hrBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hr_bpm'],
      )!,
      batteryV: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}battery_v'],
      )!,
      batteryA: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}battery_a'],
      )!,
      soc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}soc'],
      )!,
      rangeKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}range_km'],
      )!,
    );
  }

  @override
  $SamplesTable createAlias(String alias) {
    return $SamplesTable(attachedDatabase, alias);
  }
}

class Sample extends DataClass implements Insertable<Sample> {
  final int id;
  final int rideId;
  final DateTime ts;
  final double? lat;
  final double? lon;
  final double? elevation;
  final double speedKmh;
  final double humanPowerW;
  final double motorPowerW;
  final int cadenceRpm;
  final int pasLevel;
  final int hrBpm;
  final double batteryV;
  final double batteryA;
  final int soc;
  final double rangeKm;
  const Sample({
    required this.id,
    required this.rideId,
    required this.ts,
    this.lat,
    this.lon,
    this.elevation,
    required this.speedKmh,
    required this.humanPowerW,
    required this.motorPowerW,
    required this.cadenceRpm,
    required this.pasLevel,
    required this.hrBpm,
    required this.batteryV,
    required this.batteryA,
    required this.soc,
    required this.rangeKm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ride_id'] = Variable<int>(rideId);
    map['ts'] = Variable<DateTime>(ts);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || elevation != null) {
      map['elevation'] = Variable<double>(elevation);
    }
    map['speed_kmh'] = Variable<double>(speedKmh);
    map['human_power_w'] = Variable<double>(humanPowerW);
    map['motor_power_w'] = Variable<double>(motorPowerW);
    map['cadence_rpm'] = Variable<int>(cadenceRpm);
    map['pas_level'] = Variable<int>(pasLevel);
    map['hr_bpm'] = Variable<int>(hrBpm);
    map['battery_v'] = Variable<double>(batteryV);
    map['battery_a'] = Variable<double>(batteryA);
    map['soc'] = Variable<int>(soc);
    map['range_km'] = Variable<double>(rangeKm);
    return map;
  }

  SamplesCompanion toCompanion(bool nullToAbsent) {
    return SamplesCompanion(
      id: Value(id),
      rideId: Value(rideId),
      ts: Value(ts),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      elevation: elevation == null && nullToAbsent
          ? const Value.absent()
          : Value(elevation),
      speedKmh: Value(speedKmh),
      humanPowerW: Value(humanPowerW),
      motorPowerW: Value(motorPowerW),
      cadenceRpm: Value(cadenceRpm),
      pasLevel: Value(pasLevel),
      hrBpm: Value(hrBpm),
      batteryV: Value(batteryV),
      batteryA: Value(batteryA),
      soc: Value(soc),
      rangeKm: Value(rangeKm),
    );
  }

  factory Sample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sample(
      id: serializer.fromJson<int>(json['id']),
      rideId: serializer.fromJson<int>(json['rideId']),
      ts: serializer.fromJson<DateTime>(json['ts']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      elevation: serializer.fromJson<double?>(json['elevation']),
      speedKmh: serializer.fromJson<double>(json['speedKmh']),
      humanPowerW: serializer.fromJson<double>(json['humanPowerW']),
      motorPowerW: serializer.fromJson<double>(json['motorPowerW']),
      cadenceRpm: serializer.fromJson<int>(json['cadenceRpm']),
      pasLevel: serializer.fromJson<int>(json['pasLevel']),
      hrBpm: serializer.fromJson<int>(json['hrBpm']),
      batteryV: serializer.fromJson<double>(json['batteryV']),
      batteryA: serializer.fromJson<double>(json['batteryA']),
      soc: serializer.fromJson<int>(json['soc']),
      rangeKm: serializer.fromJson<double>(json['rangeKm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rideId': serializer.toJson<int>(rideId),
      'ts': serializer.toJson<DateTime>(ts),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'elevation': serializer.toJson<double?>(elevation),
      'speedKmh': serializer.toJson<double>(speedKmh),
      'humanPowerW': serializer.toJson<double>(humanPowerW),
      'motorPowerW': serializer.toJson<double>(motorPowerW),
      'cadenceRpm': serializer.toJson<int>(cadenceRpm),
      'pasLevel': serializer.toJson<int>(pasLevel),
      'hrBpm': serializer.toJson<int>(hrBpm),
      'batteryV': serializer.toJson<double>(batteryV),
      'batteryA': serializer.toJson<double>(batteryA),
      'soc': serializer.toJson<int>(soc),
      'rangeKm': serializer.toJson<double>(rangeKm),
    };
  }

  Sample copyWith({
    int? id,
    int? rideId,
    DateTime? ts,
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<double?> elevation = const Value.absent(),
    double? speedKmh,
    double? humanPowerW,
    double? motorPowerW,
    int? cadenceRpm,
    int? pasLevel,
    int? hrBpm,
    double? batteryV,
    double? batteryA,
    int? soc,
    double? rangeKm,
  }) => Sample(
    id: id ?? this.id,
    rideId: rideId ?? this.rideId,
    ts: ts ?? this.ts,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    elevation: elevation.present ? elevation.value : this.elevation,
    speedKmh: speedKmh ?? this.speedKmh,
    humanPowerW: humanPowerW ?? this.humanPowerW,
    motorPowerW: motorPowerW ?? this.motorPowerW,
    cadenceRpm: cadenceRpm ?? this.cadenceRpm,
    pasLevel: pasLevel ?? this.pasLevel,
    hrBpm: hrBpm ?? this.hrBpm,
    batteryV: batteryV ?? this.batteryV,
    batteryA: batteryA ?? this.batteryA,
    soc: soc ?? this.soc,
    rangeKm: rangeKm ?? this.rangeKm,
  );
  Sample copyWithCompanion(SamplesCompanion data) {
    return Sample(
      id: data.id.present ? data.id.value : this.id,
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      ts: data.ts.present ? data.ts.value : this.ts,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      elevation: data.elevation.present ? data.elevation.value : this.elevation,
      speedKmh: data.speedKmh.present ? data.speedKmh.value : this.speedKmh,
      humanPowerW: data.humanPowerW.present
          ? data.humanPowerW.value
          : this.humanPowerW,
      motorPowerW: data.motorPowerW.present
          ? data.motorPowerW.value
          : this.motorPowerW,
      cadenceRpm: data.cadenceRpm.present
          ? data.cadenceRpm.value
          : this.cadenceRpm,
      pasLevel: data.pasLevel.present ? data.pasLevel.value : this.pasLevel,
      hrBpm: data.hrBpm.present ? data.hrBpm.value : this.hrBpm,
      batteryV: data.batteryV.present ? data.batteryV.value : this.batteryV,
      batteryA: data.batteryA.present ? data.batteryA.value : this.batteryA,
      soc: data.soc.present ? data.soc.value : this.soc,
      rangeKm: data.rangeKm.present ? data.rangeKm.value : this.rangeKm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sample(')
          ..write('id: $id, ')
          ..write('rideId: $rideId, ')
          ..write('ts: $ts, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('elevation: $elevation, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('humanPowerW: $humanPowerW, ')
          ..write('motorPowerW: $motorPowerW, ')
          ..write('cadenceRpm: $cadenceRpm, ')
          ..write('pasLevel: $pasLevel, ')
          ..write('hrBpm: $hrBpm, ')
          ..write('batteryV: $batteryV, ')
          ..write('batteryA: $batteryA, ')
          ..write('soc: $soc, ')
          ..write('rangeKm: $rangeKm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rideId,
    ts,
    lat,
    lon,
    elevation,
    speedKmh,
    humanPowerW,
    motorPowerW,
    cadenceRpm,
    pasLevel,
    hrBpm,
    batteryV,
    batteryA,
    soc,
    rangeKm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sample &&
          other.id == this.id &&
          other.rideId == this.rideId &&
          other.ts == this.ts &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.elevation == this.elevation &&
          other.speedKmh == this.speedKmh &&
          other.humanPowerW == this.humanPowerW &&
          other.motorPowerW == this.motorPowerW &&
          other.cadenceRpm == this.cadenceRpm &&
          other.pasLevel == this.pasLevel &&
          other.hrBpm == this.hrBpm &&
          other.batteryV == this.batteryV &&
          other.batteryA == this.batteryA &&
          other.soc == this.soc &&
          other.rangeKm == this.rangeKm);
}

class SamplesCompanion extends UpdateCompanion<Sample> {
  final Value<int> id;
  final Value<int> rideId;
  final Value<DateTime> ts;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<double?> elevation;
  final Value<double> speedKmh;
  final Value<double> humanPowerW;
  final Value<double> motorPowerW;
  final Value<int> cadenceRpm;
  final Value<int> pasLevel;
  final Value<int> hrBpm;
  final Value<double> batteryV;
  final Value<double> batteryA;
  final Value<int> soc;
  final Value<double> rangeKm;
  const SamplesCompanion({
    this.id = const Value.absent(),
    this.rideId = const Value.absent(),
    this.ts = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.elevation = const Value.absent(),
    this.speedKmh = const Value.absent(),
    this.humanPowerW = const Value.absent(),
    this.motorPowerW = const Value.absent(),
    this.cadenceRpm = const Value.absent(),
    this.pasLevel = const Value.absent(),
    this.hrBpm = const Value.absent(),
    this.batteryV = const Value.absent(),
    this.batteryA = const Value.absent(),
    this.soc = const Value.absent(),
    this.rangeKm = const Value.absent(),
  });
  SamplesCompanion.insert({
    this.id = const Value.absent(),
    required int rideId,
    required DateTime ts,
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.elevation = const Value.absent(),
    required double speedKmh,
    required double humanPowerW,
    required double motorPowerW,
    required int cadenceRpm,
    required int pasLevel,
    required int hrBpm,
    required double batteryV,
    required double batteryA,
    required int soc,
    required double rangeKm,
  }) : rideId = Value(rideId),
       ts = Value(ts),
       speedKmh = Value(speedKmh),
       humanPowerW = Value(humanPowerW),
       motorPowerW = Value(motorPowerW),
       cadenceRpm = Value(cadenceRpm),
       pasLevel = Value(pasLevel),
       hrBpm = Value(hrBpm),
       batteryV = Value(batteryV),
       batteryA = Value(batteryA),
       soc = Value(soc),
       rangeKm = Value(rangeKm);
  static Insertable<Sample> custom({
    Expression<int>? id,
    Expression<int>? rideId,
    Expression<DateTime>? ts,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<double>? elevation,
    Expression<double>? speedKmh,
    Expression<double>? humanPowerW,
    Expression<double>? motorPowerW,
    Expression<int>? cadenceRpm,
    Expression<int>? pasLevel,
    Expression<int>? hrBpm,
    Expression<double>? batteryV,
    Expression<double>? batteryA,
    Expression<int>? soc,
    Expression<double>? rangeKm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rideId != null) 'ride_id': rideId,
      if (ts != null) 'ts': ts,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (elevation != null) 'elevation': elevation,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (humanPowerW != null) 'human_power_w': humanPowerW,
      if (motorPowerW != null) 'motor_power_w': motorPowerW,
      if (cadenceRpm != null) 'cadence_rpm': cadenceRpm,
      if (pasLevel != null) 'pas_level': pasLevel,
      if (hrBpm != null) 'hr_bpm': hrBpm,
      if (batteryV != null) 'battery_v': batteryV,
      if (batteryA != null) 'battery_a': batteryA,
      if (soc != null) 'soc': soc,
      if (rangeKm != null) 'range_km': rangeKm,
    });
  }

  SamplesCompanion copyWith({
    Value<int>? id,
    Value<int>? rideId,
    Value<DateTime>? ts,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<double?>? elevation,
    Value<double>? speedKmh,
    Value<double>? humanPowerW,
    Value<double>? motorPowerW,
    Value<int>? cadenceRpm,
    Value<int>? pasLevel,
    Value<int>? hrBpm,
    Value<double>? batteryV,
    Value<double>? batteryA,
    Value<int>? soc,
    Value<double>? rangeKm,
  }) {
    return SamplesCompanion(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      ts: ts ?? this.ts,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      elevation: elevation ?? this.elevation,
      speedKmh: speedKmh ?? this.speedKmh,
      humanPowerW: humanPowerW ?? this.humanPowerW,
      motorPowerW: motorPowerW ?? this.motorPowerW,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      pasLevel: pasLevel ?? this.pasLevel,
      hrBpm: hrBpm ?? this.hrBpm,
      batteryV: batteryV ?? this.batteryV,
      batteryA: batteryA ?? this.batteryA,
      soc: soc ?? this.soc,
      rangeKm: rangeKm ?? this.rangeKm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rideId.present) {
      map['ride_id'] = Variable<int>(rideId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<DateTime>(ts.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (elevation.present) {
      map['elevation'] = Variable<double>(elevation.value);
    }
    if (speedKmh.present) {
      map['speed_kmh'] = Variable<double>(speedKmh.value);
    }
    if (humanPowerW.present) {
      map['human_power_w'] = Variable<double>(humanPowerW.value);
    }
    if (motorPowerW.present) {
      map['motor_power_w'] = Variable<double>(motorPowerW.value);
    }
    if (cadenceRpm.present) {
      map['cadence_rpm'] = Variable<int>(cadenceRpm.value);
    }
    if (pasLevel.present) {
      map['pas_level'] = Variable<int>(pasLevel.value);
    }
    if (hrBpm.present) {
      map['hr_bpm'] = Variable<int>(hrBpm.value);
    }
    if (batteryV.present) {
      map['battery_v'] = Variable<double>(batteryV.value);
    }
    if (batteryA.present) {
      map['battery_a'] = Variable<double>(batteryA.value);
    }
    if (soc.present) {
      map['soc'] = Variable<int>(soc.value);
    }
    if (rangeKm.present) {
      map['range_km'] = Variable<double>(rangeKm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SamplesCompanion(')
          ..write('id: $id, ')
          ..write('rideId: $rideId, ')
          ..write('ts: $ts, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('elevation: $elevation, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('humanPowerW: $humanPowerW, ')
          ..write('motorPowerW: $motorPowerW, ')
          ..write('cadenceRpm: $cadenceRpm, ')
          ..write('pasLevel: $pasLevel, ')
          ..write('hrBpm: $hrBpm, ')
          ..write('batteryV: $batteryV, ')
          ..write('batteryA: $batteryA, ')
          ..write('soc: $soc, ')
          ..write('rangeKm: $rangeKm')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RidesTable rides = $RidesTable(this);
  late final $SamplesTable samples = $SamplesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [rides, samples];
}

typedef $$RidesTableCreateCompanionBuilder =
    RidesCompanion Function({
      Value<int> id,
      required DateTime startTime,
      Value<DateTime?> endTime,
      Value<double> timeInMotion,
      Value<double> distanceKm,
      Value<double> elevationGainM,
      Value<double?> avgHumanPowerW,
      Value<double?> maxHumanPowerW,
      Value<double?> avgMotorPowerW,
      Value<double?> avgCadenceRpm,
      Value<double?> avgHrBpm,
      Value<double?> assistRatio,
      Value<String?> notes,
      Value<String?> title,
    });
typedef $$RidesTableUpdateCompanionBuilder =
    RidesCompanion Function({
      Value<int> id,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<double> timeInMotion,
      Value<double> distanceKm,
      Value<double> elevationGainM,
      Value<double?> avgHumanPowerW,
      Value<double?> maxHumanPowerW,
      Value<double?> avgMotorPowerW,
      Value<double?> avgCadenceRpm,
      Value<double?> avgHrBpm,
      Value<double?> assistRatio,
      Value<String?> notes,
      Value<String?> title,
    });

final class $$RidesTableReferences
    extends BaseReferences<_$AppDatabase, $RidesTable, Ride> {
  $$RidesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SamplesTable, List<Sample>> _samplesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.samples,
    aliasName: 'rides__id__samples__ride_id',
  );

  $$SamplesTableProcessedTableManager get samplesRefs {
    final manager = $$SamplesTableTableManager(
      $_db,
      $_db.samples,
    ).filter((f) => f.rideId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_samplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RidesTableFilterComposer extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableFilterComposer({
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

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get timeInMotion => $composableBuilder(
    column: $table.timeInMotion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgHumanPowerW => $composableBuilder(
    column: $table.avgHumanPowerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxHumanPowerW => $composableBuilder(
    column: $table.maxHumanPowerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgMotorPowerW => $composableBuilder(
    column: $table.avgMotorPowerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgHrBpm => $composableBuilder(
    column: $table.avgHrBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get assistRatio => $composableBuilder(
    column: $table.assistRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> samplesRefs(
    Expression<bool> Function($$SamplesTableFilterComposer f) f,
  ) {
    final $$SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableFilterComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RidesTableOrderingComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get timeInMotion => $composableBuilder(
    column: $table.timeInMotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgHumanPowerW => $composableBuilder(
    column: $table.avgHumanPowerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxHumanPowerW => $composableBuilder(
    column: $table.maxHumanPowerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgMotorPowerW => $composableBuilder(
    column: $table.avgMotorPowerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgHrBpm => $composableBuilder(
    column: $table.avgHrBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get assistRatio => $composableBuilder(
    column: $table.assistRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RidesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get timeInMotion => $composableBuilder(
    column: $table.timeInMotion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgHumanPowerW => $composableBuilder(
    column: $table.avgHumanPowerW,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxHumanPowerW => $composableBuilder(
    column: $table.maxHumanPowerW,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgMotorPowerW => $composableBuilder(
    column: $table.avgMotorPowerW,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgHrBpm =>
      $composableBuilder(column: $table.avgHrBpm, builder: (column) => column);

  GeneratedColumn<double> get assistRatio => $composableBuilder(
    column: $table.assistRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  Expression<T> samplesRefs<T extends Object>(
    Expression<T> Function($$SamplesTableAnnotationComposer a) f,
  ) {
    final $$SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RidesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RidesTable,
          Ride,
          $$RidesTableFilterComposer,
          $$RidesTableOrderingComposer,
          $$RidesTableAnnotationComposer,
          $$RidesTableCreateCompanionBuilder,
          $$RidesTableUpdateCompanionBuilder,
          (Ride, $$RidesTableReferences),
          Ride,
          PrefetchHooks Function({bool samplesRefs})
        > {
  $$RidesTableTableManager(_$AppDatabase db, $RidesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RidesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RidesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RidesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> timeInMotion = const Value.absent(),
                Value<double> distanceKm = const Value.absent(),
                Value<double> elevationGainM = const Value.absent(),
                Value<double?> avgHumanPowerW = const Value.absent(),
                Value<double?> maxHumanPowerW = const Value.absent(),
                Value<double?> avgMotorPowerW = const Value.absent(),
                Value<double?> avgCadenceRpm = const Value.absent(),
                Value<double?> avgHrBpm = const Value.absent(),
                Value<double?> assistRatio = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> title = const Value.absent(),
              }) => RidesCompanion(
                id: id,
                startTime: startTime,
                endTime: endTime,
                timeInMotion: timeInMotion,
                distanceKm: distanceKm,
                elevationGainM: elevationGainM,
                avgHumanPowerW: avgHumanPowerW,
                maxHumanPowerW: maxHumanPowerW,
                avgMotorPowerW: avgMotorPowerW,
                avgCadenceRpm: avgCadenceRpm,
                avgHrBpm: avgHrBpm,
                assistRatio: assistRatio,
                notes: notes,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> timeInMotion = const Value.absent(),
                Value<double> distanceKm = const Value.absent(),
                Value<double> elevationGainM = const Value.absent(),
                Value<double?> avgHumanPowerW = const Value.absent(),
                Value<double?> maxHumanPowerW = const Value.absent(),
                Value<double?> avgMotorPowerW = const Value.absent(),
                Value<double?> avgCadenceRpm = const Value.absent(),
                Value<double?> avgHrBpm = const Value.absent(),
                Value<double?> assistRatio = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> title = const Value.absent(),
              }) => RidesCompanion.insert(
                id: id,
                startTime: startTime,
                endTime: endTime,
                timeInMotion: timeInMotion,
                distanceKm: distanceKm,
                elevationGainM: elevationGainM,
                avgHumanPowerW: avgHumanPowerW,
                maxHumanPowerW: maxHumanPowerW,
                avgMotorPowerW: avgMotorPowerW,
                avgCadenceRpm: avgCadenceRpm,
                avgHrBpm: avgHrBpm,
                assistRatio: assistRatio,
                notes: notes,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RidesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({samplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (samplesRefs) db.samples],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (samplesRefs)
                    await $_getPrefetchedData<Ride, $RidesTable, Sample>(
                      currentTable: table,
                      referencedTable: $$RidesTableReferences._samplesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RidesTableReferences(db, table, p0).samplesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.rideId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RidesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RidesTable,
      Ride,
      $$RidesTableFilterComposer,
      $$RidesTableOrderingComposer,
      $$RidesTableAnnotationComposer,
      $$RidesTableCreateCompanionBuilder,
      $$RidesTableUpdateCompanionBuilder,
      (Ride, $$RidesTableReferences),
      Ride,
      PrefetchHooks Function({bool samplesRefs})
    >;
typedef $$SamplesTableCreateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      required int rideId,
      required DateTime ts,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> elevation,
      required double speedKmh,
      required double humanPowerW,
      required double motorPowerW,
      required int cadenceRpm,
      required int pasLevel,
      required int hrBpm,
      required double batteryV,
      required double batteryA,
      required int soc,
      required double rangeKm,
    });
typedef $$SamplesTableUpdateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      Value<int> rideId,
      Value<DateTime> ts,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> elevation,
      Value<double> speedKmh,
      Value<double> humanPowerW,
      Value<double> motorPowerW,
      Value<int> cadenceRpm,
      Value<int> pasLevel,
      Value<int> hrBpm,
      Value<double> batteryV,
      Value<double> batteryA,
      Value<int> soc,
      Value<double> rangeKm,
    });

final class $$SamplesTableReferences
    extends BaseReferences<_$AppDatabase, $SamplesTable, Sample> {
  $$SamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RidesTable _rideIdTable(_$AppDatabase db) =>
      db.rides.createAlias('samples__ride_id__rides__id');

  $$RidesTableProcessedTableManager get rideId {
    final $_column = $_itemColumn<int>('ride_id')!;

    final manager = $$RidesTableTableManager(
      $_db,
      $_db.rides,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rideIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SamplesTableFilterComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableFilterComposer({
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

  ColumnFilters<DateTime> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevation => $composableBuilder(
    column: $table.elevation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get humanPowerW => $composableBuilder(
    column: $table.humanPowerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get motorPowerW => $composableBuilder(
    column: $table.motorPowerW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadenceRpm => $composableBuilder(
    column: $table.cadenceRpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pasLevel => $composableBuilder(
    column: $table.pasLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hrBpm => $composableBuilder(
    column: $table.hrBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get batteryV => $composableBuilder(
    column: $table.batteryV,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get batteryA => $composableBuilder(
    column: $table.batteryA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rangeKm => $composableBuilder(
    column: $table.rangeKm,
    builder: (column) => ColumnFilters(column),
  );

  $$RidesTableFilterComposer get rideId {
    final $$RidesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableFilterComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevation => $composableBuilder(
    column: $table.elevation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get humanPowerW => $composableBuilder(
    column: $table.humanPowerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get motorPowerW => $composableBuilder(
    column: $table.motorPowerW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadenceRpm => $composableBuilder(
    column: $table.cadenceRpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pasLevel => $composableBuilder(
    column: $table.pasLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hrBpm => $composableBuilder(
    column: $table.hrBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get batteryV => $composableBuilder(
    column: $table.batteryV,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get batteryA => $composableBuilder(
    column: $table.batteryA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rangeKm => $composableBuilder(
    column: $table.rangeKm,
    builder: (column) => ColumnOrderings(column),
  );

  $$RidesTableOrderingComposer get rideId {
    final $$RidesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableOrderingComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<double> get elevation =>
      $composableBuilder(column: $table.elevation, builder: (column) => column);

  GeneratedColumn<double> get speedKmh =>
      $composableBuilder(column: $table.speedKmh, builder: (column) => column);

  GeneratedColumn<double> get humanPowerW => $composableBuilder(
    column: $table.humanPowerW,
    builder: (column) => column,
  );

  GeneratedColumn<double> get motorPowerW => $composableBuilder(
    column: $table.motorPowerW,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cadenceRpm => $composableBuilder(
    column: $table.cadenceRpm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pasLevel =>
      $composableBuilder(column: $table.pasLevel, builder: (column) => column);

  GeneratedColumn<int> get hrBpm =>
      $composableBuilder(column: $table.hrBpm, builder: (column) => column);

  GeneratedColumn<double> get batteryV =>
      $composableBuilder(column: $table.batteryV, builder: (column) => column);

  GeneratedColumn<double> get batteryA =>
      $composableBuilder(column: $table.batteryA, builder: (column) => column);

  GeneratedColumn<int> get soc =>
      $composableBuilder(column: $table.soc, builder: (column) => column);

  GeneratedColumn<double> get rangeKm =>
      $composableBuilder(column: $table.rangeKm, builder: (column) => column);

  $$RidesTableAnnotationComposer get rideId {
    final $$RidesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableAnnotationComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SamplesTable,
          Sample,
          $$SamplesTableFilterComposer,
          $$SamplesTableOrderingComposer,
          $$SamplesTableAnnotationComposer,
          $$SamplesTableCreateCompanionBuilder,
          $$SamplesTableUpdateCompanionBuilder,
          (Sample, $$SamplesTableReferences),
          Sample,
          PrefetchHooks Function({bool rideId})
        > {
  $$SamplesTableTableManager(_$AppDatabase db, $SamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> rideId = const Value.absent(),
                Value<DateTime> ts = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> elevation = const Value.absent(),
                Value<double> speedKmh = const Value.absent(),
                Value<double> humanPowerW = const Value.absent(),
                Value<double> motorPowerW = const Value.absent(),
                Value<int> cadenceRpm = const Value.absent(),
                Value<int> pasLevel = const Value.absent(),
                Value<int> hrBpm = const Value.absent(),
                Value<double> batteryV = const Value.absent(),
                Value<double> batteryA = const Value.absent(),
                Value<int> soc = const Value.absent(),
                Value<double> rangeKm = const Value.absent(),
              }) => SamplesCompanion(
                id: id,
                rideId: rideId,
                ts: ts,
                lat: lat,
                lon: lon,
                elevation: elevation,
                speedKmh: speedKmh,
                humanPowerW: humanPowerW,
                motorPowerW: motorPowerW,
                cadenceRpm: cadenceRpm,
                pasLevel: pasLevel,
                hrBpm: hrBpm,
                batteryV: batteryV,
                batteryA: batteryA,
                soc: soc,
                rangeKm: rangeKm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int rideId,
                required DateTime ts,
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> elevation = const Value.absent(),
                required double speedKmh,
                required double humanPowerW,
                required double motorPowerW,
                required int cadenceRpm,
                required int pasLevel,
                required int hrBpm,
                required double batteryV,
                required double batteryA,
                required int soc,
                required double rangeKm,
              }) => SamplesCompanion.insert(
                id: id,
                rideId: rideId,
                ts: ts,
                lat: lat,
                lon: lon,
                elevation: elevation,
                speedKmh: speedKmh,
                humanPowerW: humanPowerW,
                motorPowerW: motorPowerW,
                cadenceRpm: cadenceRpm,
                pasLevel: pasLevel,
                hrBpm: hrBpm,
                batteryV: batteryV,
                batteryA: batteryA,
                soc: soc,
                rangeKm: rangeKm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rideId = false}) {
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
                    if (rideId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.rideId,
                                referencedTable: $$SamplesTableReferences
                                    ._rideIdTable(db),
                                referencedColumn: $$SamplesTableReferences
                                    ._rideIdTable(db)
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

typedef $$SamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SamplesTable,
      Sample,
      $$SamplesTableFilterComposer,
      $$SamplesTableOrderingComposer,
      $$SamplesTableAnnotationComposer,
      $$SamplesTableCreateCompanionBuilder,
      $$SamplesTableUpdateCompanionBuilder,
      (Sample, $$SamplesTableReferences),
      Sample,
      PrefetchHooks Function({bool rideId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db, _db.rides);
  $$SamplesTableTableManager get samples =>
      $$SamplesTableTableManager(_db, _db.samples);
}
