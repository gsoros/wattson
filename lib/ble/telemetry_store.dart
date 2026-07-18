import 'dart:async';

import '../models/telemetry.dart';

/// Mutable telemetry state that emits immutable [Telemetry] snapshots.
///
/// Single source of truth for the combined ORD + HRM data. Consumers subscribe
/// to [stream]; producers call the typed update methods. The store handles
/// cross-source merging internally so callers don't need to worry about
/// clobbering the other source's fields.
///
/// ## Usage
///
/// ```dart
/// final store = TelemetryStore();
/// store.stream.listen((t) => ui.update(t));
///
/// store.updateCts(parsedTelemetry);       // CTS arrives
/// store.updateHeartRate(72);              // HRM arrives
/// store.invalidateOrd();                  // Dash disconnects
/// ```
class TelemetryStore {
  final StreamController<Telemetry> _controller = StreamController<Telemetry>.broadcast();
  Telemetry _current = Telemetry();

  /// Live telemetry stream. Emits a new snapshot on every state change.
  Stream<Telemetry> get stream => _controller.stream;

  /// The latest snapshot. Safe to read synchronously (e.g. for one-shot writes
  /// like forwarding HR to the Dash's CTS HR char).
  Telemetry get current => _current;

  // ---------------------------------------------------------------------------
  // CTS (ORD Dash)
  // ---------------------------------------------------------------------------

  /// Replace CTS-originated fields while preserving HRM state.
  ///
  /// [ctsFields] should be a [Telemetry] returned by [CtsParser.parse] — it
  /// carries `ordValid: true` and all the CTS fields. The store merges in the
  /// last known HRM values so a CTS update never clobbers heart rate data.
  void updateCts(Telemetry ctsFields) {
    _current = ctsFields.copyWith(hrmValid: _current.hrmValid, heartRateBpm: _current.heartRateBpm);
    _controller.add(_current);
  }

  // ---------------------------------------------------------------------------
  // HRM
  // ---------------------------------------------------------------------------

  /// Update heart rate and mark HRM valid.
  ///
  /// Preserves all CTS fields. Sets [Telemetry.timestamp] to now since this is
  /// a fresh data event.
  void updateHeartRate(int bpm) {
    _current = _current.copyWith(hrmValid: true, heartRateBpm: bpm, timestamp: DateTime.now());
    _controller.add(_current);
  }

  // ---------------------------------------------------------------------------
  // Invalidation
  // ---------------------------------------------------------------------------

  /// Mark ORD data as invalid (e.g. on Dash disconnect).
  ///
  /// HRM data is preserved — the ride screen will continue showing heart rate
  /// if the HRM is still connected.
  void invalidateOrd() {
    _current = _current.copyWith(ordValid: false);
    _controller.add(_current);
  }

  /// Mark HRM data as invalid (e.g. on HRM disconnect).
  void invalidateHrm() {
    _current = _current.copyWith(hrmValid: false);
    _controller.add(_current);
  }

  /// Reset everything to defaults (both sources invalid).
  ///
  /// Useful when both devices disconnect or on app shutdown.
  void invalidateAll() {
    _current = Telemetry();
    _controller.add(_current);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Close the stream controller. No further events will be emitted.
  void dispose() => _controller.close();
}
