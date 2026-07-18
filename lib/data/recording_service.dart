import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:geolocator/geolocator.dart';

import '../data/database.dart';
import '../models/recording_state.dart';
import '../models/telemetry.dart';

/// Threshold below which the bike is considered stopped (km/h).
const double _motionThreshold = 2.0;

/// Manages ride recording lifecycle.
///
/// Listens to the telemetry stream and GPS position updates. On every CTS tick
/// while recording, writes a [Sample] row to the database and accumulates
/// elapsed time, distance, and elevation gain.
///
/// GPS positions are taken from the most recent fix at the time the sample is
/// written — no interpolation; the nearest fix is good enough for ~1 Hz CTS.
class RecordingService {
  RecordingService({required AppDatabase database, required this._telemetryStream}) : _db = database {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0, timeLimit: null),
    ).listen(_onGpsPosition);
  }

  final AppDatabase _db;
  final Stream<Telemetry> _telemetryStream;

  // -- State --
  final _stateController = StreamController<RecordingState>.broadcast();
  RecordingState _state = const RecordingState();

  // -- Subscriptions --
  StreamSubscription<Telemetry>? _telemetrySub;
  StreamSubscription<Position>? _gpsSub;

  // -- Accumulators --
  double _lastLat = 0;
  double _lastLon = 0;
  double _lastElevation = 0;
  double _prevElevation = 0;
  bool _hasGps = false;
  DateTime? _tickStart;

  /// Exposes the current recording state for the UI.
  Stream<RecordingState> get stateStream => _stateController.stream;

  /// Current snapshot (synchronous read).
  RecordingState get currentState => _state;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start a new recording session.
  Future<void> start() async {
    if (_state.isActive) return;

    // Insert a new ride row.
    final rideId = await _db.into(_db.rides).insert(RidesCompanion.insert(startTime: DateTime.now()));

    _tickStart = DateTime.now();
    _state = _state.copyWith(status: RecordingStatus.recording, rideId: rideId);

    _telemetrySub?.cancel();
    _telemetrySub = _telemetryStream.listen(_onTelemetry);

    _stateController.add(_state);
  }

  /// Pause the current session.
  Future<void> pause() async {
    if (!_state.isRecording) return;
    _state = _state.copyWith(status: RecordingStatus.paused);
    _stateController.add(_state);
  }

  /// Resume a paused session.
  Future<void> resume() async {
    if (!_state.isPaused) return;
    _tickStart = DateTime.now();
    _state = _state.copyWith(status: RecordingStatus.recording);
    _stateController.add(_state);
  }

  /// Stop the current session and finalize the ride summary.
  Future<void> stop() async {
    if (!_state.isActive) return;

    _telemetrySub?.cancel();
    _telemetrySub = null;

    // Finalize the ride row.
    await (_db.update(_db.rides)..where((r) => r.id.equals(_state.rideId!))).write(
      RidesCompanion(
        endTime: Value(DateTime.now()),
        timeInMotion: Value(_state.timeInMotion.inSeconds.toDouble()),
        distanceKm: Value(_state.distanceKm),
        elevationGainM: Value(_state.elevationGainM),
      ),
    );

    _state = _state.copyWith(status: RecordingStatus.idle, rideId: null);
    _stateController.add(_state);
  }

  /// Dispose resources.
  void dispose() {
    _telemetrySub?.cancel();
    _gpsSub?.cancel();
    _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------

  void _onGpsPosition(Position pos) {
    _lastLat = pos.latitude;
    _lastLon = pos.longitude;
    _lastElevation = pos.altitude;
    if (!_hasGps) {
      _prevElevation = pos.altitude;
    }
    _hasGps = true;
  }

  // ---------------------------------------------------------------------------
  // Telemetry handler
  // ---------------------------------------------------------------------------

  void _onTelemetry(Telemetry t) {
    if (!_state.isRecording || !t.ordValid) return;

    final now = DateTime.now();
    final elapsed = now.difference(_tickStart!);
    double distanceDelta = 0;
    double elevationDelta = 0;
    Duration motionDelta = Duration.zero;

    // Distance from speed × elapsed (odometry).
    if (t.speedKmh > _motionThreshold) {
      distanceDelta = t.speedKmh * (elapsed.inMilliseconds / 3600000.0);
      motionDelta = elapsed;
    }

    // Elevation from GPS (positive-only delta).
    if (_hasGps && _lastElevation > 0) {
      elevationDelta = (_lastElevation - _prevElevation).clamp(0, double.infinity);
      _prevElevation = _lastElevation;
    }

    // Update state accumulators.
    _state = _state.copyWith(
      status: RecordingStatus.recording,
      elapsed: _state.elapsed + elapsed,
      timeInMotion: _state.timeInMotion + motionDelta,
      distanceKm: _state.distanceKm + distanceDelta,
      elevationGainM: _state.elevationGainM + elevationDelta,
    );
    _stateController.add(_state);

    // Write a sample row.
    _db
        .into(_db.samples)
        .insert(
          SamplesCompanion.insert(
            rideId: _state.rideId!,
            ts: now,
            lat: Value(_hasGps ? _lastLat : null),
            lon: Value(_hasGps ? _lastLon : null),
            elevation: Value(_hasGps ? _lastElevation : null),
            speedKmh: t.speedKmh,
            humanPowerW: t.humanPowerW,
            motorPowerW: t.motorPowerW,
            cadenceRpm: t.cadenceRpm,
            pasLevel: t.pasLevel,
            hrBpm: t.heartRateBpm,
            batteryV: t.batteryVoltage,
            batteryA: t.batteryCurrent,
            soc: t.soc,
            rangeKm: t.rangeKm,
          ),
        );

    _tickStart = now;
  }
}
