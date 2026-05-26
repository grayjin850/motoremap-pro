import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/protocols/adapter_interface.dart';
import 'package:motorcycle_remap_app/core/protocol/kwp_session.dart';
import 'package:motorcycle_remap_app/core/protocol/security_access.dart';
import 'package:motorcycle_remap_app/core/ecu/ecu_definition.dart';
import 'package:motorcycle_remap_app/core/ecu/ecu_registry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Minimal mock adapter for security access tests
// (Copied here to keep test files self-contained)
// ─────────────────────────────────────────────────────────────────────────────

class _MockAdapter implements AdapterInterface {
  final _ctrl = StreamController<AdapterConnectionStatus>.broadcast();
  final Map<int, Uint8List Function(Uint8List)> _handlers = {};

  void onService(int id, Uint8List Function(Uint8List) h) => _handlers[id] = h;

  @override String get adapterName => 'SecurityMock';
  @override String get adapterType => 'mock';
  @override bool get supportsKLineDirect => true;
  @override bool get supportsWrite => true;
  @override Stream<AdapterConnectionStatus> get statusStream => _ctrl.stream;
  @override AdapterConnectionStatus get connectionStatus => AdapterConnectionStatus.connected;
  @override bool get isConnected => true;
  @override Future<bool> connect(String a) async => true;
  @override Future<void> disconnect() async {}
  @override Future<String?> sendCommand(String c, {Duration timeout = const Duration(seconds: 3)}) async => null;
  @override Future<bool> setProtocol(OBDProtocol p) async => true;
  @override Future<bool> setHeader(String h) async => true;
  @override void dispose() => _ctrl.close();

  @override
  Future<Uint8List?> sendRawBytes(Uint8List bytes, {Duration timeout = const Duration(seconds: 5)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final parsed = _parseService(bytes);
    if (parsed == null) return null;
    final handler = _handlers[parsed.$1];
    if (handler == null) return _negative(parsed.$1, 0x11);
    return _wrap(handler(parsed.$2));
  }

  (int, Uint8List)? _parseService(Uint8List f) {
    if (f.length < 4) return null;
    final fmt = f[0];
    if ((fmt & 0xC0) != 0x80) return null;
    final inLen = fmt & 0x3F;
    final start = inLen > 0 ? 3 : 4;
    if (start >= f.length) return null;
    return (f[start], Uint8List.fromList(f.sublist(start + 1, f.length - 1)));
  }

  Uint8List _wrap(Uint8List p) {
    final f = <int>[p.length <= 63 ? 0x80 | p.length : 0x80, 0xF1, 0x10, ...p];
    f.add(f.fold<int>(0, (s, b) => (s + b) & 0xFF));
    return Uint8List.fromList(f);
  }

  Uint8List _negative(int sid, int nrc) => _wrap(Uint8List.fromList([0x7F, sid, nrc]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers to build a session with a successful StartCommunication
// ─────────────────────────────────────────────────────────────────────────────

Future<(KwpSession, _MockAdapter)> _buildSession({required int targetAddr}) async {
  final adapter = _MockAdapter();
  adapter.onService(
    0x81,
    (_) => Uint8List.fromList([0xC1, 0x8F, 0x6B]),
  );
  final session = KwpSession(adapter: adapter, targetAddress: targetAddr);
  await session.startSession();
  return (session, adapter);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Seed→Key algorithm unit tests (no session needed) ────────────────────

  group('SecurityAccess.computeKey — Keihin XOR', () {
    test('1. Known seed 0x1234 → expected key', () {
      // Manual: 0x1234 ^ 0x1234 = 0x0000
      //         rotate left 4 → 0x0000
      //         ^ 0x4E21 = 0x4E21
      final key = SecurityAccess.computeKey(0x1234, SecurityAlgorithm.keihinXor);
      expect(key, equals(0x4E21));
    });

    test('2. Known seed 0xABCD → expected key', () {
      // 0xABCD ^ 0x1234 = 0xB9F9
      // rotate left 4 (16-bit): ((0xB9F9 << 4) & 0xFFFF) | (0xB9F9 >> 12)
      //   = (0x9F90) | (0x000B) = 0x9F9B
      // 0x9F9B ^ 0x4E21 = 0xD1BA
      final key = SecurityAccess.computeKey(0xABCD, SecurityAlgorithm.keihinXor);
      expect(key, equals(0xD1BA));
    });

    test('3. Seed 0x0000 → key is non-zero (XOR with constant)', () {
      final key = SecurityAccess.computeKey(0x0000, SecurityAlgorithm.keihinXor);
      // 0x0000 ^ 0x1234 = 0x1234
      // rotate left 4 → 0x2341
      // ^ 0x4E21 = 0x6D60
      expect(key, equals(0x6D60));
    });

    test('4. Output is always 16-bit (no overflow)', () {
      final key = SecurityAccess.computeKey(0xFFFF, SecurityAlgorithm.keihinXor);
      expect(key, greaterThanOrEqualTo(0));
      expect(key, lessThanOrEqualTo(0xFFFF));
    });
  });

  group('SecurityAccess.computeKey — Shindengen RH850', () {
    test('5. Known seed 0x5678 → expected key', () {
      // 0x5678 ^ 0xA55A = 0xF322
      // rotate right 5: ((0xF322 >> 5) & 0x07FF) | ((0xF322 & 0x1F) << 11)
      //   = 0x0799 | (0x02 << 11) = 0x0799 | 0x1000 = 0x1799
      // ^ 0x5AA5 = 0x4D3C
      final key = SecurityAccess.computeKey(0x5678, SecurityAlgorithm.shindengenRh850);
      expect(key, equals(0x4D3C));
    });

    test('6. Different algorithm from Keihin for same seed', () {
      const seed = 0x1234;
      final keihinKey = SecurityAccess.computeKey(seed, SecurityAlgorithm.keihinXor);
      final shindKey = SecurityAccess.computeKey(seed, SecurityAlgorithm.shindengenRh850);
      expect(keihinKey, isNot(equals(shindKey)));
    });

    test('7. Output is always 16-bit', () {
      final key = SecurityAccess.computeKey(0xFFFF, SecurityAlgorithm.shindengenRh850);
      expect(key, greaterThanOrEqualTo(0));
      expect(key, lessThanOrEqualTo(0xFFFF));
    });
  });

  group('SecurityAccess.computeKey — SecurityAlgorithm.none', () {
    test('8. SecurityAlgorithm.none always returns 0', () {
      expect(SecurityAccess.computeKey(0xABCD, SecurityAlgorithm.none), equals(0));
      expect(SecurityAccess.computeKey(0x0000, SecurityAlgorithm.none), equals(0));
    });
  });

  // ── Integration tests via KwpSession + mock adapter ───────────────────────

  group('SecurityAccess.unlock — Honda Click 125i', () {
    test('9. Successful unlock: send seed request → compute key → send key', () async {
      final (session, adapter) = await _buildSession(targetAddr: 0x10);

      // ECU returns seed 0x1234
      adapter.onService(
        0x27,
        (data) {
          if (data.isNotEmpty && data[0] == 0x01) {
            // Seed request: return [0x01, seedHigh, seedLow]
            return Uint8List.fromList([0x67, 0x01, 0x12, 0x34]);
          }
          if (data.isNotEmpty && data[0] == 0x02) {
            // Key received — accept (positive response)
            return Uint8List.fromList([0x67, 0x02]);
          }
          return Uint8List.fromList([0x7F, 0x27, 0x11]);
        },
      );

      // Should complete without exception
      await expectLater(
        SecurityAccess.unlock(session, EcuRegistry.hondaClick125i),
        completes,
      );
      session.dispose();
    });

    test('10. Seed 0x0000 (already unlocked) → no key request sent', () async {
      final (session, adapter) = await _buildSession(targetAddr: 0x10);

      int keyCallCount = 0;
      adapter.onService(0x27, (data) {
        if (data.isNotEmpty && data[0] == 0x01) {
          // Return seed 0x0000 = already unlocked
          return Uint8List.fromList([0x67, 0x01, 0x00, 0x00]);
        }
        if (data.isNotEmpty && data[0] == 0x02) {
          keyCallCount++;
          return Uint8List.fromList([0x67, 0x02]);
        }
        return Uint8List.fromList([0x7F, 0x27, 0x11]);
      });

      await SecurityAccess.unlock(session, EcuRegistry.hondaClick125i);
      expect(keyCallCount, equals(0), reason: 'Key should not be sent when seed=0');
      session.dispose();
    });

    test('11. NRC 0x33 security access denied → propagates KwpNegativeResponseException', () async {
      final (session, adapter) = await _buildSession(targetAddr: 0x10);

      adapter.onService(0x27, (data) {
        if (data.isNotEmpty && data[0] == 0x01) {
          return Uint8List.fromList([0x67, 0x01, 0xBE, 0xEF]);
        }
        // Reject key with NRC 0x35 (invalid key)
        return Uint8List.fromList([0x7F, 0x27, 0x35]);
      });

      await expectLater(
        () => SecurityAccess.unlock(session, EcuRegistry.hondaClick125i),
        throwsA(isA<KwpNegativeResponseException>()),
      );
      session.dispose();
    });
  });

  group('SecurityAccess.unlock — Yamaha Aerox 155', () {
    test('12. Shindengen algorithm used for Aerox ECU', () async {
      final (session, adapter) = await _buildSession(targetAddr: 0x11);

      int? receivedKey;
      const testSeed = 0x5678; // expected key = 0x4D3C

      adapter.onService(0x27, (data) {
        if (data.isNotEmpty && data[0] == 0x01) {
          return Uint8List.fromList([
            0x67,
            0x01,
            (testSeed >> 8) & 0xFF,
            testSeed & 0xFF,
          ]);
        }
        if (data.length >= 3 && data[0] == 0x02) {
          receivedKey = (data[1] << 8) | data[2];
          return Uint8List.fromList([0x67, 0x02]);
        }
        return Uint8List.fromList([0x7F, 0x27, 0x11]);
      });

      await SecurityAccess.unlock(session, EcuRegistry.yamahaAerox155);

      // Verify the correct Shindengen key was sent for seed 0x5678
      expect(receivedKey, equals(0x4D3C));
      session.dispose();
    });
  });

  group('SecurityAccess.unlock — SecurityAlgorithm.none', () {
    test('13. Algorithm.none → completes immediately without KWP service call', () async {
      final (session, adapter) = await _buildSession(targetAddr: 0x10);

      int serviceCallCount = 0;
      adapter.onService(0x27, (data) {
        serviceCallCount++;
        return Uint8List.fromList([0x67, 0x01, 0x00, 0x00]);
      });

      // Use a generic ECU that has SecurityAlgorithm.none
      const noSecEcu = EcuDefinition(
        id: 'test_no_security',
        brand: 'Test',
        displayName: 'Test ECU',
        chipFamily: EcuChipFamily.unknown,
        primaryProtocol: OBDProtocol.auto,
        capabilities: EcuCapabilities(),
        motorcycleModelIds: [],
        securityAlgorithm: SecurityAlgorithm.none,
      );

      await SecurityAccess.unlock(session, noSecEcu);
      expect(serviceCallCount, equals(0), reason: 'No 0x27 call for SecurityAlgorithm.none');
      session.dispose();
    });
  });

  // ── EcuRegistry Phase 2 entries ───────────────────────────────────────────

  group('EcuRegistry Phase 2 entries', () {
    test('14. hondaClick125i has correct KWP address and ROM size', () {
      expect(EcuRegistry.hondaClick125i.kwpTargetAddress, equals(0x10));
      expect(EcuRegistry.hondaClick125i.romSizeBytes, equals(65536));
      expect(EcuRegistry.hondaClick125i.securityAlgorithm, equals(SecurityAlgorithm.keihinXor));
    });

    test('15. hondaClick125i has fuel_map and ignition_map descriptors', () {
      final fuelMap = EcuRegistry.hondaClick125i.mapByName('fuel_map');
      final ignMap = EcuRegistry.hondaClick125i.mapByName('ignition_map');
      expect(fuelMap, isNotNull);
      expect(ignMap, isNotNull);
      expect(fuelMap!.romOffset, equals(0x4000));
      expect(ignMap!.romOffset, equals(0x5000));
      expect(fuelMap.rows, equals(12));
      expect(fuelMap.cols, equals(12));
    });

    test('16. hondaClick125i checksum descriptor is additiveByte at 0xFFFF', () {
      final cs = EcuRegistry.hondaClick125i.checksumDescriptor;
      expect(cs, isNotNull);
      expect(cs!.algorithm, equals(ChecksumAlgorithm.additiveByte));
      expect(cs.checksumOffset, equals(0xFFFF));
    });

    test('17. yamahaAerox155 has correct KWP address and 128KB ROM', () {
      expect(EcuRegistry.yamahaAerox155.kwpTargetAddress, equals(0x11));
      expect(EcuRegistry.yamahaAerox155.romSizeBytes, equals(131072));
      expect(EcuRegistry.yamahaAerox155.securityAlgorithm, equals(SecurityAlgorithm.shindengenRh850));
    });

    test('18. yamahaAerox155 has 3 maps including vva_transition', () {
      expect(EcuRegistry.yamahaAerox155.maps.length, equals(3));
      final vva = EcuRegistry.yamahaAerox155.mapByName('vva_transition');
      expect(vva, isNotNull);
      expect(vva!.romOffset, equals(0xA000));
    });

    test('19. MapDescriptor.rawToPhysical and physicalToRaw are inverses', () {
      const map = MapDescriptor(
        name: 'test', romOffset: 0, rows: 1, cols: 1,
        scale: 0.5, offset: 0.0, unit: 'deg', safeMin: 0, safeMax: 50,
      );
      for (int raw = 0; raw <= 80; raw += 10) {
        final physical = map.rawToPhysical(raw);
        final backToRaw = map.physicalToRaw(physical);
        expect(backToRaw, equals(raw), reason: 'round-trip failed for raw=$raw');
      }
    });

    test('20. flashCapable returns only full read/write ECUs', () {
      final capable = EcuRegistry.flashCapable;
      expect(capable.every((e) => e.capabilities.romWrite), isTrue);
      // Tier 1 entries should not be in flash-capable list
      expect(capable.any((e) => e.id == 'keihin_honda_fi'), isFalse);
      expect(capable.any((e) => e.id == 'keihin_click125i_pgmfi'), isTrue);
    });
  });
}
