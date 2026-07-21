import 'dart:async';

import '../models/telemetry.dart';
import 'ble_scan_result.dart';
import 'nus_protocol.dart';

/// Connection lifecycle states for a single device slot.
enum BleConnectionState { disabled, scanning, connecting, connected, disconnected }

/// Abstract BLE boundary for the Wattson app.
///
/// Manages **two independent connection slots**:
/// - **Dash** — ORD Dash (CTS telemetry + NUS command/reply).
/// - **HRM** — standard BLE Heart Rate Monitor (HR Service 0x180D).
///
/// Implemented by [RealBleService] (flutter_blue_plus) and [MockBleService]
/// (development without hardware).
abstract class BleService {
  /// Live scan results. Emits the current list of discovered devices whenever
  /// the scan produces new data. The UI consumes this stream directly.
  Stream<List<BleScanResult>> get scanResults;

  /// Connection state for the Dash slot.
  Stream<BleConnectionState> get dashConnectionState;

  /// Connection state for the HRM slot.
  Stream<BleConnectionState> get hrmConnectionState;

  /// Combined telemetry stream (CTS data from Dash + HR from HRM).
  Stream<Telemetry> get telemetry;

  /// Whether BLE is enabled on the device.
  Future<bool> isEnabled();

  // -- Scan control --

  /// Start scanning for devices. While running, [scanResults] emits updates.
  Future<void> startScan();

  /// Stop scanning.
  Future<void> stopScan();

  /// Whether a scan is currently in progress.
  bool get isScanning;

  // -- Connection (Dash slot) --

  /// Connect to the ORD Dash at [deviceId] (MAC address).
  /// Discovers CTS + NUS services and subscribes to notifications.
  Future<void> connectToDash(String deviceId, {String? name});

  /// Disconnect the Dash slot and clear its MAC from app storage.
  Future<void> disconnectDash();

  /// Whether a device is currently connected to the Dash slot.
  bool dashConnected = false;

  // -- Connection (HRM slot) --

  /// Connect to a Heart Rate Monitor at [deviceId] (MAC address).
  /// Discovers HR Service 0x180D and subscribes to HR measurement notify.
  /// Received HR values are forwarded to the Dash's CTS HR char (if connected).
  Future<void> connectToHrm(String deviceId, {String? name});

  /// Disconnect the HRM slot and clear its MAC from app storage.
  Future<void> disconnectHrm();

  /// Whether a device is currently connected to the HRM slot.
  bool hrmConnected = false;

  // -- Device management --

  /// Remove a device from the scan cache and app storage.
  /// If the device is currently connected, disconnects it first.
  Future<void> forgetDevice(String deviceId);

  // -- NUS command (Dash) --

  /// Send a command line to the Dash over NUS (e.g. "hostname", "ble status").
  /// Returns the parsed [NusReply], or null if NUS is unavailable.
  Future<NusReply?> sendCommand(String line);

  // -- HR write (Dash) --

  /// Push heart rate (BPM) to the Dash's CTS HR write char.
  /// Called automatically when HRM data arrives.
  Future<void> writeHeartRate(int bpm);

  /// Dispose resources.
  Future<void> dispose();
}
