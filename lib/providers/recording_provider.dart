import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/recording_service.dart';
import '../models/recording_state.dart';
import 'ble_provider.dart';

/// Provides the Drift database as a singleton.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the [RecordingService], wired to the live telemetry stream.
final recordingServiceProvider = Provider<RecordingService>((ref) {
  final db = ref.watch(databaseProvider);
  final bleService = ref.watch(bleServiceProvider);
  final service = RecordingService(database: db, telemetryStream: bleService.telemetry);
  ref.onDispose(service.dispose);
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
