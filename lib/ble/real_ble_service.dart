import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/telemetry.dart';
import 'ble_service.dart';
import 'cts_parser.dart';

/// Real BLE service using flutter_blue_plus.
///
/// Scans for the ORD Dash by hostname, connects, subscribes to CTS telemetry
/// notifications, and bridges NUS command/reply. Bonding is handled by the OS
/// (system dialog for passkey entry).
class RealBleService implements BleService {
  RealBleService({this.dashName = 'ORD Dash', this.scanTimeout = const Duration(seconds: 10)});

  /// The expected hostname of the ORD Dash (default "ORD Dash").
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

  StreamSubscription<BluetoothConnectionState>? _connStateSub;
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

    // 1. Start scan and find our device.
    final device = await _findDevice();
    if (device == null) {
      _stateController.add(BleConnectionState.disconnected);
      return;
    }
    _device = device;
    _stateController.add(BleConnectionState.connecting);

    // 2. Listen for connection state changes.
    _connStateSub?.cancel();
    _connStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _stateController.add(BleConnectionState.disconnected);
        _onDisconnected();
      }
    });

    // 3. Connect.
    try {
      await device.connect(
        license: License.nonprofit,
        mtu: 247, // matches firmware negotiation
      );
    } catch (e) {
      _stateController.add(BleConnectionState.disconnected);
      return;
    }

    // 4. Discover services.
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      await device.disconnect();
      _stateController.add(BleConnectionState.disconnected);
      return;
    }

    // 5. Find our characteristics.
    for (final s in services) {
      // CTS: f6333d96-74c0-462d-b92d-5750a2283429
      if (s.uuid == Guid('f6333d96-74c0-462d-b92d-5750a2283429')) {
        for (final c in s.characteristics) {
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
      await ctsChar.setNotifyValue(true);
      _ctsSub?.cancel();
      _ctsSub = ctsChar.onValueReceived.listen(_onCtsValue);
    }

    // 7. Subscribe to NUS TX notifications for reply reassembly.
    final nusTx = _nusTxChar;
    if (nusTx != null) {
      await nusTx.setNotifyValue(true);
      _nusTxSub?.cancel();
      _nusTxSub = nusTx.onValueReceived.listen(_onNusTxValue);
    }

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
    _connStateSub?.cancel();
    _connStateSub = null;

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
    // Check if adapter is on.
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      return null;
    }

    final completer = Completer<BluetoothDevice?>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        // Match by name (advertised name or platform name).
        final name = r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
        if (name == dashName) {
          completer.complete(r.device);
          return;
        }
        // Also match by appearance 0x0480 (Cycling Computer).
        final appearance = r.advertisementData.appearance;
        if (appearance == 0x0480) {
          completer.complete(r.device);
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(withNames: [dashName], timeout: scanTimeout);
      final device = await completer.future;
      return device;
    } catch (_) {
      return null;
    } finally {
      await sub.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
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
    _connStateSub?.cancel();
    _connStateSub = null;
    _nusCompleter?.completeError('disconnected');
    _nusCompleter = null;
    _nusBuffer.clear();
    _nusExpectedLen = null;
  }
}
