/// Recording lifecycle state.
enum RecordingStatus { idle, recording, paused }

/// Snapshot of recording state for the UI.
class RecordingState {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.elapsed = Duration.zero,
    this.timeInMotion = Duration.zero,
    this.distanceKm = 0,
    this.elevationGainM = 0,
    this.rideId,
  });

  final RecordingStatus status;
  final Duration elapsed;
  final Duration timeInMotion;
  final double distanceKm;
  final double elevationGainM;
  final int? rideId;

  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get isActive => status != RecordingStatus.idle;

  RecordingState copyWith({RecordingStatus? status, Duration? elapsed, Duration? timeInMotion, double? distanceKm, double? elevationGainM, int? rideId}) {
    return RecordingState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      timeInMotion: timeInMotion ?? this.timeInMotion,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      rideId: rideId ?? this.rideId,
    );
  }
}
