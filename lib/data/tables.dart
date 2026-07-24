import 'package:drift/drift.dart';

/// A recorded ride session.
class Rides extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get timeInMotion => real().withDefault(const Constant(0))();
  RealColumn get distanceKm => real().withDefault(const Constant(0))();
  RealColumn get elevationGainM => real().withDefault(const Constant(0))();
  RealColumn get avgHumanPowerW => real().nullable()();
  RealColumn get maxHumanPowerW => real().nullable()();
  RealColumn get avgMotorPowerW => real().nullable()();
  RealColumn get avgCadenceRpm => real().nullable()();
  RealColumn get avgHrBpm => real().nullable()();
  RealColumn get assistRatio => real().nullable()();
  TextColumn get notes => text().nullable()();

  /// User-editable name for the ride. Null/empty falls back to a date label.
  TextColumn get title => text().nullable()();

  // -- v3 columns --

  /// Weighted Average Power (more accurately, Normalized Power).
  RealColumn get weightedAvgPowerW => real().nullable()();

  /// Functional Threshold Power at the time this ride was recorded.
  RealColumn get rideFtpW => real().nullable()();

  /// Total motor energy used, in watt-hours.
  RealColumn get motorEnergyWh => real().nullable()();
}

/// PAS level distribution for a ride.
///
/// One row per distinct PAS level present in the ride's samples.
/// `sampleCount` is the number of telemetry ticks at that level (~1 Hz,
/// so roughly equivalent to seconds).
class PasLevelDistribution extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get rideId => integer().references(Rides, #id)();
  IntColumn get pasLevel => integer()();
  IntColumn get sampleCount => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {rideId, pasLevel},
  ];
}

/// A single telemetry sample within a ride.
///
/// Written at every CTS tick (~1 Hz) while recording. GPS fields are populated
/// from the nearest available position fix.
class Samples extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get rideId => integer().references(Rides, #id)();
  DateTimeColumn get ts => dateTime()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  RealColumn get elevation => real().nullable()();
  RealColumn get speedKmh => real()();
  RealColumn get humanPowerW => real()();
  RealColumn get motorPowerW => real()();
  IntColumn get cadenceRpm => integer()();
  IntColumn get pasLevel => integer()();
  IntColumn get hrBpm => integer()();
  RealColumn get batteryV => real()();
  RealColumn get batteryA => real()();
  IntColumn get soc => integer()();
  RealColumn get rangeKm => real()();
}
