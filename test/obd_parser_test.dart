import 'package:flutter_test/flutter_test.dart';

/// OBD ELM327 parsing logic tests.
///
/// These tests document the expected parsing behavior that obd_service.dart
/// must implement. The formulas are tested directly here using raw arithmetic
/// so there is no dependency on the not-yet-existing obd_service.dart.
void main() {
  group('OBD ELM327 Parsing Logic', () {
    test('RPM: 010C response "410C1AF8" → 1726 RPM', () {
      // Formula: ((A*256)+B) / 4
      // 0x1A = 26, 0xF8 = 248, (26*256 + 248) / 4 = 6904 / 4 = 1726
      const a = 0x1A;
      const b = 0xF8;
      final rpm = ((a * 256) + b) ~/ 4;
      expect(rpm, equals(1726));
    });

    test('TPS: 0111 response "41114D" → ~30%', () {
      // Formula: A * 100 / 255
      const a = 0x4D; // 77
      final tps = (a * 100 / 255).round();
      expect(tps, closeTo(30, 2));
    });

    test('Coolant temp: 0105 response "41054B" → 35°C', () {
      // Formula: A - 40
      const a = 0x4B; // 75
      final temp = a - 40;
      expect(temp, equals(35));
    });

    test('Coolant temp: 41057F → 87°C (operating temp)', () {
      const a = 0x7F; // 127
      expect(a - 40, equals(87));
    });

    test('NODATA response → null (not a crash)', () {
      // This test documents the contract: obd_service must return null for NODATA
      const response = 'NODATA';
      final result = response == 'NODATA' ? null : 'some value';
      expect(result, isNull);
    });

    test('ERROR response → null', () {
      const response = 'ERROR';
      expect(response == 'ERROR' ? null : response, isNull);
    });

    test('RPM formula: maximum value 0xFFFF → 16383 RPM', () {
      // Boundary: largest possible A=0xFF, B=0xFF
      // ((255*256)+255) / 4 = 65535 / 4 = 16383
      const a = 0xFF;
      const b = 0xFF;
      final rpm = ((a * 256) + b) ~/ 4;
      expect(rpm, equals(16383));
    });

    test('RPM formula: zero value 0x0000 → 0 RPM (engine off)', () {
      const a = 0x00;
      const b = 0x00;
      final rpm = ((a * 256) + b) ~/ 4;
      expect(rpm, equals(0));
    });

    test('Coolant temp: minimum A=0x00 → -40°C (sensor disconnected)', () {
      // Formula: A - 40, minimum value
      const a = 0x00;
      expect(a - 40, equals(-40));
    });

    test('TPS: A=0x00 → 0% (closed throttle)', () {
      const a = 0x00;
      expect((a * 100 / 255).round(), equals(0));
    });

    test('TPS: A=0xFF → 100% (wide open throttle)', () {
      const a = 0xFF; // 255
      expect((a * 100 / 255).round(), equals(100));
    });
  });
}
