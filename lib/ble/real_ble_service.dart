import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/telemetry.dart';
import 'ble_service.dart';
import 'cts_parser.dart';

/// Real BLE service using flutter_blue_plus.
///
/// Scans for the ORD Dash by hostname, connects, subscribes to CTS telemetry
/// notifications, and bridges NUS command/reply. Bonding is handled by the OS
/// (system dialog for passkey entry).
class RealBleService implements BleService {
  RealBleService({this.dashName = 'ord-dev', this.scanTimeout = const Duration(seconds: 10)});

  /// The expected hostname of the ORD Dash (default "ord-dev").
  final String dashName;

  /// How long to scan before giving up.
  final Duration scanTimeout;

  final _stateController = StreamController<BleConnectionState>.broadcast();
  final _telemetryController = StreamController<Telemetry>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _ctsTelemetryChar;
  BluetoothCharacteristic? _nusTxChar;
  BluetoothCharacteristic? _nusRxChar;
  BluetoothCharacteristic? _ctsHrChar;

  // NUS reply reassembly state.
  StreamSubscription<List<int>>? _nusTxSub;
  int? _nusExpectedLen;
  final List<int> _nusBuffer = [];
  Completer<String>? _nusCompleter;

  StreamSubscription<OnConnectionStateChangedEvent>? _connStateEventSub;
  StreamSubscription<List<int>>? _ctsSub;
  bool _disposed = false;

  @override
  Stream<BleConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<Telemetry> get telemetry => _telemetryController.stream;

  @override
  Future<bool> isEnabled() async {
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  @override
  Future<void> connect() async {
    if (_disposed) return;
    _stateController.add(BleConnectionState.scanning);
    debugPrint('[RealBle] connect: scanning for "$dashName"...');

    // 1. Start scan and find our device.
    final device = await _findDevice();
    if (device == null) {
      debugPrint('[RealBle] connect: device not found');
      _stateController.add(BleConnectionState.disconnected);
      return;
    }
    _device = device;
    _stateController.add(BleConnectionState.connecting);
    debugPrint('[RealBle] connect: found device ${device.remoteId}');

    // 2. Listen for disconnection events.
    // Use the global event stream to avoid the initial-state emission that
    // device.connectionState sends on first listen.
    _connStateEventSub?.cancel();
    _connStateEventSub = FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (event.device.remoteId == device.remoteId && event.connectionState == BluetoothConnectionState.disconnected) {
        debugPrint('[RealBle] disconnected event');
        _stateController.add(BleConnectionState.disconnected);
        _onDisconnected();
      }
    });

    // 3. Connect.
    try {
      debugPrint('[RealBle] connect: calling device.connect()...');
      await device.connect(
        license: License.nonprofit,
        mtu: 247, // matches firmware negotiation
      );
      debugPrint('[RealBle] connect: connected');
    } catch (e) {
      debugPrint('[RealBle] connect failed: $e');
      _stateController.add(BleConnectionState.disconnected);
      return;
    }

    // 4. Discover services.
    List<BluetoothService> services;
    try {
      debugPrint('[RealBle] discovering services...');
      services = await device.discoverServices();
      debugPrint('[RealBle] found ${services.length} services');
    } catch (e) {
      debugPrint('[RealBle] discoverServices failed: $e');
      await device.disconnect();
      _stateController.add(BleConnectionState.disconnected);
      return;
    }

    // 5. Find our characteristics.
    for (final s in services) {
      debugPrint('[RealBle]   service: ${s.uuid}');
      // CTS: f6333d96-74c0-462d-b92d-5750a2283429
      if (s.uuid == Guid('f6333d96-74c0-462d-b92d-5750a2283429')) {
        for (final c in s.characteristics) {
          debugPrint('[RealBle]     CTS char: ${c.uuid}');
          if (c.uuid == Guid('5ee460d2-75a3-41ac-9034-2b2d435bb549')) {
            _ctsTelemetryChar = c;
          } else if (c.uuid == Guid('a2c4f7b1-0e3d-4a8c-9b6e-1f2c3d4e5f60')) {
            _ctsHrChar = c;
          }
        }
      }
      // NUS: 6e400001-b5a3-f393-e0a9-e50e24dcca9e
      if (s.uuid == Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')) {
        for (final c in s.characteristics) {
          debugPrint('[RealBle]     NUS char: ${c.uuid}');
          if (c.uuid == Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e')) {
            _nusRxChar = c;
          } else if (c.uuid == Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e')) {
            _nusTxChar = c;
          }
        }
      }
    }

    // 6. Subscribe to CTS telemetry notifications.
    final ctsChar = _ctsTelemetryChar;
    if (ctsChar != null) {
      debugPrint('[RealBle] subscribing to CTS notify...');
      await ctsChar.setNotifyValue(true);
      _ctsSub?.cancel();
      _ctsSub = ctsChar.onValueReceived.listen(_onCtsValue);
    } else {
      debugPrint('[RealBle] WARNING: CTS telemetry char not found');
    }

    // 7. Subscribe to NUS TX notifications for reply reassembly.
    final nusTx = _nusTxChar;
    if (nusTx != null) {
      debugPrint('[RealBle] subscribing to NUS TX notify...');
      await nusTx.setNotifyValue(true);
      _nusTxSub?.cancel();
      _nusTxSub = nusTx.onValueReceived.listen(_onNusTxValue);
    } else {
      debugPrint('[RealBle] WARNING: NUS TX char not found');
    }

    debugPrint('[RealBle] connect: done');
    _stateController.add(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    final device = _device;
    _device = null;
    _ctsTelemetryChar = null;
    _nusTxChar = null;
    _nusRxChar = null;
    _ctsHrChar = null;

    _ctsSub?.cancel();
    _ctsSub = null;
    _nusTxSub?.cancel();
    _nusTxSub = null;
    _connStateEventSub?.cancel();
    _connStateEventSub = null;

    _nusCompleter?.completeError('disconnected');
    _nusCompleter = null;
    _nusBuffer.clear();
    _nusExpectedLen = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _stateController.add(BleConnectionState.disconnected);
  }

  @override
  Future<String?> sendCommand(String line) async {
    final rx = _nusRxChar;
    if (rx == null) return null;

    // Write the command to NUS RX.
    await rx.write(line.codeUnits, withoutResponse: false);

    // Wait for the NUS TX reply (fragmented, length-prefixed).
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
    await disconnect();
    await _stateController.close();
    await _telemetryController.close();
  }

  // ---- Private helpers ----

  Future<BluetoothDevice?> _findDevice() async {
    // 1. Request runtime permissions (Android 12+ needs BLUETOOTH_SCAN + CONNECT,
    //    older needs ACCESS_FINE_LOCATION).
    if (!await _requestBlePermissions()) {
      debugPrint('[RealBle] _findDevice: permissions not granted');
      return null;
    }

    // 2. Wait for the adapter to be ready.
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      debugPrint('[RealBle] _findDevice: waiting for adapter to be on...');
      try {
        await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 30));
      } catch (_) {
        debugPrint('[RealBle] _findDevice: adapter never became ready');
        return null;
      }
    }
    debugPrint('[RealBle] _findDevice: adapter is on');

    // 3. Subscribe to scan results BEFORE starting the scan.
    debugPrint('[RealBle] _findDevice: scanning for "$dashName"...');

    // Subscribe before startScan to avoid the race vs first result.
    final completer = Completer<BluetoothDevice?>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
        final appearance = r.advertisementData.appearance;
        debugPrint('[RealBle]   scan result: "$name" appearance=$appearance');
        if (name == dashName || appearance == 0x0480) {
          debugPrint('[RealBle]   -> MATCH');
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    // 4. Start the scan.
    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      final device = await completer.future.timeout(scanTimeout + const Duration(seconds: 2), onTimeout: () => null);
      if (device != null) {
        debugPrint('[RealBle]   -> MATCH: ${device.remoteId}');
      } else {
        debugPrint('[RealBle]   -> no match found');
      }
      return device;
    } catch (e) {
      debugPrint('[RealBle] _findDevice error: $e');
      return null;
    } finally {
      await sub.cancel();
      if (!completer.isCompleted) completer.complete(null);
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  /// Request BLE runtime permissions. Returns true if sufficient permissions
  /// are granted for scanning.
  Future<bool> _requestBlePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    // Android 12+ (API 31+): BLUETOOTH_SCAN + BLUETOOTH_CONNECT are sufficient.
    // Always request them — the dialog won't show if already granted.
    debugPrint('[RealBle] requesting BLUETOOTH_SCAN + BLUETOOTH_CONNECT...');
    final bleResult = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    final bleGranted = bleResult[Permission.bluetoothScan]?.isGranted == true && bleResult[Permission.bluetoothConnect]?.isGranted == true;
    if (!bleGranted) {
      debugPrint('[RealBle] BLUETOOTH_SCAN/CONNECT not granted');
      return false;
    }

    // Android <12: location permission is required for BLE scan.
    // On Android 12+ it's optional (some devices need it, some don't).
    if (await Permission.locationWhenInUse.status.isDenied == true) {
      debugPrint('[RealBle] requesting location permission...');
      final locResult = await Permission.locationWhenInUse.request();
      if (locResult.isGranted != true) {
        debugPrint('[RealBle] location not granted — BLE scan may still work');
        // Don't return false; BLE permissions alone may suffice on 12+.
      }
    }

    return true;
  }

  void _onCtsValue(List<int> value) {
    try {
      final telemetry = CtsParser.parse(value, timestamp: DateTime.now());

      // Motor power is derived from CTS voltage * current (no regen, so current is unsigned).
      final motorPower = telemetry.batteryVoltage * telemetry.batteryCurrent;

      _telemetryController.add(telemetry.copyWith(motorPowerW: motorPower));
    } on CtsParseException {
      // Ignore malformed payloads.
    } on CtsVersionException {
      // Ignore unknown versions; forward-compat.
    }
  }

  void _onNusTxValue(List<int> data) {
    if (_nusCompleter == null) return;

    if (_nusExpectedLen == null) {
      // First frame: 2-byte big-endian total length prefix.
      if (data.length < 2) return;
      _nusExpectedLen = (data[0] << 8) | data[1];
      _nusBuffer.addAll(data.sublist(2));
    } else {
      // Subsequent frames: raw continuation data.
      _nusBuffer.addAll(data);
    }

    // Check if we've received the full reply.
    if (_nusBuffer.length >= _nusExpectedLen!) {
      final reply = String.fromCharCodes(_nusBuffer.take(_nusExpectedLen!));
      _nusCompleter!.complete(reply);
      _nusCompleter = null;
      _nusBuffer.clear();
      _nusExpectedLen = null;
    }
  }

  void _onDisconnected() {
    _ctsTelemetryChar = null;
    _nusTxChar = null;
    _nusRxChar = null;
    _ctsHrChar = null;
    _ctsSub?.cancel();
    _ctsSub = null;
    _nusTxSub?.cancel();
    _nusTxSub = null;
    _connStateEventSub?.cancel();
    _connStateEventSub = null;
    _nusCompleter?.completeError('disconnected');
    _nusCompleter = null;
    _nusBuffer.clear();
    _nusExpectedLen = null;
  }
}
