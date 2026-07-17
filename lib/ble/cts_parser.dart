import '../models/telemetry.dart';

/// Decodes the ORD Dash CTS (custom telemetry service) payload.
///
/// Fixed 14-byte little-endian payload, version 1:
///   byte  0    : version (0x01)
///   bytes 1-2  : speed, km/h * 100 (uint16, little-endian)
///   bytes 3-4  : battery voltage, V * 100 (uint16, little-endian)
///   bytes 5-6  : battery current, A * 100 (uint16, little-endian, unsigned)
///   byte  7    : state of charge, % (uint8)
///   bytes 8-9  : range, km * 100 (uint16, little-endian)
///   byte  10   : PAS level (int8: -1 walk, 0 off, 1-5)
///   bytes 11-12: human power, W * 10 (uint16, little-endian)
///   byte  13   : cadence, RPM (uint8)
///
/// Forward-compatible: trailing bytes beyond 14 are ignored; unknown versions
/// throw [CtsVersionException].
class CtsParser {
  static const int expectedVersion = 0x01;
  static const int payloadSize = 14;

  /// Parses a CTS payload into a [Telemetry] (CTS fields only; motor power and
  /// heart rate are filled from other sources).
  static Telemetry parse(List<int> payload, {DateTime? timestamp}) {
    if (payload.isEmpty) {
      throw const CtsParseException('Empty CTS payload');
    }
    final version = payload[0];
    if (version != expectedVersion) {
      throw CtsVersionException(version);
    }
    if (payload.length < payloadSize) {
      throw CtsParseException('CTS payload too short: ${payload.length} < $payloadSize');
    }

    final speed = _readUint16(payload, 1) / 100.0;
    final voltage = _readUint16(payload, 3) / 100.0;
    final current = _readUint16(payload, 5) / 100.0;
    final soc = payload[7];
    final range = _readUint16(payload, 8) / 100.0;
    // int8 reinterpreted as raw byte (handles -1 walk assist).
    final pas = payload[10] >= 0x80 ? payload[10] - 0x100 : payload[10];
    final humanPower = _readUint16(payload, 11) / 10.0;
    final cadence = payload[13];

    return Telemetry(
      speedKmh: speed,
      batteryVoltage: voltage,
      batteryCurrent: current,
      soc: soc,
      rangeKm: range,
      pasLevel: pas,
      humanPowerW: humanPower,
      motorPowerW: 0,
      cadenceRpm: cadence,
      heartRateBpm: 0,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  static int _readUint16(List<int> b, int offset) {
    // Little-endian: LSB at offset, MSB at offset+1.
    return b[offset] | (b[offset + 1] << 8);
  }
}

class CtsParseException implements Exception {
  const CtsParseException(this.message);
  final String message;
  @override
  String toString() => 'CtsParseException: $message';
}

class CtsVersionException implements Exception {
  const CtsVersionException(this.version);
  final int version;
  @override
  String toString() => 'CtsVersionException: unsupported CTS version $version';
}
