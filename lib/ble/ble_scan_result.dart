/// A discovered BLE device shown in the scan results list.
class BleScanResult {
  const BleScanResult({required this.deviceId, required this.name, this.rssi, this.appearance = 0, this.isConnected = false, this.inRange = true});

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

  /// Whether this device was seen in the most recent scan.
  /// False for stored-but-out-of-range devices.
  final bool inRange;

  BleScanResult copyWith({String? deviceId, String? name, int? rssi, int? appearance, bool? isConnected, bool? inRange}) {
    return BleScanResult(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      appearance: appearance ?? this.appearance,
      isConnected: isConnected ?? this.isConnected,
      inRange: inRange ?? this.inRange,
    );
  }
}
