/// Unified telemetry snapshot.
///
/// Sourced from two BLE devices:
///  - ORD: CTS char (custom telemetry, notify @ ~1 Hz, change-gated): speed, battery
///    voltage/current, state of charge, range, PAS level, human power, cadence.
///  - HRM: heart rate
class Telemetry {
  const Telemetry({
    this.ordValid = false,
    this.hrmValid = false,
    this.speedKmh = 0,
    this.batteryVoltage = 0,
    this.batteryCurrent = 0,
    this.soc = 0,
    this.rangeKm = 0,
    this.pasLevel = 0,
    this.humanPowerW = 0,
    this.motorPowerW = 0,
    this.cadenceRpm = 0,
    this.heartRateBpm = 0,
    this.timestamp,
  });

  /// Whether ORD values are valid.
  final bool ordValid;

  /// Whether HRM value is valid.
  final bool hrmValid;

  /// Speed in km/h.
  final double speedKmh;

  /// Battery voltage in V.
  final double batteryVoltage;

  /// Battery current in A (unsigned on the device; no regen/charge sign).
  final double batteryCurrent;

  /// State of charge in % (0-100). Authoritative source is CTS SoC.
  final int soc;

  /// Estimated range in km.
  final double rangeKm;

  /// Pedal assist level: -1 walk, 0 off, 1-5.
  final int pasLevel;

  /// Human mechanical power in W.
  final double humanPowerW;

  /// Motor power in W (from CPS).
  final double motorPowerW;

  /// Cadence in RPM.
  final int cadenceRpm;

  /// Heart rate in BPM (0 = none).
  final int heartRateBpm;

  /// Time the sample was produced/received.
  final DateTime? timestamp;

  Telemetry copyWith({
    bool? ordValid,
    bool? hrmValid,
    double? speedKmh,
    double? batteryVoltage,
    double? batteryCurrent,
    int? soc,
    double? rangeKm,
    int? pasLevel,
    double? humanPowerW,
    double? motorPowerW,
    int? cadenceRpm,
    int? heartRateBpm,
    DateTime? timestamp,
  }) {
    return Telemetry(
      ordValid: ordValid ?? this.ordValid,
      hrmValid: hrmValid ?? this.hrmValid,
      speedKmh: speedKmh ?? this.speedKmh,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryCurrent: batteryCurrent ?? this.batteryCurrent,
      soc: soc ?? this.soc,
      rangeKm: rangeKm ?? this.rangeKm,
      pasLevel: pasLevel ?? this.pasLevel,
      humanPowerW: humanPowerW ?? this.humanPowerW,
      motorPowerW: motorPowerW ?? this.motorPowerW,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
