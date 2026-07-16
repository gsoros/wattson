import 'dart:async';
import 'dart:math';

import '../models/telemetry.dart';
import 'ble_service.dart';

/// Development BLE service that emits realistic telemetry without hardware.
///
/// Drives a simulated ride: speed ramps up, cadence/power track speed, battery
/// drains slowly, PAS cycles. Useful for building and testing the UI, recording,
/// and export paths without a physical ORD Dash.
class MockBleService implements BleService {
  MockBleService({this.heartRateEnabled = false});

  final bool heartRateEnabled;

  final _stateController = StreamController<BleConnectionState>.broadcast();
  final _telemetryController = StreamController<Telemetry>.broadcast();

  Timer? _tickTimer;
  int _tick = 0;
  bool _connected = false;

  @override
  Stream<BleConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<Telemetry> get telemetry => _telemetryController.stream;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> connect() async {
    _stateController.add(BleConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _connected = true;
    _stateController.add(BleConnectionState.connected);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  Future<void> disconnect() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _connected = false;
    _stateController.add(BleConnectionState.disconnected);
  }

  void _onTick(Timer _) {
    if (!_connected) return;
    _tick++;
    final t = _tick.toDouble();

    // Smoothly varying speed between ~12 and ~28 km/h.
    final speed = 20.0 + 8.0 * sin(t / 20.0);
    final cadence = (60 + 20 * sin(t / 15.0)).round().clamp(0, 120);
    final humanPower = (speed * 3.0 + 20 * sin(t / 10.0)).clamp(0, 400).toDouble();
    final motorPower = (speed * 5.0).clamp(0, 750).toDouble();
    final soc = (100 - t / 30).clamp(0, 100).round();
    final voltage = (54.0 - t / 2000).clamp(40, 58).toDouble();
    final current = (motorPower / voltage).clamp(0, 40).toDouble();
    final range = (soc / 100.0 * 720 / (motorPower / speed).clamp(0.5, 50)).clamp(0, 200).toDouble();
    final pas = [0, 1, 2, 3, 4, 5][_tick ~/ 10 % 6];

    _telemetryController.add(
      Telemetry(
        speedKmh: speed,
        batteryVoltage: voltage,
        batteryCurrent: current,
        soc: soc,
        rangeKm: range,
        pasLevel: pas,
        humanPowerW: humanPower,
        motorPowerW: motorPower,
        cadenceRpm: cadence,
        heartRateBpm: heartRateEnabled ? (120 + 10 * sin(t / 8.0)).round() : 0,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<String?> sendCommand(String line) async {
    // Echo a plausible API reply for the dev console.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (line.startsWith('hostname')) return 'ord';
    if (line.startsWith('ble')) return 'enabled: true, connected: true';
    if (line.startsWith('battery')) return '720';
    return 'API [$line] (Success) ok';
  }

  @override
  Future<void> writeHeartRate(int bpm) async {
    // No-op in mock; HR is already simulated when enabled.
  }

  @override
  Future<void> dispose() async {
    _tickTimer?.cancel();
    await _stateController.close();
    await _telemetryController.close();
  }
}
