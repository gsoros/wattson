import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry.dart';
import 'ble_service.dart';
import 'ble_scan_result.dart';
import 'cts_parser.dart';

/// Real BLE service using flutter_blue_plus.
///
/// Manages two independent connection slots:
/// - **Dash**: ORD Dash (CTS telemetry + NUS command/reply).
/// - **HRM**: standard BLE Heart Rate Monitor (HR Service 0x180D).
///
/// Exposes a live [scanResults] stream consumed by the settings page.
/// Persistent MAC addresses stored in [SharedPreferences].
class RealBleService implements BleService {
  RealBleService({this.scanTimeout = const Duration(seconds: 10)}) {
    _seedKnownDevices();
  }

  /// How long to scan before automatically stopping.
  final Duration scanTimeout;

  // -- Stream controllers --
  final _scanController = StreamController<List<BleScanResult>>.broadcast();
  final _dashStateController = StreamController<BleConnectionState>.broadcast();
  final _hrmStateController = StreamController<BleConnectionState>.broadcast();
  final _telemetryController = StreamController<Telemetry>.broadcast();

  // -- Scan result cache --
  // Accumulates all devices ever seen across scans, keyed by deviceId.
  // Merged with fresh scan results before emitting.
  final Map<String, BleScanResult> _knownDevices = {};

  // -- Dash slot state --
  BluetoothDevice? _dashDevice;
  BluetoothCharacteristic? _ctsTelemetryChar;
  BluetoothCharacteristic? _nusTxChar;
  BluetoothCharacteristic? _nusRxChar;
  BluetoothCharacteristic? _ctsHrChar;
  StreamSubscription<OnConnectionStateChangedEvent>? _dashConnEventSub;
  StreamSubscription<List<int>>? _ctsSub;
  bool _dashConnected = false;

  // -- HRM slot state --
  BluetoothDevice? _hrmDevice;
  BluetoothCharacteristic? _hrmChar;
  StreamSubscription<OnConnectionStateChangedEvent>? _hrmConnEventSub;
  StreamSubscription<List<int>>? _hrmSub;
  bool _hrmConnected = false;

  // -- NUS reply reassembly state --
  StreamSubscription<List<int>>? _nusTxSub;
  int? _nusExpectedLen;
  final List<int> _nusBuffer = [];
  Completer<String>? _nusCompleter;

  // -- Last known telemetry (for merging HR-only updates) --
  Telemetry? _lastTelemetry;
  int _lastHeartRateBpm = 0;

  // -- Scan state --
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _scanCancelTimer;

  bool _disposed = false;

  @override
  Stream<List<BleScanResult>> get scanResults => _scanController.stream;

  @override
  Stream<BleConnectionState> get dashConnectionState => _dashStateController.stream;

  @override
  Stream<BleConnectionState> get hrmConnectionState => _hrmStateController.stream;

  @override
  Stream<Telemetry> get telemetry => _telemetryController.stream;

  @override
  bool get isScanning => _scanning;

  @override
  Future<bool> isEnabled() async {
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  // ---------------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------------

  @override
  Future<void> startScan() async {
    if (_disposed) return;
    if (_scanning) {
      debugPrint('[RealBle] startScan: already scanning');
      return;
    }

    if (!await _requestBlePermissions()) {
      debugPrint('[RealBle] startScan: permissions not granted');
      return;
    }

    // Wait for adapter to be on.
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      debugPrint('[RealBle] startScan: waiting for adapter...');
      try {
        await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 30));
      } catch (_) {
        debugPrint('[RealBle] startScan: adapter never became ready');
        return;
      }
    }

    _scanning = true;
    debugPrint('[RealBle] startScan: starting scan');

    // Subscribe to results before startScan.
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _onScanResults(results);
    });

    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
    } catch (e) {
      debugPrint('[RealBle] startScan error: $e');
      _scanning = false;
    }

    // Auto-stop when the timeout fires.
    _scanCancelTimer?.cancel();
    _scanCancelTimer = Timer(scanTimeout, () {
      if (_scanning) {
        stopScan();
      }
    });
  }

  @override
  Future<void> stopScan() async {
    if (!_scanning) return;
    debugPrint('[RealBle] stopScan');
    _scanning = false;
    _scanCancelTimer?.cancel();
    _scanCancelTimer = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void _onScanResults(List<ScanResult> results) {
    final connectedIds = <String>{};
    if (_dashDevice != null) connectedIds.add(_dashDevice!.remoteId.str);
    if (_hrmDevice != null) connectedIds.add(_hrmDevice!.remoteId.str);

    // Mark all known devices as out-of-range before we update.
    for (final key in _knownDevices.keys.toList()) {
      _knownDevices[key] = _knownDevices[key]!.copyWith(inRange: false);
    }

    // Merge fresh scan results into the cache.
    final now = DateTime.now();
    for (final r in results) {
      final id = r.device.remoteId.str;
      final name = r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
      _knownDevices[id] = BleScanResult(
        deviceId: id,
        name: name,
        rssi: r.rssi,
        appearance: r.advertisementData.appearance ?? 0,
        isConnected: connectedIds.contains(id),
        inRange: true,
        lastSeen: now,
        serviceUuids: r.advertisementData.serviceUuids.map((g) => g.str).toList(),
      );
    }

    // Emit the merged list.
    _scanController.add(_knownDevices.values.toList());
  }

  /// Seed the known-devices cache from stored MACs so that previously-connected
  /// devices appear in the scan list even when out of range.
  Future<void> _seedKnownDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dashMac = prefs.getString('preferred_dash_mac');
      final hrmMac = prefs.getString('preferred_hrm_mac');
      for (final mac in [dashMac, hrmMac]) {
        if (mac != null && !_knownDevices.containsKey(mac)) {
          _knownDevices[mac] = BleScanResult(deviceId: mac, name: '', inRange: false);
        }
      }
      if (dashMac != null || hrmMac != null) {
        _scanController.add(_knownDevices.values.toList());
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Dash connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connectToDash(String deviceId) async {
    if (_disposed) return;
    if (_dashConnected) {
      debugPrint('[RealBle] connectToDash: already connected');
      return;
    }

    _dashStateController.add(BleConnectionState.scanning);

    // Find the device by remote ID.
    final device = await _findDeviceById(deviceId);
    if (device == null) {
      debugPrint('[RealBle] connectToDash: device $deviceId not found');
      _dashStateController.add(BleConnectionState.disconnected);
      return;
    }

    _dashDevice = device;
    _dashStateController.add(BleConnectionState.connecting);
    debugPrint('[RealBle] connectToDash: found ${device.remoteId}');

    // Persist the MAC.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_dash_mac', deviceId);

    // Listen for disconnection.
    _dashConnEventSub?.cancel();
    _dashConnEventSub = FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (event.device.remoteId == device.remoteId && event.connectionState == BluetoothConnectionState.disconnected) {
        debugPrint('[RealBle] Dash disconnected');
        _dashConnected = false;
        _dashStateController.add(BleConnectionState.disconnected);
        _onDashDisconnected();
      }
    });

    // Connect.
    try {
      await device.connect(license: License.nonprofit, mtu: 247);
      debugPrint('[RealBle] Dash connected');
    } catch (e) {
      debugPrint('[RealBle] Dash connect failed: $e');
      _dashStateController.add(BleConnectionState.disconnected);
      return;
    }

    // Discover services.
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      debugPrint('[RealBle] Dash discoverServices failed: $e');
      await device.disconnect();
      _dashStateController.add(BleConnectionState.disconnected);
      return;
    }

    // Find CTS + NUS characteristics.
    for (final s in services) {
      if (s.uuid == Guid('f6333d96-74c0-462d-b92d-5750a2283429')) {
        for (final c in s.characteristics) {
          if (c.uuid == Guid('5ee460d2-75a3-41ac-9034-2b2d435bb549')) {
            _ctsTelemetryChar = c;
          } else if (c.uuid == Guid('a2c4f7b1-0e3d-4a8c-9b6e-1f2c3d4e5f60')) {
            _ctsHrChar = c;
          }
        }
      }
      if (s.uuid == Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')) {
        for (final c in s.characteristics) {
          if (c.uuid == Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e')) {
            _nusRxChar = c;
          } else if (c.uuid == Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e')) {
            _nusTxChar = c;
          }
        }
      }
    }

    // Subscribe to CTS telemetry.
    final ctsChar = _ctsTelemetryChar;
    if (ctsChar != null) {
      await ctsChar.setNotifyValue(true);
      _ctsSub?.cancel();
      _ctsSub = ctsChar.onValueReceived.listen(_onCtsValue);
      try {
        final initial = await ctsChar.read();
        if (initial.isNotEmpty) _onCtsValue(initial);
      } catch (e) {
        debugPrint('[RealBle] CTS initial read failed: $e');
      }
    } else {
      debugPrint('[RealBle] WARNING: CTS telemetry char not found');
    }

    // Subscribe to NUS TX.
    final nusTx = _nusTxChar;
    if (nusTx != null) {
      await nusTx.setNotifyValue(true);
      _nusTxSub?.cancel();
      _nusTxSub = nusTx.onValueReceived.listen(_onNusTxValue);
    } else {
      debugPrint('[RealBle] WARNING: NUS TX char not found');
    }

    _dashConnected = true;
    _dashStateController.add(BleConnectionState.connected);
    _updateConnectedFlag(deviceId, true);
    _updateKnownDevice(deviceId, name: device.advName.isNotEmpty ? device.advName : device.platformName, appearance: 0x0480);
    debugPrint('[RealBle] connectToDash: done');
  }

  @override
  Future<void> disconnectDash() async {
    final device = _dashDevice;
    final deviceId = device?.remoteId.str;
    _dashDevice = null;
    _dashConnected = false;
    _clearDashChars();

    // Clear stored MAC.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preferred_dash_mac');

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _updateConnectedFlag(deviceId, false);
    _dashStateController.add(BleConnectionState.disconnected);
  }

  void _onDashDisconnected() {
    _dashConnected = false;
    _clearDashChars();
    _updateConnectedFlag(_dashDevice?.remoteId.str, false);
  }

  void _clearDashChars() {
    _ctsTelemetryChar = null;
    _nusTxChar = null;
    _nusRxChar = null;
    _ctsHrChar = null;
    _lastTelemetry = null;
    _lastHeartRateBpm = 0;
    _ctsSub?.cancel();
    _ctsSub = null;
    _nusTxSub?.cancel();
    _nusTxSub = null;
    _dashConnEventSub?.cancel();
    _dashConnEventSub = null;
    _nusCompleter?.completeError('disconnected');
    _nusCompleter = null;
    _nusBuffer.clear();
    _nusExpectedLen = null;
  }

  // ---------------------------------------------------------------------------
  // HRM connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connectToHrm(String deviceId) async {
    if (_disposed) return;
    if (_hrmConnected) {
      debugPrint('[RealBle] connectToHrm: already connected');
      return;
    }

    _hrmStateController.add(BleConnectionState.scanning);

    final device = await _findDeviceById(deviceId);
    if (device == null) {
      debugPrint('[RealBle] connectToHrm: device $deviceId not found');
      _hrmStateController.add(BleConnectionState.disconnected);
      return;
    }

    _hrmDevice = device;
    _hrmStateController.add(BleConnectionState.connecting);
    debugPrint('[RealBle] connectToHrm: found ${device.remoteId}');

    // Persist the MAC.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_hrm_mac', deviceId);

    // Listen for disconnection.
    _hrmConnEventSub?.cancel();
    _hrmConnEventSub = FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (event.device.remoteId == device.remoteId && event.connectionState == BluetoothConnectionState.disconnected) {
        debugPrint('[RealBle] HRM disconnected');
        _hrmConnected = false;
        _hrmStateController.add(BleConnectionState.disconnected);
        _onHrmDisconnected();
      }
    });

    // Connect.
    try {
      await device.connect(license: License.nonprofit);
      debugPrint('[RealBle] HRM connected');
    } catch (e) {
      debugPrint('[RealBle] HRM connect failed: $e');
      _hrmStateController.add(BleConnectionState.disconnected);
      return;
    }

    // Discover services — find HR Service 0x180D / char 0x2A37.
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      debugPrint('[RealBle] HRM discoverServices failed: $e');
      await device.disconnect();
      _hrmStateController.add(BleConnectionState.disconnected);
      return;
    }

    for (final s in services) {
      if (s.uuid == Guid('0000180d-0000-1000-8000-00805f9b34fb')) {
        for (final c in s.characteristics) {
          if (c.uuid == Guid('00002a37-0000-1000-8000-00805f9b34fb')) {
            _hrmChar = c;
          }
        }
      }
    }

    final hrmChar = _hrmChar;
    if (hrmChar != null) {
      await hrmChar.setNotifyValue(true);
      _hrmSub?.cancel();
      _hrmSub = hrmChar.onValueReceived.listen(_onHrmValue);
    } else {
      debugPrint('[RealBle] WARNING: HRM char not found');
    }

    _hrmConnected = true;
    _hrmStateController.add(BleConnectionState.connected);
    _updateConnectedFlag(deviceId, true);
    _updateKnownDevice(deviceId, name: device.advName.isNotEmpty ? device.advName : device.platformName, appearance: 0x0134);
    debugPrint('[RealBle] connectToHrm: done');
  }

  @override
  Future<void> disconnectHrm() async {
    debugPrint('[RealBle] disconnectHrm');
    final device = _hrmDevice;
    final deviceId = device?.remoteId.str;
    _hrmDevice = null;
    _hrmConnected = false;
    _clearHrmChars();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preferred_hrm_mac');

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _updateConnectedFlag(deviceId, false);
    _hrmStateController.add(BleConnectionState.disconnected);
  }

  @override
  Future<void> forgetDevice(String deviceId) async {
    debugPrint('[RealBle] forgetDevice: $deviceId');
    // Disconnect if connected.
    if (_dashDevice?.remoteId.str == deviceId) {
      await disconnectDash();
    } else if (_hrmDevice?.remoteId.str == deviceId) {
      await disconnectHrm();
    }

    // Remove from cache.
    _knownDevices.remove(deviceId);

    // Also clear from preferences if stored.
    final prefs = await SharedPreferences.getInstance();
    final dashMac = prefs.getString('preferred_dash_mac');
    final hrmMac = prefs.getString('preferred_hrm_mac');
    if (dashMac == deviceId) await prefs.remove('preferred_dash_mac');
    if (hrmMac == deviceId) await prefs.remove('preferred_hrm_mac');

    // Re-emit the scan list.
    _scanController.add(_knownDevices.values.toList());
  }

  void _onHrmDisconnected() {
    _hrmConnected = false;
    _clearHrmChars();
    _updateConnectedFlag(_hrmDevice?.remoteId.str, false);
  }

  void _clearHrmChars() {
    _hrmChar = null;
    _hrmSub?.cancel();
    _hrmSub = null;
    _hrmConnEventSub?.cancel();
    _hrmConnEventSub = null;
  }

  // ---------------------------------------------------------------------------
  // NUS command
  // ---------------------------------------------------------------------------

  @override
  Future<String?> sendCommand(String line) async {
    final rx = _nusRxChar;
    if (rx == null) return null;

    await rx.write(line.codeUnits, withoutResponse: false);

    final completer = Completer<String>();
    _nusCompleter = completer;
    _nusBuffer.clear();
    _nusExpectedLen = null;

    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _nusCompleter = null;
      _nusBuffer.clear();
      _nusExpectedLen = null;
      return null;
    }
  }

  @override
  Future<void> writeHeartRate(int bpm) async {
    final hr = _ctsHrChar;
    if (hr == null) return;
    await hr.write([bpm], withoutResponse: true);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnectDash();
    await disconnectHrm();
    await stopScan();
    await _scanController.close();
    await _dashStateController.close();
    await _hrmStateController.close();
    await _telemetryController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Find a previously-seen [BluetoothDevice] by its remote ID string.
  Future<BluetoothDevice?> _findDeviceById(String deviceId) async {
    if (!await _requestBlePermissions()) return null;

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 30));
      } catch (_) {
        return null;
      }
    }

    // The device may be in the system bond list. Try that first.
    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final d in bonded) {
        if (d.remoteId.str == deviceId) return d;
      }
    } catch (_) {}

    // Otherwise scan and find it.
    final completer = Completer<BluetoothDevice?>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.str == deviceId) {
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      return await completer.future.timeout(scanTimeout + const Duration(seconds: 2), onTimeout: () => null);
    } catch (e) {
      debugPrint('[RealBle] _findDeviceById error: $e');
      return null;
    } finally {
      await sub.cancel();
      if (!completer.isCompleted) completer.complete(null);
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  Future<bool> _requestBlePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    final bleResult = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    final bleGranted = bleResult[Permission.bluetoothScan]?.isGranted == true && bleResult[Permission.bluetoothConnect]?.isGranted == true;
    if (!bleGranted) {
      debugPrint('[RealBle] BLUETOOTH_SCAN/CONNECT not granted');
      return false;
    }

    if (await Permission.locationWhenInUse.status.isDenied == true) {
      await Permission.locationWhenInUse.request();
    }

    return true;
  }

  /// Update the cache entry for a device with known name and appearance.
  void _updateKnownDevice(String deviceId, {String? name, int? appearance}) {
    final existing = _knownDevices[deviceId];
    if (existing != null) {
      _knownDevices[deviceId] = existing.copyWith(name: name ?? existing.name, appearance: appearance ?? existing.appearance);
      _scanController.add(_knownDevices.values.toList());
    }
  }

  /// Update the [isConnected] flag on a known device and re-emit the scan list.
  void _updateConnectedFlag(String? deviceId, bool connected) {
    if (deviceId == null) return;
    final existing = _knownDevices[deviceId];
    if (existing != null) {
      _knownDevices[deviceId] = existing.copyWith(isConnected: connected);
      _scanController.add(_knownDevices.values.toList());
    }
  }

  void _onCtsValue(List<int> value) {
    try {
      final telemetry = CtsParser.parse(value, timestamp: DateTime.now());
      final motorPower = telemetry.batteryVoltage * telemetry.batteryCurrent;
      // Preserve the last known HR so CTS updates don't clobber it.
      final result = telemetry.copyWith(motorPowerW: motorPower, heartRateBpm: _lastHeartRateBpm);
      _lastTelemetry = result;
      _telemetryController.add(result);
    } on CtsParseException {
      // Ignore malformed payloads.
    } on CtsVersionException {
      // Ignore unknown versions; forward-compat.
    }
  }

  void _onNusTxValue(List<int> data) {
    if (_nusCompleter == null) return;

    if (_nusExpectedLen == null) {
      if (data.length < 2) return;
      _nusExpectedLen = (data[0] << 8) | data[1];
      _nusBuffer.addAll(data.sublist(2));
    } else {
      _nusBuffer.addAll(data);
    }

    if (_nusBuffer.length >= _nusExpectedLen!) {
      final reply = String.fromCharCodes(_nusBuffer.take(_nusExpectedLen!));
      _nusCompleter!.complete(reply);
      _nusCompleter = null;
      _nusBuffer.clear();
      _nusExpectedLen = null;
    }
  }

  void _onHrmValue(List<int> data) {
    if (data.isEmpty) return;

    // HR Measurement characteristic (0x2A37) format:
    // byte 0: flags (bit 0: 0=uint8, 1=uint16; bit 1: sensor contact status; etc.)
    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;
    int bpm;
    if (isUint16 && data.length >= 3) {
      bpm = (data[1] << 8) | data[2];
    } else {
      bpm = data[1];
    }

    // Update the telemetry stream with HR value.
    // Merge into the last known CTS sample so we don't overwrite real values with zeros.
    _lastHeartRateBpm = bpm;
    final last = _lastTelemetry;
    if (last != null) {
      _telemetryController.add(last.copyWith(heartRateBpm: bpm, timestamp: DateTime.now()));
    } else {
      _telemetryController.add(Telemetry(heartRateBpm: bpm, timestamp: DateTime.now()));
    }

    // Forward to Dash's CTS HR char if connected.
    writeHeartRate(bpm);
  }
}
