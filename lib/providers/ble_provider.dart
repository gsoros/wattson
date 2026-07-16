import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/mock_ble_service.dart';
import '../models/telemetry.dart';

/// Provides the active [BleService].
///
/// M0 uses [MockBleService] so the app runs without hardware. Swap for
/// [RealBleService] (flutter_blue_plus) in M1.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = MockBleService(heartRateEnabled: true);
  ref.onDispose(service.dispose);
  return service;
});

/// Latest telemetry sample.
final telemetryProvider = StreamProvider<Telemetry>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.telemetry;
});

/// Connection state.
final connectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.connectionState;
});
