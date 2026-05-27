---
name: motoremap
description: MotoRemap Pro project skill — domain knowledge, task patterns, and architecture rules for the Honda Click 125i / Aerox 155 ECU remapping platform
---

# MotoRemap Pro Project Skill

You are working on **MotoRemap Pro** — a professional Android ECU remapping app built in Flutter/Dart targeting Filipino motorcycle mechanics. The app reads, modifies, and reflashes Honda Click 125i (Keihin PGM-FI) and Yamaha Aerox 155 (Shindengen RH850) ECUs via K-Line/KWP2000 over USB.

## Domain Knowledge

### ECU Tuning Concepts
- **AFR (Air-Fuel Ratio):** Stoichiometric = 14.7:1. Rich = lower number (more fuel). Lean = higher number (less fuel).
- **Lambda:** AFR/14.7. Lambda 1.0 = stoich. Lambda < 1 = rich. Lambda > 1 = lean.
- **Fuel map:** 2D table indexed by RPM (rows) × throttle position (cols). Cells are injector pulse width targets.
- **Ignition map:** 2D table — degrees BTDC (before top dead center). Too advanced → knock. Too retarded → power loss.
- **VVA (Variable Valve Actuation):** Aerox 155 feature — transition RPM point where cam profile switches.
- **Knock:** Pre-ignition detonation. Detected by knock sensor. Causes engine damage. Always check knock when advancing timing.
- **Wideband O2:** Required to verify actual AFR. Narrowband sensors only detect rich/lean — not the ratio.
- **Dyno:** Dynamometer. Measures power at wheel under load. Only way to get real AFR trace at full throttle.

### PH Shop Reality
- Most PH mechanics tune WITHOUT a wideband — map looks correct mathematically but AFR is unverified under load.
- Wideband kit (Innovate LC-2 or PLX SM-AFR): ₱4,000–8,000
- Dyno pull: ₱500–1,500 per run
- Audio knock detector: ~₱500
- The app must ALWAYS warn when no wideband verification is possible.

### Protocol Facts
- K-Line baud rate: 10400 baud for KWP2000
- KWP2000 fast-init: pull K-Line low for 25ms, high for 25ms, then send 0x81 start session
- Keihin security: XOR + rotate (see `security_access.dart`)
- Shindengen RH850 security: different algorithm (see `security_access.dart`)
- Max chunk size for ROM read (service 0x23): 128 bytes per request

## Architecture Rules

NEVER violate these:
1. Bluetooth = diagnostics only. USB = read/write.
2. SafetyValidator must filter ALL AI and preset changes.
3. ROM integrity check before any map editor open or flash.
4. EcuFingerprint check before applying any preset.
5. Advanced presets require "PROCEED" typed by mechanic.
6. Map offsets (0x4000, 0x5000, 0x8000, 0x9000, 0xA000) are community estimates until hardware-validated.
7. Never claim flash succeeded without calling `recordSuccessfulFlash()`.
8. `blocksFlash = true` from RiskAnalyzer MUST prevent flash at UI level.

## Common Tasks & How to Approach Them

### Adding a new preset
1. Edit `lib/core/tuning/click125i_presets.dart` or `aerox155_presets.dart`
2. Use `TunePreset` constructor with explicit `confidenceScore < 1.0` until hardware-validated
3. Add `requiresProceed: true` for any Racing/Drag/Aggressive preset
4. Run `flutter test` — safety_validator_test will catch out-of-range deltas

### Adding a new ECU model
1. Add `EcuDefinition` to `lib/core/ecu/ecu_registry.dart`
2. Define `MapDescriptor` list with ROM offsets, grid dimensions, scale, unit
3. Define `ChecksumDescriptor` with algorithm + offsets
4. Add model-specific AI rules in `lib/ai/model_packs/`
5. Add presets in `lib/core/tuning/`

### Modifying the flash sequence
- Flash engine: `lib/core/flash/flash_engine.dart`
- Pre-flash gate: `lib/core/flash/pre_flash_gate.dart`
- Recovery: `lib/core/flash/recovery_manager.dart`
- Always test the interruption recovery path — simulate USB disconnect mid-write

### Working on the map editor
- `lib/screens/map_editor/map_editor_screen.dart`
- Undo/redo stack has 50-step limit — don't change without a reason
- Color gradient: rich blue ← → stoich white ← → lean red
- Interpolation: same-row or same-column only (no diagonal)

### Adding a new diagnostic screen
- Follow pattern of `lib/screens/diagnostic/protocol_log_screen.dart`
- Use `KwpProtocolLogger` for raw frame logging
- TX = blue, RX = green, NRC errors = red (established convention)

## Testing Rules

- Always run `flutter test` before claiming any task complete
- Always run `flutter analyze --no-fatal-warnings` — zero errors required
- 111 tests as of Phase 7. If count drops, investigate before proceeding.
- Test files mirror source path: `lib/core/binary/rom_parser.dart` → `test/rom_parser_test.dart`

## Build Commands

```powershell
# Android APK
flutter build apk --release

# Windows UI preview (requires Visual Studio C++ tools)
.\run_windows.ps1
```

**APK build note:** `flutter_bluetooth_serial-0.4.0` and `usb_serial-0.4.0` in the pub cache have been manually patched for AGP 9 + Kotlin 2.x compatibility. If pub cache is cleared or packages are upgraded, re-apply patches documented in CLAUDE.md → "Known Build Fixes".

## Key Decisions Already Made (Don't Revisit)

| Decision | Rationale |
|---|---|
| USB only for flash | Safety — Bluetooth can drop mid-write, bricking ECU |
| PROCEED keyword gate | Prevents accidental aggressive preset application |
| 50-step undo in map editor | Memory vs usability tradeoff — 50 is sufficient |
| CRC-16/IBM variant | Standard for automotive ECUs |
| Keihin checksum: two's complement | sum(all bytes) == 0x00 |
| MockAdapter for dev | Real hardware not always available — mock gives deterministic behavior |
| confidenceScore < 1.0 for all presets | Honest about unverified offsets |

## Remapping Workflow (App → Real Hardware)

```
1. Select bike model → EcuRegistry loads definition
2. Connect OpenPort 2.0 via USB OTG
3. KwpSession.startSession() → KWP2000 fast-init
4. SecurityAccess.unlock() → seed→key exchange
5. EcuIdentifier.identify() → read ECU part number
6. EcuFingerprint.fromIdentification() → store fingerprint
7. RomReader.readRom() → 64KB/128KB dump in chunks
8. RomIntegrityChecker.check() → must pass (5 fault types)
9. RomBinaryParser.parseRom() → ExtractedMap with physical values
10. [Mechanic edits map OR applies preset]
11. RiskAnalyzer.analyze() → blocksFlash check
12. RomBinaryWriter.applyMapEdit() → modified binary
13. ChecksumEngine.correct() → checksum recomputed
14. RomDiffEngine.diff() → mechanic reviews before/after
15. FlashEngine.flash() → chunked write with recovery
16. ECU restart → verify boot → recordSuccessfulFlash()
```

## What "Professional Tools" Do (Context for AI Suggestions)

| Tool | Type | Used For |
|---|---|---|
| WinOLS | Laptop software (~$999) | Binary ROM hex editing, map identification |
| Woolich Racing Tuned | Laptop software (free) | Direct ECU flash for Yamaha/Kawasaki/Honda sport bikes |
| Power Commander V/6 | Piggyback hardware | Fuel trim without touching ECU ROM |
| Dynojet Autotune | Wideband + self-learn module | Auto-corrects Power Commander map from real AFR |
| KessV2 / KESS3 | OBD/bench/boot hardware | Read/write ECU files (automotive focus) |
| TuneECU | Open-source laptop | Triumph/KTM/Ducati (not Click/Aerox) |
| Innovate LC-2 | Wideband O2 controller | Real AFR measurement ±0.1:1 accuracy |

**MotoRemap Pro fills the gap:** no laptop needed, purpose-built for Click/Aerox, runs on the Android phone mechanics already carry.
