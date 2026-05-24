import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/utils/afr_calculator.dart';

void main() {
  group('AfrCalculator — fuelTrimPercent', () {
    test('1. Stoich target → 0.0 trim', () {
      expect(
        AfrCalculator.fuelTrimPercent(
          currentAfr: 14.7,
          targetAfr: 14.7,
        ),
        equals(0.0),
      );
    });

    test('2. Current 14.0, target 13.5 → positive trim (lean)', () {
      // ((14.0 - 13.5) / 14.0) * 100 = 3.571...
      expect(
        AfrCalculator.fuelTrimPercent(currentAfr: 14.0, targetAfr: 13.5),
        closeTo(3.571, 0.001),
      );
    });

    test('3. Current 13.0, target 13.5 → negative trim (rich)', () {
      // ((13.0 - 13.5) / 13.0) * 100 = -3.846...
      expect(
        AfrCalculator.fuelTrimPercent(currentAfr: 13.0, targetAfr: 13.5),
        closeTo(-3.846, 0.001),
      );
    });

    test('4. currentAfr = 0 → returns 0.0 (divide-by-zero protection)', () {
      expect(
        AfrCalculator.fuelTrimPercent(currentAfr: 0.0, targetAfr: 13.5),
        equals(0.0),
      );
    });
  });

  group('AfrCalculator — lambda conversions', () {
    test('5. lambdaFromAfr(14.7) → 1.0 (stoichiometric)', () {
      expect(
        AfrCalculator.lambdaFromAfr(14.7),
        closeTo(1.0, 0.0001),
      );
    });

    test('6. lambdaFromAfr(12.0) → ≈ 0.816', () {
      // 12.0 / 14.7 = 0.8163...
      expect(
        AfrCalculator.lambdaFromAfr(12.0),
        closeTo(0.816, 0.001),
      );
    });

    test('7. afrFromLambda(1.0) → 14.7', () {
      expect(
        AfrCalculator.afrFromLambda(1.0),
        closeTo(14.7, 0.0001),
      );
    });
  });

  group('AfrCalculator — estimatedAfrFromNarrowbandVoltage', () {
    test('8. voltage = 0.0 → 11.5 (full rich)', () {
      expect(
        AfrCalculator.estimatedAfrFromNarrowbandVoltage(0.0),
        equals(11.5),
      );
    });

    test('9. voltage = 1.0 → 15.5 (full lean)', () {
      // 11.5 + (1.0 * 4.0) = 15.5
      expect(
        AfrCalculator.estimatedAfrFromNarrowbandVoltage(1.0),
        equals(15.5),
      );
    });

    test('10. voltage = 0.5 → 13.5 (mid)', () {
      // 11.5 + (0.5 * 4.0) = 13.5
      expect(
        AfrCalculator.estimatedAfrFromNarrowbandVoltage(0.5),
        equals(13.5),
      );
    });

    test('11. voltage = -0.5 → 11.5 (clamped to 0.0)', () {
      expect(
        AfrCalculator.estimatedAfrFromNarrowbandVoltage(-0.5),
        equals(11.5),
      );
    });

    test('12. voltage = 1.5 → 15.5 (clamped to 1.0)', () {
      expect(
        AfrCalculator.estimatedAfrFromNarrowbandVoltage(1.5),
        equals(15.5),
      );
    });
  });

  group('AfrCalculator — isAfrDangerous', () {
    test('13. AFR 11.9, any RPM → dangerous (too rich)', () {
      expect(
        AfrCalculator.isAfrDangerous(11.9, atHighRpm: false),
        isTrue,
      );
    });

    test('14. AFR 12.1, low RPM → not dangerous', () {
      expect(
        AfrCalculator.isAfrDangerous(12.1, atHighRpm: false),
        isFalse,
      );
    });

    test('15. AFR 15.1, high RPM → dangerous (too lean at high RPM)', () {
      expect(
        AfrCalculator.isAfrDangerous(15.1, atHighRpm: true),
        isTrue,
      );
    });

    test('16. AFR 15.1, low RPM → not dangerous', () {
      expect(
        AfrCalculator.isAfrDangerous(15.1, atHighRpm: false),
        isFalse,
      );
    });
  });

  group('AfrCalculator — isAfrWarning', () {
    test('17. AFR 12.4 → warning (< 12.5)', () {
      expect(AfrCalculator.isAfrWarning(12.4), isTrue);
    });

    test('18. AFR 13.0 → no warning (within range)', () {
      expect(AfrCalculator.isAfrWarning(13.0), isFalse);
    });

    test('19. AFR 14.6 → warning (> 14.5)', () {
      expect(AfrCalculator.isAfrWarning(14.6), isTrue);
    });
  });
}
