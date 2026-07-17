import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/real_ble_service.dart';
import '../models/telemetry.dart';

/// Provides the active [BleService].
///
/// M1 uses [RealBleService] for live hardware. Swap for [MockBleService] in
/// tests or development without a Dash unit.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = RealBleService();
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
