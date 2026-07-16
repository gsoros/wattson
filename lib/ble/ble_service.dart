import 'dart:async';

import '../models/telemetry.dart';

/// Connection lifecycle states for the ORD Dash.
enum BleConnectionState { disabled, scanning, connecting, connected, disconnected }

/// Abstract BLE boundary for the ORD Dash.
///
/// Implemented by [RealBleService] (flutter_blue_plus) and [MockBleService]
/// (development without hardware). Keeping this abstract lets the entire app
/// (UI, recording, export) run against a simulator.
abstract class BleService {
  /// Stream of connection state changes.
  Stream<BleConnectionState> get connectionState;

  /// Stream of telemetry samples (CTS + CPS + HR merged).
  Stream<Telemetry> get telemetry;

  /// Whether BLE is enabled on the device.
  Future<bool> isEnabled();

  /// Start scanning and connect to a bonded/discovered ORD Dash.
  Future<void> connect();

  /// Disconnect and stop scanning.
  Future<void> disconnect();

  /// Send a command line to the device over NUS (e.g. "hostname", "ble status").
  /// Returns the formatted API reply string, or null if NUS is unavailable.
  Future<String?> sendCommand(String line);

  /// Push heart rate (BPM) to the device's CTS HR write char.
  Future<void> writeHeartRate(int bpm);

  /// Dispose resources.
  Future<void> dispose();
}
