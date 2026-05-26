# MotoRemap Pro — CLAUDE.md

> Professional ECU Remapping Platform for Filipino motorcycle mechanics.
> Target bikes: Honda Click 125i (Keihin PGM-FI) · Yamaha Aerox 155 / NMAX 155 (Shindengen RH850)

---

## Quick Context

This is NOT a generic OBD monitor. It is a full ECU read/modify/flash platform — the same job that WinOLS + OpenPort 2.0 does on a laptop, but running natively on Android.

**The ONE real success condition:**
> Successfully read, modify, checksum-correct, and safely reflash ONE Honda Click ECU and ONE Aerox ECU on real hardware.

Everything else is scaffolding until that is proven.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x / Dart 3 |
| State | flutter_riverpod 2.5 |
| DB | sqflite 2.3 (SQLite) |
| Bluetooth | flutter_bluetooth_serial 0.4 |
| USB Serial | usb_serial 0.4 (FTDI/CP2102/CH340/PL2303) |
| PDF | pdf 3.11 + printing 5.12 |
| Charts | fl_chart 0.68 |
| Platform | Android API 26+ |

Run tests: `flutter test`
Analyze: `flutter analyze --no-fatal-warnings`
Build: `flutter build apk --release`

---

## Architecture Rules (NON-NEGOTIABLE)

1. **Bluetooth (ELM327/Vgate/OBDLink)** = diagnostics + telemetry ONLY. Never flash.
2. **USB wired (OpenPort 2.0 / K-Line direct)** = actual ECU read + write.
3. Flashing MUST be: wired, verified, recoverable with automatic rollback.
4. AI recommendations MUST be model-specific — never generic presets.
5. `SafetyValidator` filters ALL AI suggestions and preset deltas — cannot be bypassed.
6. `EcuVerificationManager.isVerified()` gates flash confidence display.
7. `RiskAnalyzer.blocksFlash = true` → flash prevented at UI level.
8. ROM integrity check MUST pass before map editor or flash attempt.
9. `EcuFingerprint` stored per unit — mismatch blocks preset application.
10. Advanced presets (Racing/Drag/Aggressive VVA) REQUIRE user to type `PROCEED` before applying.

---

## Phase Status (2026-05-26)

| Phase | Name | Status | Tests |
|---|---|---|---|
| 1 | Bluetooth + Protocol Abstraction + Suzuki | ✅ Complete | 60 |
| 2 | KWP2000 Protocol Engine + ECU Communication | ✅ Complete | +36 |
| 3 | Binary Engine + Map Parser + Map Editor | ✅ Complete | +0 |
| 4 | AI Integration + Tuning AI | ✅ Complete | — |
| 5 | Flash System + Recovery | ✅ Complete | — |
| 6 | Hardware + Customer Presets + Risk Analyzer | ✅ Complete | — |
| 7 | Production Hardening (PROCEED gate, fingerprint, logger, ROM integrity, PDF, Pro Mode) | ✅ Complete | 111 total |

**Next:** Hardware validation — connect real adapter, dump ROM, validate map offsets.

---

## Key Files

### Core Protocol
| File | Purpose |
|---|---|
| `lib/core/protocol/kwp_session.dart` | ISO14230-4 KWP2000 session engine |
| `lib/core/protocol/security_access.dart` | Seed→key: Keihin XOR, Shindengen RH850 |
| `lib/core/protocols/kline_usb_adapter.dart` | OpenPort 2.0 USB serial driver |
| `lib/core/protocols/kwp_protocol_logger.dart` | SQLite-backed protocol frame logger |

### ECU Layer
| File | Purpose |
|---|---|
| `lib/core/ecu/ecu_definition.dart` | MapDescriptor, ChecksumDescriptor, SecurityAlgorithm |
| `lib/core/ecu/ecu_registry.dart` | Click 125i + Aerox 155 full specs + community estimates |
| `lib/core/ecu/ecu_identifier.dart` | Service 0x1A ECU identification |
| `lib/core/ecu/rom_reader.dart` | Service 0x23 chunked ROM dump |
| `lib/core/ecu/ecu_verification_manager.dart` | 8-step hardware validation chain |
| `lib/core/ecu/ecu_fingerprint.dart` | Per-unit fingerprint from 0x87/0x88/0x89/0x97 |

### Binary Engine
| File | Purpose |
|---|---|
| `lib/core/binary/rom_parser.dart` | Parse ROM → ExtractedMap with physical values |
| `lib/core/binary/rom_writer.dart` | Apply map edits with safe-range clamping |
| `lib/core/binary/checksum_engine.dart` | additiveByte, additiveWord, CRC-16, Keihin, Shindengen |
| `lib/core/binary/rom_diff.dart` | Before/after diff grouped by map |
| `lib/core/binary/rom_integrity_checker.dart` | 5-fault detector (zeros, ones, entropy, repeating) |

### Tuning Engine
| File | Purpose |
|---|---|
| `lib/core/tuning/tune_preset.dart` | TunePreset model + SafetyValidator integration |
| `lib/core/tuning/click125i_presets.dart` | 5 Click presets (Stock → Racing) |
| `lib/core/tuning/aerox155_presets.dart` | 5 Aerox presets (Stock → Drag) |
| `lib/core/tuning/risk_analyzer.dart` | Per-cell lean/rich/timingHigh/outOfRange + blocksFlash |
| `lib/core/tuning/preset_engine.dart` | Applies preset delta to ROM binary |

### Flash System
| File | Purpose |
|---|---|
| `lib/core/flash/flash_engine.dart` | Chunked write + USB disconnect + session timeout recovery |
| `lib/core/flash/pre_flash_gate.dart` | Pre-flash checklist gate |
| `lib/core/flash/recovery_manager.dart` | Rollback + recovery on interruption |

### AI
| File | Purpose |
|---|---|
| `lib/ai/tuning_ai.dart` | Claude API integration for tuning suggestions |
| `lib/ai/model_packs/click125i_pack.dart` | Click-specific AI rules + safe limits |
| `lib/ai/model_packs/aerox155_pack.dart` | Aerox-specific AI rules + safe limits |

### Screens
| File | Purpose |
|---|---|
| `lib/screens/map_editor/map_editor_screen.dart` | Interactive 12×12/16×16 map grid |
| `lib/screens/remap/preset_selector_screen.dart` | Preset picker + PROCEED gate |
| `lib/screens/professional/professional_tuning_screen.dart` | 10-param pro mode + HIGH RISK badge |
| `lib/screens/diagnostic/protocol_log_screen.dart` | TX/RX/NRC hex viewer |
| `lib/screens/flash/flash_screen.dart` | Flash progress + recovery UI |

---

## Known Honest Limitations

These are NOT bugs — they are tracked unknowns awaiting hardware validation:

| Item | Status |
|---|---|
| Fuel map offset @0x4000 (Click) | Community estimate — unconfirmed against real dump |
| Ignition map offset @0x5000 (Click) | Community estimate — unconfirmed |
| Fuel map offset @0x8000 (Aerox) | Community estimate — unconfirmed |
| Keihin checksum algorithm | Two's complement — unconfirmed on physical ECU |
| Seed→key on real ECU | Implemented, unconfirmed |
| Actual flash | No real flash performed yet |

`EcuVerificationManager` + `EcuFingerprint` track verification state per physical unit.

---

## ECU Specs Reference

### Honda Click 125i — Keihin PGM-FI
- Protocol: KWP2000 / ISO14230 / K-Line
- Connector: 3-pin Honda diagnostic
- Target address: `0x10`
- ROM size: 64KB
- Security: XOR + rotate (Keihin)
- Fuel map: 12×12 @ `0x4000` (community)
- Ignition map: 12×12 @ `0x5000` (community)
- Checksum: additiveByte @ `0xFFFF`

### Yamaha Aerox 155 / NMAX 155 — Shindengen RH850
- Protocol: KWP2000 fast-init / K-Line
- Connector: 4-pin Yamaha diagnostic
- Target address: `0x11`
- ROM size: 128KB
- Security: Shindengen RH850 algorithm
- Fuel map: 16×16 @ `0x8000` (community)
- Ignition map: 16×16 @ `0x9000` (community)
- VVA transition map: 16×16 @ `0xA000` (community)
- Checksum: CRC-16

---

## Hardware Setup (Real Tuning)

### Minimum to read ECU
- OpenPort 2.0 USB K-Line adapter (~₱2,500–4,000)
- Android phone with USB-C OTG

### Minimum to tune safely
- OpenPort 2.0 (read/write)
- Innovate LC-2 or PLX SM-AFR wideband O2 kit (~₱4,000–8,000) — actual AFR 0–20:1
- Audio knock detector (~₱500) — amplified knock signal via headphones during test ride

### To tune professionally
- Above + dyno access (~₱500–1,500/pull) — real power curve + AFR trace under full load

**Without a wideband:** tuner is working to a mathematically correct map but cannot verify actual AFR under real load. The app makes this explicit at every step.

---

## Professional Tool Context

The PH tuning market uses:
- **Laptop + WinOLS** — binary hex editor (~$999), reads raw ROM, manual map identification
- **Woolich Racing Tuned** — model-specific flash software for Yamaha/Kawasaki/Honda sport bikes
- **Power Commander V/6** — plug-and-play piggyback fuel controller (does NOT touch ECU ROM)
- **Dynojet Autotune** — wideband + self-learning module paired with Power Commander
- **KessV2 / KESS3 / K-TAG** — OBD + bench + boot-mode chip tuning tools (automotive focus)
- **TuneECU** — open-source for Triumph/KTM/Ducati (not Click/Aerox)
- **JDiag M200 Pro** — budget diagnostic tool available on Lazada (~₱10,000)

**MotoRemap Pro is the only mobile-native tool purpose-built for Honda Click 125i and Yamaha Aerox 155 in the PH market.** Existing tools either require a laptop, are generic OBD monitors, or target sport bikes — not the scooters that dominate PH roads.

---

## Testing

```bash
# Run all tests
flutter test

# Analyze
flutter analyze --no-fatal-warnings

# Build APK
flutter build apk --release
```

Test files:
- `test/kwp_session_test.dart` — KWP2000 framing, session lifecycle, NRC handling
- `test/security_access_test.dart` — seed→key for both ECU types
- `test/safety_validator_test.dart` — SafetyValidator boundary tests
- `test/phase7_test.dart` — PROCEED gate, fingerprint, ROM integrity, validation report
- `test/afr_calculator_test.dart` — AFR/lambda calculations
- `test/obd_parser_test.dart` — OBD PID parsing

Total: **111 tests, 0 analyzer errors** as of Phase 7.

---

## Development Notes

- Map offsets are community-researched. Always dump ROM first, hex-inspect, then validate before any flash attempt.
- `MockAdapter` simulates realistic cycling OBD data — use for UI development without hardware.
- `EcuVerificationManager.recordSuccessfulFlash()` is the milestone call — only invoke after a real ECU survives reflash and boots cleanly.
- Flash engine uses 2-second delay before recovery attempt after USB disconnect (ECU recovery time).
- Protocol logger (SQLite) auto-prunes sessions older than 30 days.

---

## Next Hardware Validation Steps

1. Connect OpenPort 2.0 → KWP2000 fast-init → confirm session handshake
2. Security access → confirm seed→key on real Click ECU
3. Dump full 64KB ROM → hex-inspect → validate `0x4000` fuel map offset
4. Compute checksum → verify additiveByte algorithm matches
5. Make 1-cell fuel change → flash → boot → confirm ECU starts
6. Call `EcuVerificationManager.recordSuccessfulFlash()` → mark unit VERIFIED
7. Repeat for Aerox 155
