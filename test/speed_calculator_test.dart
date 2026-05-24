import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/utils/speed_calculator.dart';

void main() {
  group('SpeedCalculator — estimatedSpeed', () {
    test('1. rpm = 0 → 0.0 km/h', () {
      expect(SpeedCalculator.estimatedSpeed(rpm: 0), equals(0.0));
    });

    test('2. rpm = 8500 → positive, reasonable scooter speed', () {
      final speed = SpeedCalculator.estimatedSpeed(rpm: 8500);
      // Default ratios: finalDriveRatio=9.8, tireDiameterMm=550
      // wheelRpm = 8500 / 9.8 ≈ 867.3
      // circumferenceMm = 550 * pi ≈ 1727.9 mm
      // speedMmPerMin = 867.3 * 1727.9 ≈ 1,498,743
      // speedKmh = 1,498,743 * 60 / 1,000,000 ≈ 89.9 km/h
      expect(speed, greaterThan(50.0));
      expect(speed, lessThan(150.0));
    });

    test('3. rpm negative → 0.0 (treated as rpm <= 0)', () {
      expect(SpeedCalculator.estimatedSpeed(rpm: -1000), equals(0.0));
    });
  });

  group('SpeedCalculator — isApproachingRevLimit', () {
    // revLimitRpm = 8500, threshold = (8500 * 0.95).round() = 8075

    test('3. rpm = 8000 → false (8000 < 8075)', () {
      expect(SpeedCalculator.isApproachingRevLimit(8000, 8500), isFalse);
    });

    test('4. rpm = 8100 → true (8100 >= 8075)', () {
      expect(SpeedCalculator.isApproachingRevLimit(8100, 8500), isTrue);
    });

    test('5. rpm = 8500 (at limit) → true', () {
      expect(SpeedCalculator.isApproachingRevLimit(8500, 8500), isTrue);
    });

    test('6. rpm = 0 → false', () {
      expect(SpeedCalculator.isApproachingRevLimit(0, 8500), isFalse);
    });
  });
}
