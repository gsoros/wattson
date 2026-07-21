import 'dart:async';
import 'dart:math';

import '../models/telemetry.dart';
import 'ble_service.dart';
import 'ble_scan_result.dart';
import 'nus_protocol.dart';

/// Development BLE service that simulates two virtual devices without hardware.
///
/// Drives a simulated ride and optional HRM for UI/recording/export testing.
class MockBleService implements BleService {
  MockBleService({this.heartRateEnabled = false, this.simAvailable = false}) {
    _dashStateController.add(BleConnectionState.disconnected);
    _hrmStateController.add(BleConnectionState.disconnected);
  }

  final bool heartRateEnabled;

  /// Whether the simulated firmware supports the `sim` command.
  final bool simAvailable;

  final _scanController = StreamController<List<BleScanResult>>.broadcast();
  final _dashStateController = StreamController<BleConnectionState>.broadcast();
  final _hrmStateController = StreamController<BleConnectionState>.broadcast();
  final _telemetryController = StreamController<Telemetry>.broadcast();

  Timer? _tickTimer;
  int _tick = 0;
  bool _scanning = false;

  bool _dashConnected = false;
  @override
  bool get dashConnected => _dashConnected;
  @override
  set dashConnected(bool value) => _dashConnected = value;
  bool _hrmConnected = false;
  @override
  bool get hrmConnected => _hrmConnected;
  @override
  set hrmConnected(bool value) => _hrmConnected = value;

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
  Future<bool> isEnabled() async => true;

  // -- Scan --

  @override
  Future<void> startScan() async {
    _scanning = true;
    final now = DateTime.now();
    _scanController.add([
      BleScanResult(deviceId: '00:11:22:33:44:55', name: 'ord-dev', rssi: -55, appearance: 0x0480, isConnected: dashConnected, lastSeen: now),
      BleScanResult(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: 'Polar H10',
        rssi: -62,
        appearance: 0x0134,
        isConnected: hrmConnected,
        lastSeen: now,
        serviceUuids: ['0000180d-0000-1000-8000-00805f9b34fb'],
      ),
    ]);
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
  }

  // -- Dash --

  @override
  Future<void> connectToDash(String deviceId, {String? name}) async {
    _dashStateController.add(BleConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    dashConnected = true;
    _dashStateController.add(BleConnectionState.connected);
    _ensureTickTimer();
  }

  @override
  Future<void> disconnectDash() async {
    dashConnected = false;
    _dashStateController.add(BleConnectionState.disconnected);
    _maybeStopTimer();
  }

  // -- HRM --

  @override
  Future<void> connectToHrm(String deviceId, {String? name}) async {
    _hrmStateController.add(BleConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    hrmConnected = true;
    _hrmStateController.add(BleConnectionState.connected);
    _ensureTickTimer();
  }

  @override
  Future<void> disconnectHrm() async {
    hrmConnected = false;
    _hrmStateController.add(BleConnectionState.disconnected);
    _maybeStopTimer();
  }

  void _ensureTickTimer() {
    if (_tickTimer != null) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _maybeStopTimer() {
    if (!dashConnected && !hrmConnected) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  void _onTick(Timer _) {
    if (!dashConnected && !hrmConnected) {
      _maybeStopTimer();
      return;
    }
    _tick++;
    final t = _tick.toDouble();

    // Simulate CTS data if Dash is connected.
    if (dashConnected) {
      final speed = 20.0 + 8.0 * sin(t / 20.0);
      final cadence = (60 + 20 * sin(t / 15.0)).round().clamp(0, 120);
      final humanPower = (speed * 3.0 + 20 * sin(t / 10.0)).clamp(0, 400).toDouble();
      final motorPower = (speed * 5.0).clamp(0, 750).toDouble();
      final soc = (100 - t / 30).clamp(0, 100).round();
      final voltage = (54.0 - t / 2000).clamp(40, 58).toDouble();
      final current = (motorPower / voltage).clamp(0, 40).toDouble();
      final range = (soc / 100.0 * 720 / (motorPower / speed).clamp(0.5, 50)).clamp(0, 200).toDouble();
      final pas = [0, 1, 2, 3, 4, 5][_tick ~/ 10 % 6];
      final hr = heartRateEnabled || hrmConnected ? (120 + 10 * sin(t / 8.0)).round() : 0;

      _telemetryController.add(
        Telemetry(
          ordValid: true,
          hrmValid: hr != 0,
          speedKmh: speed,
          batteryVoltage: voltage,
          batteryCurrent: current,
          soc: soc,
          rangeKm: range,
          pasLevel: pas,
          humanPowerW: humanPower,
          motorPowerW: motorPower,
          cadenceRpm: cadence,
          heartRateBpm: hr,
          timestamp: DateTime.now(),
        ),
      );
    } else if (hrmConnected) {
      // HRM-only tick: emit HR without full CTS data.
      _telemetryController.add(Telemetry(hrmValid: true, heartRateBpm: (120 + 10 * sin(t / 8.0)).round(), timestamp: DateTime.now()));
    }
  }

  @override
  Future<NusReply?> sendCommand(String line) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final trimmed = line.trim();
    final spaceIdx = trimmed.indexOf(' ');
    final cmd = spaceIdx >= 0 ? trimmed.substring(0, spaceIdx) : trimmed;
    final args = spaceIdx >= 0 ? trimmed.substring(spaceIdx + 1).trim() : '';

    // Hostname
    if (cmd == 'hostname') {
      if (args.isEmpty) return NusReply(command: 'hostname', data: 'ord-dev');
      return NusReply(command: 'hostname', args: args, data: args);
    }

    // Battery
    if (cmd == 'battery') {
      if (args.isEmpty) return NusReply(command: 'battery', data: '720');
      return NusReply(command: 'battery', args: args, data: 'Battery capacity set to $args Wh');
    }

    // BLE
    if (cmd == 'ble') {
      if (args.isEmpty || args == 'status') {
        return NusReply(command: 'ble', args: args, data: 'enabled: on, connected: true');
      }
      if (args == 'on' || args == 'off' || args == 'toggle') {
        return NusReply(command: 'ble', args: args, data: args == 'on' ? 'on' : 'off');
      }
      return NusReply(command: 'ble', args: args, code: NusReplyCode.invalidArgs, data: 'Usage: ble[ on|off|toggle|status]');
    }

    // WiFi
    if (cmd == 'wifi') {
      if (args.isEmpty) {
        return NusReply(command: 'wifi', data: 'sta: on, ap: off, ssid: MyWiFi, password: secret');
      }
      if (args == 'ssid') return NusReply(command: 'wifi', args: 'ssid', data: 'MyWiFi');
      if (args.startsWith('ssid ')) return NusReply(command: 'wifi', args: args, data: args.substring(5));
      if (args == 'password') return NusReply(command: 'wifi', args: 'password', data: 'secret');
      if (args.startsWith('password ')) return NusReply(command: 'wifi', args: args, data: args.substring(9));
      if (args == 'ap') return NusReply(command: 'wifi', args: 'ap', data: 'off');
      if (args == 'ap on' || args == 'ap off') return NusReply(command: 'wifi', args: args, data: args.endsWith('on') ? 'on' : 'off');
      if (args == 'on' || args == 'off' || args == 'toggle') return NusReply(command: 'wifi', args: args, data: args == 'on' ? 'on' : 'off');
      if (args == 'status') return NusReply(command: 'wifi', args: 'status', data: 'sta: connected, ap_clients: 0');
      return NusReply(
        command: 'wifi',
        args: args,
        code: NusReplyCode.invalidArgs,
        data: 'Usage: wifi[ on|off|toggle|ssid[ ssid]|password[ password]|ap[ on|off|toggle]|status]',
      );
    }

    // Simulator
    if (cmd == 'sim') {
      if (!simAvailable) {
        return NusReply(command: 'sim', args: args, code: NusReplyCode.unknownCommand, data: "'sim' is a mystery");
      }
      if (args.isEmpty || args == 'on' || args == 'off') {
        final state = args.isEmpty ? 'off' : args;
        return NusReply(command: 'sim', args: args, data: 'sim $state');
      }
      return NusReply(command: 'sim', args: args, code: NusReplyCode.invalidArgs, data: 'Usage: sim[ on|off]');
    }

    // Unknown command
    return NusReply(command: cmd, args: args, code: NusReplyCode.unknownCommand, data: "'$cmd' is a mystery");
  }

  @override
  Future<void> writeHeartRate(int bpm) async {
    // No-op in mock.
  }

  @override
  Future<void> forgetDevice(String deviceId) async {
    if (dashConnected && deviceId == '00:11:22:33:44:55') {
      await disconnectDash();
    } else if (hrmConnected && deviceId == 'AA:BB:CC:DD:EE:FF') {
      await disconnectHrm();
    }
  }

  @override
  Future<void> dispose() async {
    _tickTimer?.cancel();
    await _scanController.close();
    await _dashStateController.close();
    await _hrmStateController.close();
    await _telemetryController.close();
  }
}
