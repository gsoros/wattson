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
  /// Batches all commands into a single state update to avoid per-command
  /// widget rebuilds (which cause skipped frames).
  Future<void> fetchAll() async {
    final service = _getService();
    if (service == null) return;

    // Clear stale state immediately — device may have rebooted, old errors
    // and stale values should not linger for even one frame.
    state = DeviceConfigState(
      config: state.config.copyWith(simAvailable: false, simEnabled: null),
      inProgress: {DeviceConfigField.hostname, DeviceConfigField.batteryCapacity, DeviceConfigField.bleEnabled, DeviceConfigField.wifiSsid},
      errors: {},
    );

    // Collect all replies first without updating state.
    final replies = <DeviceConfigField, NusReply?>{};
    replies[DeviceConfigField.hostname] = await _send(service, NusCommands.hostname);
    replies[DeviceConfigField.batteryCapacity] = await _send(service, NusCommands.battery);
    replies[DeviceConfigField.bleEnabled] = await _send(service, NusCommands.ble);
    replies[DeviceConfigField.wifiSsid] = await _send(service, NusCommands.wifi);
    final simReply = await _send(service, NusCommands.sim);

    // Apply all results in a single state update.
    var config = state.config;
    final errors = <DeviceConfigField, String>{};

    _applyResult(replies[DeviceConfigField.hostname], (data) => config = config.copyWith(hostname: data.trim()), errors, DeviceConfigField.hostname);
    _applyResult(
      replies[DeviceConfigField.batteryCapacity],
      (data) {
        final wh = int.tryParse(data.trim());
        if (wh != null) config = config.copyWith(batteryCapacityWh: wh);
      },
      errors,
      DeviceConfigField.batteryCapacity,
    );
    _applyResult(
      replies[DeviceConfigField.bleEnabled],
      (data) {
        // "enabled: on, connected: true" — \w+ stops at the comma.
        final enabledMatch = RegExp(r'enabled:\s*(\w+)').firstMatch(data);
        if (enabledMatch != null) config = config.copyWith(bleEnabled: enabledMatch.group(1) == 'on');
      },
      errors,
      DeviceConfigField.bleEnabled,
    );
    _applyResult(
      replies[DeviceConfigField.wifiSsid],
      (data) {
        // "sta: on, ap: on, ssid: myNetwork, password: secret" — \w+ stops at commas.
        final staMatch = RegExp(r'sta:\s*(\w+)').firstMatch(data);
        final apMatch = RegExp(r'ap:\s*(\w+)').firstMatch(data);
        final ssidMatch = RegExp(r'ssid:\s*(.+?)(?:,\s*password:|$)').firstMatch(data);
        final pwMatch = RegExp(r'password:\s*(.+?)$').firstMatch(data);
        config = config.copyWith(
          staEnabled: staMatch != null ? staMatch.group(1) == 'on' : null,
          apEnabled: apMatch != null ? apMatch.group(1) == 'on' : null,
          wifiSsid: ssidMatch?.group(1)?.trim(),
          wifiPassword: pwMatch?.group(1)?.trim(),
        );
      },
      errors,
      DeviceConfigField.wifiSsid,
    );

    if (simReply != null && simReply.isSuccess) {
      config = config.copyWith(simAvailable: true, simEnabled: _parseSimEnabled(simReply.data));
    } else {
      config = config.copyWith(simAvailable: false, simEnabled: null);
    }

    state = DeviceConfigState(config: config, inProgress: {}, errors: errors);
  }

  /// Apply a single fetch result: run [apply] on success, record error on failure.
  void _applyResult(NusReply? reply, void Function(String data) apply, Map<DeviceConfigField, String> errors, DeviceConfigField field) {
    if (reply != null && reply.isSuccess) {
      apply(reply.data);
    } else {
      errors[field] = reply?.data ?? 'Failed to fetch';
    }
  }

  // ---------------------------------------------------------------------------
  // Setters
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

  /// Set the hostname.
  Future<void> setHostname(String value) async {
    await _setAndFetch(DeviceConfigField.hostname, '${NusCommands.hostname} $value', (cfg) => cfg.copyWith(hostname: value));
  }

  /// Set the battery capacity (Wh).
  Future<void> setBatteryCapacity(int wh) async {
    await _setAndFetch(DeviceConfigField.batteryCapacity, '${NusCommands.battery} $wh', (cfg) => cfg.copyWith(batteryCapacityWh: wh));
  }

  /// Set WiFi STA SSID.
  Future<void> setWifiSsid(String value) async {
    await _setAndFetch(DeviceConfigField.wifiSsid, '${NusCommands.wifiSsid} $value', (cfg) => cfg.copyWith(wifiSsid: value));
  }

  /// Set WiFi STA password.
  Future<void> setWifiPassword(String value) async {
    await _setAndFetch(DeviceConfigField.wifiPassword, '${NusCommands.wifiPassword} $value', (cfg) => cfg.copyWith(wifiPassword: value));
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
  // Parsers / updaters
  // ---------------------------------------------------------------------------

  bool _parseSimEnabled(String data) {
    // "sim on" or "sim off"
    return data.trim() == 'sim on';
  }
}

/// Provider for the device config state (config + in-progress + errors).
final deviceConfigProvider = NotifierProvider<DeviceConfigNotifier, DeviceConfigState>(DeviceConfigNotifier.new);
