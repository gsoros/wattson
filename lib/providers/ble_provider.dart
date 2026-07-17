import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/ble_scan_result.dart';
import '../ble/real_ble_service.dart';
import '../models/telemetry.dart';
import 'auto_connect.dart';

/// Provides the active [BleService].
///
/// M2 uses [RealBleService] for live hardware. Swap for [MockBleService] in
/// tests or development without a Dash unit.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = RealBleService();
  ref.onDispose(service.dispose);
  return service;
});

/// Starts auto-connect logic on first access.
final autoConnectProvider = Provider<AutoConnectManager>((ref) {
  final service = ref.watch(bleServiceProvider);
  final manager = AutoConnectManager(service);
  ref.onDispose(manager.dispose);
  return manager;
});

/// Live scan results (discovered BLE devices).
final scanResultsProvider = StreamProvider<List<BleScanResult>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.scanResults;
});

/// Dash slot connection state.
final dashConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.dashConnectionState;
});

/// HRM slot connection state.
final hrmConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.hrmConnectionState;
});

/// Latest telemetry sample (CTS from Dash + HR from HRM).
final telemetryProvider = StreamProvider<Telemetry>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.telemetry;
});
