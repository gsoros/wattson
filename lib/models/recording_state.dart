/// Recording lifecycle state.
enum RecordingStatus { idle, recording, paused }

/// Snapshot of recording state for the UI.
///
/// Includes live accumulators for stats that are computed continuously
/// during recording (power, cadence, PAS distribution) so the UI can
/// display them as optional tiles on the main ride screen.
class RecordingState {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.elapsed = Duration.zero,
    this.timeInMotion = Duration.zero,
    this.distanceKm = 0,
    this.elevationGainM = 0,
    this.rideId,
    this.movingSampleCount = 0,
    this.totalHumanPower = 0,
    this.totalCadence = 0,
    this.cadenceSampleCount = 0,
    this.totalMotorPower = 0,
    this.pasLevelCounts = const <int, int>{},
    this.normalizedPower,
  });

  final RecordingStatus status;
  final Duration elapsed;
  final Duration timeInMotion;
  final double distanceKm;
  final double elevationGainM;
  final int? rideId;

  // -- Live accumulators --

  /// Number of moving samples processed (speed > 2 km/h).
  final int movingSampleCount;

  /// Sum of human power across moving samples.
  final double totalHumanPower;

  /// Sum of cadence across moving samples with non-zero cadence.
  final double totalCadence;

  /// Number of moving samples with non-zero cadence.
  final int cadenceSampleCount;

  /// Sum of motor power across moving samples.
  final double totalMotorPower;

  /// Count of samples per PAS level (all samples, not just moving).
  final Map<int, int> pasLevelCounts;

  // -- Computed live stats --

  /// Live average human power, or null if no moving samples yet.
  double? get avgHumanPowerW => movingSampleCount > 0 ? totalHumanPower / movingSampleCount : null;

  /// Live Normalized Power (30s rolling average algorithm), or null.
  ///
  /// Uses the standard Coggan/TrainingPeaks 30-second rolling average
  /// algorithm. Labeled "WAP" in the UI to avoid trademark issues.
  final double? normalizedPower;

  /// Live average cadence (zero-excluded), or null.
  double? get avgCadenceRpm => cadenceSampleCount > 0 ? totalCadence / cadenceSampleCount : null;

  /// Live average motor power, or null.
  double? get avgMotorPowerW => movingSampleCount > 0 ? totalMotorPower / movingSampleCount : null;

  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get isActive => status != RecordingStatus.idle;

  RecordingState copyWith({
    RecordingStatus? status,
    Duration? elapsed,
    Duration? timeInMotion,
    double? distanceKm,
    double? elevationGainM,
    int? rideId,
    int? movingSampleCount,
    double? totalHumanPower,
    double? totalCadence,
    int? cadenceSampleCount,
    double? totalMotorPower,
    Map<int, int>? pasLevelCounts,
    double? normalizedPower,
  }) {
    return RecordingState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      timeInMotion: timeInMotion ?? this.timeInMotion,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      rideId: rideId ?? this.rideId,
      movingSampleCount: movingSampleCount ?? this.movingSampleCount,
      totalHumanPower: totalHumanPower ?? this.totalHumanPower,
      totalCadence: totalCadence ?? this.totalCadence,
      cadenceSampleCount: cadenceSampleCount ?? this.cadenceSampleCount,
      totalMotorPower: totalMotorPower ?? this.totalMotorPower,
      pasLevelCounts: pasLevelCounts ?? this.pasLevelCounts,
      normalizedPower: normalizedPower ?? this.normalizedPower,
    );
  }
}
