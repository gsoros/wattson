/// Central protocol constants and types for the ORD Dash NUS text API.
///
/// All command strings, reply parsing, and data models live here so they can
/// be changed in one place instead of scattered throughout the codebase.
///
/// ## Wire format
///
/// ```
/// API [<command>[ <args>]] (<code>) <data>
/// ```
///
/// See `open-ride-dash/docs/protocol.md` for the authoritative spec.
library;

/// Command strings sent to the ORD Dash over NUS.
///
/// Usage: `sendCommand('${NusCommands.hostname}')` or
/// `sendCommand('${NusCommands.hostname} my-device')`.
class NusCommands {
  NusCommands._();

  static const String version = 'v';
  static const String help = 'help';
  static const String restart = 'restart';
  static const String hostname = 'hostname';
  static const String battery = 'battery';
  static const String ble = 'ble';
  static const String wifi = 'wifi';
  static const String wifiSsid = 'wifi ssid';
  static const String wifiPassword = 'wifi password';
  static const String wifiAp = 'wifi ap';
  static const String wifiStatus = 'wifi status';
  static const String sim = 'sim';
  static const String state = 'state';
}

/// Reply codes from the ORD Dash API.
enum NusReplyCode {
  success,
  unknownCommand,
  invalidArgs,
  executionError;

  /// Parse a code string from the wire format, e.g. `"Success"`.
  static NusReplyCode fromString(String s) {
    switch (s) {
      case 'Success':
        return NusReplyCode.success;
      case 'Unknown Command':
        return NusReplyCode.unknownCommand;
      case 'Invalid Arguments':
        return NusReplyCode.invalidArgs;
      case 'Execution Error':
        return NusReplyCode.executionError;
      default:
        return NusReplyCode.executionError;
    }
  }

  @override
  String toString() {
    switch (this) {
      case NusReplyCode.success:
        return 'Success';
      case NusReplyCode.unknownCommand:
        return 'Unknown Command';
      case NusReplyCode.invalidArgs:
        return 'Invalid Arguments';
      case NusReplyCode.executionError:
        return 'Execution Error';
    }
  }
}

/// A parsed reply from the ORD Dash.
///
/// Wire format: `API [<command>[ <args>]] (<code>) <data>`
class NusReply {
  const NusReply({required this.command, this.args = '', this.code = NusReplyCode.success, this.data = ''});

  /// The command name (e.g. `hostname`, `ble`).
  final String command;

  /// The arguments as received by the handler.
  final String args;

  /// The reply code.
  final NusReplyCode code;

  /// The reply payload (text).
  final String data;

  /// Whether the command succeeded.
  bool get isSuccess => code == NusReplyCode.success;

  /// Parse a raw wire-format string into a [NusReply].
  ///
  /// Returns `null` if the string does not match the expected format.
  static NusReply? parse(String raw) {
    // Format: API [<command>[ <args>]] (<code>) <data>
    final regex = RegExp(r'^API \[(.*?)\] \((\w+(?: \w+)?)\) (.*)$');
    final match = regex.firstMatch(raw.trim());
    if (match == null) return null;

    final cmdAndArgs = match.group(1)!.trim();
    final codeStr = match.group(2)!;
    final data = match.group(3) ?? '';

    // Split cmdAndArgs into command and args at the first space.
    final spaceIdx = cmdAndArgs.indexOf(' ');
    final command = spaceIdx >= 0 ? cmdAndArgs.substring(0, spaceIdx) : cmdAndArgs;
    final args = spaceIdx >= 0 ? cmdAndArgs.substring(spaceIdx + 1) : '';

    return NusReply(command: command, args: args, code: NusReplyCode.fromString(codeStr), data: data);
  }

  @override
  String toString() => 'NusReply(command: $command, args: $args, code: $code, data: $data)';
}

/// Fields that can be configured on the ORD Dash.
///
/// Used for tracking which fields have in-flight commands or errors.
enum DeviceConfigField { hostname, wifiSsid, wifiPassword, staEnabled, apEnabled, bleEnabled, simEnabled, batteryCapacity }

/// Local state for the connected ORD Dash.
///
/// All values are nullable — `null` means "unknown" (not yet fetched or
/// unavailable) .
class DeviceConfig {
  const DeviceConfig({
    this.hostname,
    this.wifiSsid,
    this.wifiPassword,
    this.staEnabled,
    this.apEnabled,
    this.bleEnabled,
    this.simEnabled,
    this.batteryCapacityWh,
    this.simAvailable = false,
  });

  /// Device hostname.
  final String? hostname;

  /// WiFi STA SSID.
  final String? wifiSsid;

  /// WiFi STA password.
  final String? wifiPassword;

  /// Whether WiFi STA mode is enabled.
  final bool? staEnabled;

  /// Whether WiFi AP mode is enabled.
  final bool? apEnabled;

  /// Whether BLE radio is enabled.
  final bool? bleEnabled;

  /// Whether the simulator is enabled (only if [simAvailable]).
  final bool? simEnabled;

  /// Battery capacity in watt-hours.
  final int? batteryCapacityWh;

  /// Whether the `sim` command is available on this firmware build.
  final bool? simAvailable;

  DeviceConfig copyWith({
    String? hostname,
    String? wifiSsid,
    String? wifiPassword,
    bool? staEnabled,
    bool? apEnabled,
    bool? bleEnabled,
    bool? simEnabled,
    int? batteryCapacityWh,
    bool? simAvailable,
  }) {
    return DeviceConfig(
      hostname: hostname ?? this.hostname,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      staEnabled: staEnabled ?? this.staEnabled,
      apEnabled: apEnabled ?? this.apEnabled,
      bleEnabled: bleEnabled ?? this.bleEnabled,
      simEnabled: simEnabled ?? this.simEnabled,
      batteryCapacityWh: batteryCapacityWh ?? this.batteryCapacityWh,
      simAvailable: simAvailable ?? this.simAvailable,
    );
  }

  @override
  String toString() =>
      'DeviceConfig(hostname: $hostname, wifiSsid: $wifiSsid, staEnabled: $staEnabled, '
      'apEnabled: $apEnabled, bleEnabled: $bleEnabled, simEnabled: $simEnabled, '
      'batteryCapacityWh: $batteryCapacityWh, simAvailable: $simAvailable)';
}
