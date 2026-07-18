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
