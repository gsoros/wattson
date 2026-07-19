import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:drift/drift.dart' show Value, OrderingTerm, OrderingMode;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../data/database.dart';
import '../models/recording_state.dart';
import '../models/telemetry.dart';
import '../service/recording_task_handler.dart';

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
  RecordingService({required AppDatabase database, required this._telemetryStream}) : _db = database;

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

  /// Called after every ride start or stop so the UI can refresh.
  VoidCallback? onRideMutation;

  /// Exposes the current recording state for the UI.
  Stream<RecordingState> get stateStream => _stateController.stream;

  /// Current snapshot (synchronous read).
  RecordingState get currentState => _state;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start a new recording session.
  ///
  /// If [rideId] is provided (orphan resume), the existing ride row is reused
  /// and no new row is inserted. Otherwise a fresh ride row is created.
  Future<void> start({int? rideId}) async {
    if (_state.isActive) return;

    debugPrint('[RecordingService] starting ride #${rideId ?? 'new'}');

    // Emit recording state immediately so the UI swaps to pause/stop buttons
    // without waiting for the async setup below.
    _tickStart = DateTime.now();
    _state = _state.copyWith(status: RecordingStatus.recording, rideId: rideId);
    _stateController.add(_state);

    _telemetrySub?.cancel();
    _telemetrySub = _telemetryStream.listen(_onTelemetry);

    // Start foreground service (wake-lock + notification).
    await FlutterForegroundTask.startService(
      serviceId: 501,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Wattson',
      notificationText: 'Recording ride…',
      callback: startForegroundCallback,
    );

    // Insert a new ride row unless resuming an orphan.
    if (rideId == null) {
      final newId = await _db.into(_db.rides).insert(RidesCompanion.insert(startTime: DateTime.now()));
      _state = _state.copyWith(rideId: newId);
      _stateController.add(_state);
      debugPrint('[RecordingService] inserted new ride #$newId');
    }

    onRideMutation?.call();

    // Defer GPS to the next microtask so the UI can render the recording state
    // before the potentially-blocking platform channel call.
    Future.microtask(() {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0, timeLimit: null),
      ).listen(_onGpsPosition);
    });
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

    final rideId = _state.rideId;
    debugPrint('[RecordingService] stopping ride #$rideId');

    _telemetrySub?.cancel();
    _telemetrySub = null;

    // Finalize the ride row.
    await (_db.update(_db.rides)..where((r) => r.id.equals(rideId!))).write(
      RidesCompanion(
        endTime: Value(DateTime.now()),
        timeInMotion: Value(_state.timeInMotion.inSeconds.toDouble()),
        distanceKm: Value(_state.distanceKm),
        elevationGainM: Value(_state.elevationGainM),
      ),
    );
    debugPrint('[RecordingService] ride #$rideId finalized in DB');

    // Reset specific state fields only
    // _state = _state.copyWith(status: RecordingStatus.idle, rideId: null, timeInMotion: Duration.zero, distanceKm: 0, elevationGainM: 0);
    // Reset all state fields
    _state = RecordingState();
    _stateController.add(_state);
    debugPrint('[RecordingService] state emitted: idle, rideId=null');

    onRideMutation?.call();

    // Stop foreground service.
    await FlutterForegroundTask.stopService();

    // Stop GPS.
    _gpsSub?.cancel();
    _gpsSub = null;

    debugPrint('[RecordingService] stopped');
  }

  /// Check for an orphan ride (endTime == null) left from a previous session.
  ///
  /// If the most recent sample is ≤ 4 hours old, resume recording that ride.
  /// Otherwise, close it at the time of the last sample (or startTime if no
  /// samples were written).
  Future<void> recoverOrphanRide() async {
    final orphans = await (_db.select(_db.rides)..where((r) => r.endTime.isNull())).get();
    if (orphans.isEmpty) return;

    final ride = orphans.first;
    final samples =
        await (_db.select(_db.samples)
              ..where((s) => s.rideId.equals(ride.id))
              ..orderBy([(s) => OrderingTerm(expression: s.ts, mode: OrderingMode.desc)])
              ..limit(1))
            .get();

    final lastSampleTs = samples.isNotEmpty ? samples.first.ts : ride.startTime;
    final age = DateTime.now().difference(lastSampleTs);

    if (age.inHours <= 4) {
      // Resume recording this ride.
      debugPrint('[RecordingService] Resuming orphan ride #${ride.id} (last sample ${age.inMinutes}m ago)');

      // Compute initial accumulators from existing samples.
      final allSamples = await (_db.select(_db.samples)..where((s) => s.rideId.equals(ride.id))).get();
      Duration elapsed = Duration.zero;
      double distanceKm = 0;
      if (allSamples.length >= 2) {
        elapsed = allSamples.last.ts.difference(allSamples.first.ts);
        for (final s in allSamples) {
          if (s.speedKmh > _motionThreshold) {
            final idx = allSamples.indexOf(s);
            if (idx > 0) {
              final dt = s.ts.difference(allSamples[idx - 1].ts).inMilliseconds / 3600000.0;
              distanceKm += s.speedKmh * dt;
            }
          }
        }
      }

      _state = _state.copyWith(elapsed: elapsed, distanceKm: distanceKm);
      await start(rideId: ride.id);
    } else {
      // Close the orphan ride at the last known data point.
      debugPrint('[RecordingService] Closing stale orphan ride #${ride.id} (last sample ${age.inHours}h ago)');

      // Compute summary stats from samples.
      final allSamples = await (_db.select(_db.samples)..where((s) => s.rideId.equals(ride.id))).get();
      double totalDistance = 0;
      double totalElevation = 0;
      double totalHumanPower = 0;
      double totalMotorPower = 0;
      int totalCadence = 0;
      int sampleCount = allSamples.length;

      for (int i = 0; i < sampleCount; i++) {
        final s = allSamples[i];
        if (s.speedKmh > _motionThreshold && i > 0) {
          final dt = s.ts.difference(allSamples[i - 1].ts).inMilliseconds / 3600000.0;
          totalDistance += s.speedKmh * dt;
        }
        if (s.elevation != null && s.elevation! > 0 && i > 0) {
          final prev = allSamples[i - 1].elevation;
          if (prev != null && prev > 0) {
            totalElevation += (s.elevation! - prev).clamp(0, double.infinity);
          }
        }
        totalHumanPower += s.humanPowerW;
        totalMotorPower += s.motorPowerW;
        totalCadence += s.cadenceRpm;
      }

      final avgHumanPower = sampleCount > 0 ? totalHumanPower / sampleCount : null;
      final avgMotorPower = sampleCount > 0 ? totalMotorPower / sampleCount : null;
      final avgCadence = sampleCount > 0 ? totalCadence / sampleCount : null;

      await (_db.update(_db.rides)..where((r) => r.id.equals(ride.id))).write(
        RidesCompanion(
          endTime: Value(lastSampleTs),
          timeInMotion: Value(lastSampleTs.difference(ride.startTime).inSeconds.toDouble()),
          distanceKm: Value(totalDistance),
          elevationGainM: Value(totalElevation),
          avgHumanPowerW: Value(avgHumanPower),
          avgMotorPowerW: Value(avgMotorPower),
          avgCadenceRpm: Value(avgCadence?.toDouble()),
        ),
      );
    }
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

    if (_state.rideId == null) {
      //debugPrint('[RecordingService] rideId is null, dropping sample');
    } else {
      // Write a sample row.
      _db
          .into(_db.samples)
          .insert(
            SamplesCompanion.insert(
              rideId: _state.rideId!, // Throws: Null check used on a null value
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
    }

    _tickStart = now;
  }
}
