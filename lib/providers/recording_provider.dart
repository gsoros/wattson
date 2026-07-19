import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/recording_service.dart';
import '../models/recording_state.dart';
import 'ble_provider.dart';

/// Bumped on every ride start/stop so [rideHistoryProvider] can re-fetch.
class _RideVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final rideHistoryVersionProvider = NotifierProvider<_RideVersionNotifier, int>(_RideVersionNotifier.new);

/// Provides the Drift database as a singleton.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the [RecordingService], wired to the live telemetry stream.
///
/// On creation, checks for an orphan ride from a previous session and either
/// resumes or closes it. Also wires [rideHistoryVersionProvider] so the ride
/// history page re-fetches on every start/stop.
final recordingServiceProvider = Provider<RecordingService>((ref) {
  final db = ref.watch(databaseProvider);
  final bleService = ref.watch(bleServiceProvider);
  final service = RecordingService(database: db, telemetryStream: bleService.telemetry);
  ref.onDispose(service.dispose);

  // Recover any orphan ride left from a previous session.
  service.recoverOrphanRide();

  // Bump version on every ride start/stop so rideHistoryProvider re-fetches.
  service.onRideMutation = () {
    ref.read(rideHistoryVersionProvider.notifier).bump();
  };

  return service;
});

/// Exposes the recording state for the UI to consume.
///
/// Emits [RecordingService.currentState] immediately, then forwards live
/// updates from the service's state stream. This ensures the provider never
/// starts in `loading` even if the broadcast stream was created before the
/// provider subscribed.
final recordingStateProvider = StreamProvider<RecordingState>((ref) {
  final service = ref.watch(recordingServiceProvider);
  return _withInitialState(service);
});

/// Helper that prepends the current state to the service's live stream.
Stream<RecordingState> _withInitialState(RecordingService service) async* {
  yield service.currentState;
  yield* service.stateStream;
}
