import 'package:flutter_test/flutter_test.dart';
import 'package:wattson/ble/cts_parser.dart';

// Helper: build a 14-byte little-endian CTS payload.
List<int> buildPayload({
  int version = 0x01,
  int speed = 2000, // 20.00 km/h
  int voltage = 5400, // 54.00 V
  int current = 1000, // 10.00 A
  int soc = 80,
  int range = 5000, // 50.00 km
  int pas = 3,
  int humanPower = 1500, // 150.0 W
  int cadence = 70,
}) {
  final b = List<int>.filled(14, 0, growable: true);
  b[0] = version;
  b[1] = speed & 0xFF;
  b[2] = (speed >> 8) & 0xFF;
  b[3] = voltage & 0xFF;
  b[4] = (voltage >> 8) & 0xFF;
  b[5] = current & 0xFF;
  b[6] = (current >> 8) & 0xFF;
  b[7] = soc;
  b[8] = range & 0xFF;
  b[9] = (range >> 8) & 0xFF;
  b[10] = pas;
  b[11] = humanPower & 0xFF;
  b[12] = (humanPower >> 8) & 0xFF;
  b[13] = cadence;
  return b;
}

void main() {
  group('CtsParser', () {
    test('parses all fields correctly', () {
      final t = CtsParser.parse(buildPayload());
      expect(t.speedKmh, 20.0);
      expect(t.batteryVoltage, 54.0);
      expect(t.batteryCurrent, 10.0);
      expect(t.soc, 80);
      expect(t.rangeKm, 50.0);
      expect(t.pasLevel, 3);
      expect(t.humanPowerW, 150.0);
      expect(t.cadenceRpm, 70);
    });

    test('decodes negative PAS (walk assist = -1)', () {
      // -1 as int8 -> 0xFF
      final t = CtsParser.parse(buildPayload(pas: 0xFF));
      expect(t.pasLevel, -1);
    });

    test('ignores trailing bytes (forward-compatible)', () {
      final payload = buildPayload()..addAll([0, 0, 0]);
      final t = CtsParser.parse(payload);
      expect(t.speedKmh, 20.0);
    });

    test('rejects unknown version', () {
      expect(() => CtsParser.parse(buildPayload(version: 0x02)), throwsA(isA<CtsVersionException>()));
    });

    test('rejects too-short payload', () {
      expect(() => CtsParser.parse([0x01, 0, 0]), throwsA(isA<CtsParseException>()));
    });

    test('rejects empty payload', () {
      expect(() => CtsParser.parse([]), throwsA(isA<CtsParseException>()));
    });
  });
}
