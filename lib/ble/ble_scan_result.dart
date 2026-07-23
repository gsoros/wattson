/// A discovered BLE device shown in the scan results list.
class BleScanResult {
  const BleScanResult({
    required this.deviceId,
    required this.name,
    this.rssi,
    this.appearance = 0,
    this.isConnected = false,
    this.isConnecting = false,
    this.inRange = true,
    this.lastSeen,
    this.serviceUuids = const [],
  });

  /// Bluetooth MAC / remote ID.
  final String deviceId;

  /// Advertised name (empty string if none).
  final String name;

  /// Signal strength in dBm (null if unknown).
  final int? rssi;

  /// BLE appearance code (e.g. 0x0480 = Cycling Computer, 0x0134 = HRM).
  final int appearance;

  /// Whether this device is currently connected to one of our slots.
  final bool isConnected;

  /// Whether this device is currently connecting to one of our slots.
  final bool isConnecting;

  /// Whether this device was seen in the most recent scan.
  /// False for stored-but-out-of-range devices.
  final bool inRange;

  /// When this device was last seen in a scan (null = never seen, just stored).
  final DateTime? lastSeen;

  /// Advertised service UUIDs (as 16/32/128-bit hex strings, e.g. "0000180d-...").
  final List<String> serviceUuids;

  BleScanResult copyWith({
    String? deviceId,
    String? name,
    int? rssi,
    int? appearance,
    bool? isConnected,
    bool? isConnecting,
    bool? inRange,
    DateTime? lastSeen,
    List<String>? serviceUuids,
  }) {
    return BleScanResult(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      appearance: appearance ?? this.appearance,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      inRange: inRange ?? this.inRange,
      lastSeen: lastSeen ?? this.lastSeen,
      serviceUuids: serviceUuids ?? this.serviceUuids,
    );
  }
}
