import 'dart:typed_data';
import '../ecu/ecu_definition.dart';
import 'kwp_session.dart';

class SecurityAccessException implements Exception {
  final String message;
  const SecurityAccessException(this.message);
  @override
  String toString() => 'SecurityAccessException: $message';
}

/// KWP2000 security access handler for ECU unlock via service 0x27.
///
/// Implements the two-step challenge/response:
///   1. Request seed (subfunction 0x01) → ECU returns a random seed value
///   2. Compute key from seed using ECU-specific algorithm
///   3. Send key (subfunction 0x02) → ECU unlocks if key matches
///
/// Algorithms implemented:
/// - [SecurityAlgorithm.keihinXor]       — Honda Keihin FI (XOR + rotate)
/// - [SecurityAlgorithm.shindengenRh850] — Yamaha Shindengen RH850
class SecurityAccess {
  SecurityAccess._();

  static const int _subFnRequestSeed = 0x01;
  static const int _subFnSendKey = 0x02;
  static const int _service = 0x27;

  /// Unlock the ECU using the security access algorithm defined in [ecu].
  ///
  /// No-ops if [ecu.securityAlgorithm] == [SecurityAlgorithm.none].
  /// Throws [SecurityAccessException] if the ECU rejects the key.
  /// Throws [KwpNegativeResponseException] on NRC responses (e.g. 0x33 denied).
  static Future<void> unlock(KwpSession session, EcuDefinition ecu) async {
    if (ecu.securityAlgorithm == SecurityAlgorithm.none) return;

    // Step 1: Request seed
    final seedResponse = await session.sendService(
      _service,
      Uint8List.fromList([_subFnRequestSeed]),
    );

    // Positive response: [0x01, seedHigh, seedLow] (subfunction echo + 2 seed bytes)
    if (seedResponse.length < 3 || seedResponse[0] != _subFnRequestSeed) {
      throw SecurityAccessException(
        'Unexpected seed response (length=${seedResponse.length})',
      );
    }

    final seed = (seedResponse[1] << 8) | seedResponse[2];

    // Seed 0x0000 means the ECU is already unlocked — nothing more to do
    if (seed == 0x0000) return;

    // Step 2: Compute key from seed
    final key = computeKey(seed, ecu.securityAlgorithm);

    // Step 3: Send key
    await session.sendService(
      _service,
      Uint8List.fromList([
        _subFnSendKey,
        (key >> 8) & 0xFF,
        key & 0xFF,
      ]),
    );
    // No exception thrown = ECU accepted the key
  }

  /// Compute the security key from a seed value using the given algorithm.
  ///
  /// Exposed publicly for unit testing without requiring a live KWP session.
  static int computeKey(int seed, SecurityAlgorithm algorithm) {
    return switch (algorithm) {
      SecurityAlgorithm.keihinXor => _keihinXorKey(seed),
      SecurityAlgorithm.shindengenRh850 => _shindengenKey(seed),
      SecurityAlgorithm.none => 0,
    };
  }

  /// Honda Keihin FI seed→key algorithm.
  ///
  /// Based on the documented Keihin PGM-FI pattern from open-source tuning
  /// community research. Algorithm: XOR with magic constant, rotate 16-bit
  /// value left by 4 positions, XOR with second magic constant.
  static int _keihinXorKey(int seed) {
    int key = seed ^ 0x1234;
    // Rotate left by 4 (16-bit)
    key = ((key << 4) & 0xFFFF) | (key >> 12);
    key = key ^ 0x4E21;
    return key & 0xFFFF;
  }

  /// Yamaha Shindengen RH850 seed→key algorithm.
  ///
  /// Different XOR constants and rotation direction from the Keihin variant.
  static int _shindengenKey(int seed) {
    int key = seed ^ 0xA55A;
    // Rotate right by 5 (16-bit)
    key = ((key >> 5) & 0x07FF) | ((key & 0x1F) << 11);
    key = key ^ 0x5AA5;
    return key & 0xFFFF;
  }
}
