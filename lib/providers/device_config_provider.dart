import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../ble/nus_protocol.dart';
import '../util/app_log.dart';
import 'ble_provider.dart';

/// Combined state for the device config UI.
class DeviceConfigState {
  const DeviceConfigState({this.config = const DeviceConfig(), this.inProgress = const {}, this.errors = const {}});

  /// The device config values.
  final DeviceConfig config;

  /// Set of fields that currently have a command in flight.
  final Set<DeviceConfigField> inProgress;

  /// Map of fields to error messages.
  final Map<DeviceConfigField, String> errors;

  DeviceConfigState copyWith({DeviceConfig? config, Set<DeviceConfigField>? inProgress, Map<DeviceConfigField, String>? errors}) {
    return DeviceConfigState(config: config ?? this.config, inProgress: inProgress ?? this.inProgress, errors: errors ?? this.errors);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConfigState &&
          config == other.config &&
          inProgress.length == other.inProgress.length &&
          inProgress.containsAll(other.inProgress) &&
          errors.length == other.errors.length &&
          errors.entries.every((e) => other.errors[e.key] == e.value);

  @override
  int get hashCode => Object.hash(config, Object.hashAll(inProgress), Object.hashAll(errors.entries));
}

/// Manages the local device config state for the connected ORD Dash.
///
/// All values are nullable — `null` means "unknown" (not yet fetched or
/// unavailable). The notifier sends commands over NUS via [BleService] and
/// updates state based on the parsed [NusReply].
class DeviceConfigNotifier extends Notifier<DeviceConfigState> {
  @override
  DeviceConfigState build() => const DeviceConfigState();

  /// Module logger.
  static final _log = AppLog.logFor('DeviceConfig');

  // ---------------------------------------------------------------------------
  // Fetch all
  // ---------------------------------------------------------------------------

  /// Fetch all config values from the connected Dash.
  ///
  /// Sends commands sequentially and updates state as each reply arrives.
  /// Fields that fail remain `null` and an error is recorded.
  Future<void> fetchAll() async {
    final service = _getService();
    if (service == null) return;

    state = state.copyWith(errors: {});

    await _fetch(service, DeviceConfigField.hostname, NusCommands.hostname, _parseHostname);
    await _fetch(service, DeviceConfigField.batteryCapacity, NusCommands.battery, _parseBattery);
    await _fetch(service, DeviceConfigField.bleEnabled, NusCommands.ble, _parseBle);

    // WiFi summary (includes ssid, password, sta, ap).
    await _fetch(service, DeviceConfigField.wifiSsid, NusCommands.wifi, _parseWifiSummary);

    // Probe sim command.
    final simReply = await _send(service, NusCommands.sim);
    if (simReply != null && simReply.isSuccess) {
      state = state.copyWith(config: state.config.copyWith(simAvailable: true, simEnabled: _parseSimEnabled(simReply.data)));
    } else {
      state = state.copyWith(config: state.config.copyWith(simAvailable: false, simEnabled: null));
    }
  }

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------

  /// Set the hostname.
  Future<void> setHostname(String value) async {
    await _setAndFetch(DeviceConfigField.hostname, '${NusCommands.hostname} $value', _updateHostname);
  }

  /// Set the battery capacity (Wh).
  Future<void> setBatteryCapacity(int wh) async {
    await _setAndFetch(DeviceConfigField.batteryCapacity, '${NusCommands.battery} $wh', _updateBattery);
  }

  /// Set WiFi STA SSID.
  Future<void> setWifiSsid(String value) async {
    await _setAndFetch(DeviceConfigField.wifiSsid, '${NusCommands.wifiSsid} $value', _updateWifiSsid);
  }

  /// Set WiFi STA password.
  Future<void> setWifiPassword(String value) async {
    await _setAndFetch(DeviceConfigField.wifiPassword, '${NusCommands.wifiPassword} $value', _updateWifiPassword);
  }

  /// Enable or disable BLE radio.
  Future<void> setBleEnabled(bool on) async {
    final cmd = '${NusCommands.ble} ${on ? 'on' : 'off'}';
    await _setAndFetch(DeviceConfigField.bleEnabled, cmd, (cfg) => cfg.copyWith(bleEnabled: on));
  }

  /// Enable or disable WiFi STA.
  Future<void> setStaEnabled(bool on) async {
    final cmd = '${NusCommands.wifi} ${on ? 'on' : 'off'}';
    await _setAndFetch(DeviceConfigField.staEnabled, cmd, (cfg) => cfg.copyWith(staEnabled: on));
  }

  /// Enable or disable WiFi AP.
  Future<void> setApEnabled(bool on) async {
    final cmd = '${NusCommands.wifiAp} ${on ? 'on' : 'off'}';
    await _setAndFetch(DeviceConfigField.apEnabled, cmd, (cfg) => cfg.copyWith(apEnabled: on));
  }

  /// Enable or disable the simulator.
  Future<void> setSimEnabled(bool on) async {
    final cmd = '${NusCommands.sim} ${on ? 'on' : 'off'}';
    await _setAndFetch(DeviceConfigField.simEnabled, cmd, (cfg) => cfg.copyWith(simEnabled: on));
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  BleService? _getService() {
    try {
      return ref.read(bleServiceProvider);
    } catch (_) {
      return null;
    }
  }

  Future<NusReply?> _send(BleService service, String command) async {
    try {
      return await service.sendCommand(command);
    } catch (e) {
      _log.e('send error: $e', error: e);
      return null;
    }
  }

  /// Fetch a single field and update state.
  Future<void> _fetch(BleService service, DeviceConfigField field, String command, void Function(DeviceConfig config, String data) parser) async {
    state = state.copyWith(inProgress: {...state.inProgress, field});
    final reply = await _send(service, command);
    if (reply != null && reply.isSuccess) {
      parser(state.config, reply.data);
      final newErrors = Map<DeviceConfigField, String>.from(state.errors)..remove(field);
      state = state.copyWith(inProgress: {...state.inProgress}..remove(field), errors: newErrors);
    } else {
      state = state.copyWith(inProgress: {...state.inProgress}..remove(field), errors: {...state.errors, field: reply?.data ?? 'Failed to fetch'});
    }
  }

  /// Set a value and update state optimistically.
  Future<void> _setAndFetch(DeviceConfigField field, String command, DeviceConfig Function(DeviceConfig config) updater) async {
    final service = _getService();
    if (service == null) return;

    state = state.copyWith(inProgress: {...state.inProgress, field});
    final reply = await _send(service, command);
    if (reply != null && reply.isSuccess) {
      final newConfig = updater(state.config);
      final newErrors = Map<DeviceConfigField, String>.from(state.errors)..remove(field);
      state = state.copyWith(config: newConfig, inProgress: {...state.inProgress}..remove(field), errors: newErrors);
    } else {
      state = state.copyWith(inProgress: {...state.inProgress}..remove(field), errors: {...state.errors, field: reply?.data ?? 'Command failed'});
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers / updaters
  // ---------------------------------------------------------------------------

  void _parseHostname(DeviceConfig config, String data) {
    state = state.copyWith(config: config.copyWith(hostname: data.trim()));
  }

  DeviceConfig _updateHostname(DeviceConfig config) => config.copyWith(hostname: config.hostname);

  void _parseBattery(DeviceConfig config, String data) {
    final trimmed = data.trim();
    final wh = int.tryParse(trimmed);
    if (wh != null) {
      state = state.copyWith(config: config.copyWith(batteryCapacityWh: wh));
    }
  }

  DeviceConfig _updateBattery(DeviceConfig config) => config.copyWith(batteryCapacityWh: config.batteryCapacityWh);

  void _parseBle(DeviceConfig config, String data) {
    // "enabled: on, connected: true"
    final enabledMatch = RegExp(r'enabled:\s*(\S+)').firstMatch(data);
    if (enabledMatch != null) {
      state = state.copyWith(config: config.copyWith(bleEnabled: enabledMatch.group(1) == 'on'));
    }
  }

  void _parseWifiSummary(DeviceConfig config, String data) {
    // "sta: on, ap: off, ssid: MyWiFi, password: secret"
    final staMatch = RegExp(r'sta:\s*(\S+)').firstMatch(data);
    final apMatch = RegExp(r'ap:\s*(\S+)').firstMatch(data);
    final ssidMatch = RegExp(r'ssid:\s*(.+?)(?:,\s*password:|$)').firstMatch(data);
    final pwMatch = RegExp(r'password:\s*(.+?)$').firstMatch(data);

    state = state.copyWith(
      config: config.copyWith(
        staEnabled: staMatch != null ? staMatch.group(1) == 'on' : null,
        apEnabled: apMatch != null ? apMatch.group(1) == 'on' : null,
        wifiSsid: ssidMatch?.group(1)?.trim(),
        wifiPassword: pwMatch?.group(1)?.trim(),
      ),
    );
  }

  bool _parseSimEnabled(String data) {
    // "sim on" or "sim off"
    return data.trim() == 'sim on';
  }

  DeviceConfig _updateWifiSsid(DeviceConfig config) => config.copyWith(wifiSsid: config.wifiSsid);

  DeviceConfig _updateWifiPassword(DeviceConfig config) => config.copyWith(wifiPassword: config.wifiPassword);
}

/// Provider for the device config state (config + in-progress + errors).
final deviceConfigProvider = NotifierProvider<DeviceConfigNotifier, DeviceConfigState>(DeviceConfigNotifier.new);
