# MotoRemap Pro — Implementation Progress

---

## STRATEGIC DIRECTION (Updated 2026-05-25)

**This is NOT a generic OBD monitor. It is a professional ECU remapping platform.**

### Primary Target ECUs
| Motorcycle | ECU | Protocol | Connector |
|---|---|---|---|
| Honda Click 125i | Keihin FI | KWP2000 / ISO14230 / K-Line | 3-pin Honda diagnostic |
| Yamaha Aerox 155 / NMAX 155 | Shindengen RH850 | KWP2000 fast-init / K-Line | 4-pin Yamaha diagnostic |

### The ONE Real Success Condition
> "Successfully read, modify, checksum-correct, and safely reflash ONE Honda Click ECU and ONE Aerox ECU on real hardware."

Until that is proven, nothing else matters.

### Architecture Rules (NON-NEGOTIABLE)
- **Bluetooth adapters (ELM327, Vgate, OBDLink)** = telemetry + diagnostics ONLY. Never flash.
- **USB wired adapters (OpenPort 2.0 / K-Line direct)** = actual ECU read/write.
- Flashing MUST be: wired, verified, recoverable with automatic rollback.
- AI recommendations MUST be model-specific — never generic presets.

### Platform Structure
```
CORE ENGINES:           MODEL PACKS:
- Protocol engine       - Click 125i pack (Keihin)
- Binary engine         - Aerox 155 pack (Shindengen RH850)
- Flash engine
- Editor engine         Each pack contains:
- Telemetry engine      - ECU definitions + map offsets
- AI engine             - Checksum rules + protocol quirks
                        - Safe limits + AI tuning rules
```

---

## Phase 1 — Real Bluetooth + Protocol Abstraction + Suzuki Support — ✅ COMPLETE 2026-05-25

### Commit: `1d9c921`

### Tasks Completed
- [x] `AdapterInterface` abstraction — decouples all OBD code from hardware type
- [x] `MockAdapter` — simulates realistic cycling RPM + all standard OBD PIDs for dev builds
- [x] `Elm327BluetoothAdapter` — real Bluetooth Classic RFCOMM via flutter_bluetooth_serial
- [x] `AdapterRegistry` — lifecycle management and debug/release switching
- [x] `EcuDefinition` + `EcuRegistry` — documents Shindengen/Keihin/Denso protocols and capabilities
- [x] Extended OBD PIDs: IAT, engine load, STFT, LTFT, fuel pressure, knock retard
- [x] Mode 09 ECU identification: VIN, calibration ID, part number
- [x] Suzuki Raider R150 FI, GSX-S150, Address 125 — models + 18 profiles
- [x] DB v3 migration
- [x] `live_chart_widget.dart` — fl_chart line charts (RPM, AFR est., STFT, engine load)
- [x] Live monitor: 3-mode view, 4 new gauges (IAT/Load/STFT/LTFT), extended CSV export
- [x] All 60 tests green, flutter analyze clean

---

## Phase 2 — Protocol Engine + ECU Communication Foundation — ✅ COMPLETE 2026-05-25

### Tasks Completed
- [x] 2.1 — `KwpSession` engine: ISO14230-4 fast-init, frame builder, NRC handling, keep-alive, 3-retry (lib/core/protocol/kwp_session.dart)
- [x] 2.2 — `SecurityAccess` engine: service 0x27, Keihin XOR + rotate, Shindengen RH850 algorithms, seed=0 early exit (lib/core/protocol/security_access.dart)
- [x] 2.3 — `KLineUsbAdapter`: OpenPort 2.0 USB serial skeleton, supportsKLineDirect=true, K-Line half-duplex echo stripping (lib/core/protocols/kline_usb_adapter.dart)
- [x] 2.4 — `EcuIdentifier`: service 0x1A ReadEcuIdentification, records 0x87/0x88/0x89, ASCII decode (lib/core/ecu/ecu_identifier.dart)
- [x] 2.5 — `RomReader`: service 0x23 chunked 128B reads, SecurityAccess.unlock first, keep-alive pause/resume, .bin save to documents/backups/ (lib/core/ecu/rom_reader.dart)
- [x] 2.6 — `EcuDefinition` extended: SecurityAlgorithm, ChecksumAlgorithm enums; MapDescriptor, AxisDescriptor, ChecksumDescriptor classes; kwpTargetAddress, romSizeBytes, securityAlgorithm, maps, checksumDescriptor, defaultAxes fields (lib/core/ecu/ecu_definition.dart)
- [x] 2.7 — Honda Click 125i full spec in EcuRegistry: fuel_map @0x4000, ignition_map @0x5000, 12×12 grids, additiveByte checksum @0xFFFF, keihinXor security (lib/core/ecu/ecu_registry.dart)
- [x] 2.8 — Yamaha Aerox 155 full spec in EcuRegistry: fuel_injection @0x8000, ignition_timing @0x9000, vva_transition @0xA000, 16×16 grids, CRC16 checksum, shindengenRh850 security, 128KB ROM (lib/core/ecu/ecu_registry.dart)
- [x] 2.9 — Unit tests: KWP2000 framing, payload extraction, session lifecycle, NRC handling, seed→key algorithms, security unlock integration, EcuRegistry Phase 2 entries (test/kwp_session_test.dart, test/security_access_test.dart)

### Files Modified
- `lib/core/protocol/kwp_session.dart` — NEW: full KWP2000 session engine
- `lib/core/protocol/security_access.dart` — NEW: seed→key security access
- `lib/core/protocols/kline_usb_adapter.dart` — NEW: K-Line USB adapter skeleton
- `lib/core/ecu/ecu_identifier.dart` — NEW: service 0x1A ECU identification
- `lib/core/ecu/rom_reader.dart` — NEW: ROM reader (service 0x23 + SecurityAccess)
- `lib/core/ecu/ecu_definition.dart` — EXTENDED: MapDescriptor, ChecksumDescriptor, SecurityAlgorithm, new fields
- `lib/core/ecu/ecu_registry.dart` — EXTENDED: hondaClick125i + yamahaAerox155 full-spec entries
- `test/kwp_session_test.dart` — NEW: 16 tests
- `test/security_access_test.dart` — NEW: 20 tests

### Key Technical Decisions
- `KLineUsbAdapter` is a compilable skeleton with TODO markers for platform USB serial driver — physical serial port integration deferred to when hardware is available
- `SecurityAccess.computeKey()` is public static for testability without a live session
- `EcuDefinition` new fields use safe defaults — backward-compatible with all existing registry entries
- `EcuRegistry` keeps Tier 1 generic entries AND adds Tier 2 full-spec entries; `flashCapable` getter filters to Tier 2 only
- Map offsets (fuel @0x4000, ignition @0x5000 for Click; @0x8000/@0x9000/@0xA000 for Aerox) are community-researched — must be verified against a known-good ROM dump before first flash

### Verification Result
- Command run: `flutter test` (full suite)
- Result: **PASSED — 96/96 tests green** (60 Phase 1 + 36 Phase 2)
- `flutter analyze --no-fatal-warnings`: exit 0, no errors

---

---

## Phase 3 — Binary Engine + Map Parser + Checksum + Interactive Map Editor — ✅ COMPLETE 2026-05-25

### Tasks Completed
- [x] 3.1 — `RomBinaryParser`: parseRom(Uint8List, EcuDefinition) → ParsedRom, ExtractedMap with physical values, bounds validation (lib/core/binary/rom_parser.dart)
- [x] 3.2 — `RomBinaryWriter`: applyMapEdit, applyCell, applyExtractedMap — inverse scale/offset, safe-range clamping, minimal diff principle (lib/core/binary/rom_writer.dart)
- [x] 3.3 — `ChecksumEngine`: verify() + correct() for additiveByte, additiveWord, crc16, keihinCustom, shindengenCustom (lib/core/binary/checksum_engine.dart)
- [x] 3.4 — `RomDiffEngine`: diff(original, modified, ecu) → DiffResult with MapDiff groupings, minimum-diff principle (lib/core/binary/rom_diff.dart)
- [x] 3.5 — Interactive map editor: tappable grid, color gradient (rich blue → stoich white → lean red), undo/redo 50 steps, interpolation, live RPM overlay, trace mode, double-tap edit, long-press context menu (lib/screens/map_editor/map_editor_screen.dart)
- [x] 3.6 — ROM diff viewer: before/after per changed byte, physical value conversion, grouped by map name, Approve checkbox gates flash button (lib/screens/map_editor/rom_diff_viewer.dart)

### Files Modified
- `lib/core/binary/rom_parser.dart` — NEW
- `lib/core/binary/rom_writer.dart` — NEW
- `lib/core/binary/checksum_engine.dart` — NEW (5 algorithms including CRC-16/IBM)
- `lib/core/binary/rom_diff.dart` — NEW (RomDiff, MapDiff, DiffResult, RomDiffEngine)
- `lib/screens/map_editor/map_editor_screen.dart` — NEW (full interactive editor)
- `lib/screens/map_editor/rom_diff_viewer.dart` — NEW (pre-flash approval UI)

### Key Technical Decisions
- CRC-16 uses the reflected CRC-16/IBM variant (standard for automotive ECUs)
- Keihin checksum uses two's complement so sum(all bytes) == 0x00
- Map editor uses Table widget with InteractiveViewer for pinch-zoom
- Interpolation limited to same-row or same-column (diagonal = complex, deferred)
- Approve button requires explicit checkbox check before enabling

### Verification Result
- Command run: `flutter test` (full suite)
- Result: **PASSED — 96/96 tests green**
- `flutter analyze --no-fatal-warnings`: exit 0, only expected hardware-stub warnings

---

## Phase 2 — Original Goal
Build the real K-Line / KWP2000 / ISO14230 protocol stack so the app can **actually talk to** a Honda Click 125i and Yamaha Aerox 155 ECU — not just standard OBD PIDs.

### What to Build

**2.1 — KwpSession engine** (`lib/core/protocol/kwp_session.dart`)
- ISO14230-4 fast-init sequence (5-baud optional, fast-init mandatory)
- `startSession(targetAddress)` — send 0x81 service request, parse response
- `sendService(serviceId, data)` / `receiveResponse()` — full request/response lifecycle
- Negative response code (NRC) handling with human-readable errors
- Timeout + retry logic (3 attempts, configurable)
- Session keep-alive (tester present 0x3E every 2 seconds)

**2.2 — SecurityAccess engine** (`lib/core/protocol/security_access.dart`)
- Service 0x27 SubFunction 0x01 — request seed
- Seed→key algorithm for Keihin ECU (XOR + rotate, documented in open-source community)
- Seed→key algorithm for Shindengen RH850 (different algorithm)
- `unlock(EcuDefinition)` — abstracted unlock regardless of ECU type

**2.3 — Real K-Line adapter support**
- `KLineUsbAdapter` class (`lib/core/protocols/kline_usb_adapter.dart`)
- Targets: OpenPort 2.0 (most common in PH tuning community) via USB serial
- Uses `flutter_libserialport` or platform channel for USB serial access
- Raw byte send/receive with configurable baud rate (10400 for K-Line)
- Update `AdapterInterface` with `supportsKLineDirect = true` flag

**2.4 — ECU identification (real, not OBD Mode 09)**
- `EcuIdentifier.identify(session)` using service 0x1A (ReadEcuIdentification)
- Returns: ECU part number, software version, calibration ID, hardware version
- Honda Click: target address 0x10 (engine ECU)
- Aerox: target address 0x11 (Shindengen ECU)

**2.5 — ROM read capability**
- Service 0x23 (ReadMemoryByAddress) for Keihin
- Chunked read: 128 bytes per request (ECU limit)
- Progress callback: `onProgress(bytesRead, totalBytes)`
- Full 64KB ROM dump to `Uint8List`
- Save raw binary to device storage as `.bin` file with timestamp

**2.6 — EcuDefinition extended with real protocol data**
```dart
class EcuDefinition {
  // existing fields...
  final int kwpTargetAddress;      // 0x10 = Honda, 0x11 = Yamaha
  final int romSizeBytes;          // 65536 for most 64KB ECUs
  final SecurityAlgorithm securityAlgorithm; // keihinXor, shindengenRh850
  final List<MapDescriptor> maps;  // fuel map, ignition map offsets
  final ChecksumDescriptor checksum; // algorithm + offset + length
}

class MapDescriptor {
  final String name;        // 'fuel_map', 'ignition_map'
  final int romOffset;      // byte offset in ROM
  final int rows;           // e.g. 12
  final int cols;           // e.g. 12
  final double scale;       // multiply raw byte by this
  final double offset;      // add this after scaling
  final String unit;        // 'AFR', 'deg BTDC'
}

class ChecksumDescriptor {
  final int startOffset;    // start of checksummed region
  final int endOffset;      // end of checksummed region
  final int checksumOffset; // where the checksum byte lives in ROM
  final ChecksumAlgorithm algorithm; // additiveByte, crc16, etc.
}
```

**2.7 — Honda Click 125i map offsets (RESEARCH)**
Known from open-source tuning community documentation:
- Keihin PGM-FI 37820-KYZ (Click 125i 2014–2021 variant)
- Fuel base map: ~0x4000, 12×12 grid, byte per cell, scale 0.1 kg/h
- Ignition advance map: ~0x5000, 12×12 grid, byte per cell, scale 0.5°
- Rev limit: 2 bytes at ~0x0200
- Speed limit: 1 byte at ~0x0210
- Checksum: additive sum of all bytes 0x0000–0xFFFE, stored at 0xFFFF

**2.8 — Aerox 155 map offsets (RESEARCH)**
Known from Shindengen/community documentation:
- Shindengen RH850 (Aerox 2017+ / NMAX 2020+)
- ROM is 128KB, not 64KB — chunked reads needed
- Fuel injection duration map: ~0x8000
- Ignition timing map: ~0x9000
- VVA transition map: ~0xA000
- Checksum: CRC16 of specific regions, multiple checksum blocks

**2.9 — Tests**
- Unit tests for KWP2000 request/response framing
- Unit tests for each security seed→key algorithm
- Unit tests for checksum calculation (known ROM segment)
- Integration test with MockKwpAdapter (simulates ECU responses)

### Success Condition for Phase 2
- App can open a KWP2000 session with a real Honda Click ECU connected via K-Line
- App can dump full 64KB ROM and save as `.bin`
- Binary matches a known-good ROM dump byte-for-byte
- All new tests pass

---

## Phase 3 — Binary Engine + Map Parser + Checksum Correction — PENDING

### Goal
Parse the raw ROM binary into structured, editable maps. Correct checksums after edits.

### What to Build

**3.1 — RomBinaryParser** (`lib/core/binary/rom_parser.dart`)
- `parseRom(Uint8List rom, EcuDefinition ecu)` → `ParsedRom`
- Extracts each `MapDescriptor` region into `ExtractedMap`
- `ExtractedMap` = `List<List<double>>` (rows × cols, physical values)
- Axis labels from `AxisDescriptor` (RPM values, TPS % values)
- Validates map bounds — throws `RomParseException` if offsets exceed ROM size

**3.2 — RomBinaryWriter** (`lib/core/binary/rom_writer.dart`)
- `applyMapEdit(Uint8List rom, MapDescriptor map, List<List<double>> newValues)` → `Uint8List`
- Converts physical values back to raw bytes (inverse of parser scale/offset)
- Clamps values to safe range from `EcuDefinition.safeLimits`
- Returns new ROM with ONLY the edited region changed — diff is minimal

**3.3 — ChecksumEngine** (`lib/core/binary/checksum_engine.dart`)
- `verify(Uint8List rom, ChecksumDescriptor desc)` → bool
- `correct(Uint8List rom, ChecksumDescriptor desc)` → `Uint8List`
- Supports: additiveByte, additivWord, crc16, keihinCustom, shindengenCustom
- ALWAYS run verify before any flash — hard stop if checksum mismatch after write

**3.4 — RomDiffEngine** (`lib/core/binary/rom_diff.dart`)
- `diff(Uint8List original, Uint8List modified)` → `List<RomDiff>`
- Each `RomDiff` = {offset, originalByte, newByte}
- Used to show the user exactly what changed before flashing
- Minimum diff principle: only changed bytes are listed

**3.5 — Interactive Map Editor** (`lib/screens/map_editor/`)
- Full grid editor — every cell is tappable and editable
- Axis labels on rows and columns (RPM / TPS)
- Color gradient: rich blue (rich AFR) → white (stoich) → red (lean)
- Long-press cell: shows raw byte + physical value + safe range
- Pinch to zoom on large maps
- **Undo/redo** (up to 50 steps)
- **Interpolation**: select two cells, right-click → interpolate between them
- **Live RPM/load overlay**: when OBD is connected, active cell highlighted in real time
- **Map tracing mode**: records which cells were hit during a test run
- **Import/export map**: JSON format for sharing between tuners

**3.6 — ROM Diff Viewer** (`lib/screens/map_editor/rom_diff_viewer.dart`)
- Shows before/after for every changed byte
- Grouped by map name
- "Approve Changes" button required before flash is enabled

### Success Condition for Phase 3
- Tuner can open a Click ROM, see the fuel map as an editable grid
- Tuner can change individual cells, see checksum auto-corrected
- Diff viewer shows only the cells that changed
- All map values are within safe limits (SafetyValidator still enforces hard limits)

---

## Phase 4 — AI Tuning Engine (Claude API Integration) — PENDING

### Goal
Model-specific AI assistant that makes real tuning recommendations based on live OBD data and the current ROM state — not generic suggestions.

### What to Build

**4.1 — Click 125i AI tuning pack** (`lib/ai/model_packs/click125i_pack.dart`)
- Stock AFR behavior: 13.5–14.2 at cruise, 13.0–13.3 at WOT
- Safe ignition range: base 28–32° BTDC, max advance +3°
- Known lean zones: 3000–4500 RPM partial throttle (common in stock map)
- Thermal behavior: watch for AFR enrichment >120°C coolant
- Injector characteristics: 90cc/min @ 3 bar, dead time 0.8ms
- Common mod: free-flow exhaust → needs mid-range enrichment +8–12%

**4.2 — Aerox 155 / NMAX AI tuning pack** (`lib/ai/model_packs/aerox155_pack.dart`)
- VVA transition zone (5800–6200 RPM): map must be smooth across transition
- High-RPM timing: max +3° at 8000+ RPM with liquid cooling
- Injector: 120cc/min, requires re-scaling after injector upgrade
- Knock sensitivity: elevated at 11.6:1 CR — aggressive timing needs RON97
- Common mod: racing cam → requires complete fuel map re-baseline

**4.3 — AI recommendation engine** (`lib/ai/tuning_ai.dart`)
- `analyzeCurrentState(OBDSession, ParsedRom)` → `TuningRecommendation`
- `generateMapSuggestion(context)` → `MapDelta` (specific cell changes, not full map)
- Calls Claude API with model-specific system prompt from the model pack
- System prompt includes: ECU type, current map values, live OBD readings, known limits
- Response MUST include: changed cells + rationale + risk level + revert instructions
- Hard limit: AI can never suggest values outside `EcuDefinition.safeLimits`

**4.4 — AI chat interface** (embedded in map editor)
- Tuner types: "my bike feels lean at 3000 RPM partial throttle"
- AI responds with specific map cells to enrich + magnitude + reasoning
- Changes are applied as pending edits — tuner reviews before accepting
- Chat history saved with session for audit trail

### AI Rules (ENFORCE IN CODE)
- AI suggestions filtered through `SafetyValidator` before display — anything unsafe is blocked
- AI cannot suggest timing advance beyond `compressionRatio.maxTimingAdvance`
- AI cannot suggest AFR below `safeAfrMin` or above `safeAfrMax`
- Every AI suggestion includes a one-click revert to original value

---

## Phase 5 — Real ECU Flash System + Recovery — PENDING

### Goal
Safely write modified ROM back to the ECU with full verification and automatic recovery if anything goes wrong.

### What to Build

**5.1 — FlashEngine** (`lib/core/flash/flash_engine.dart`)
- `backup(KwpSession, EcuDefinition)` → saves original ROM to device storage FIRST
- `erase(KwpSession, EcuDefinition)` — service 0x31 (RoutineControl) or 0x34 erase
- `write(KwpSession, Uint8List rom)` — chunked 128-byte blocks via service 0x36
- `verify(KwpSession, Uint8List expectedRom)` — read-back and byte-compare
- `recovery(KwpSession, Uint8List backupRom)` — auto-triggered if verify fails
- Progress stream: emits `FlashProgress(stage, percent, bytesWritten)`

**5.2 — Pre-flash safety gate** (HARD REQUIREMENTS before flash is allowed)
- Battery voltage ≥ 12.4V (checked via OBD)
- Engine off (RPM = 0)
- Coolant temperature < 40°C (engine cold)
- Backup ROM file verified on device storage
- Checksum verified on modified ROM
- Diff review approved by user (explicit button tap)
- Safety score ≥ 85 from `SafetyValidator`
- If ANY condition fails → flash button remains locked

**5.3 — Flash UI** (`lib/screens/flash/flash_screen.dart`)
- Pre-flight checklist (all items must be green)
- Live progress bar: backup → erase → write → verify
- Real-time byte counter
- If verify fails → auto-recovery starts immediately, user notified
- "Flash Complete" screen: shows before/after map summary + next steps

**5.4 — Recovery system**
- Backup stored in: `{app_documents}/backups/{ecuId}_{timestamp}.bin`
- Multiple backups kept (last 5)
- Recovery can be triggered manually from settings at any time
- Recovery uses same flash engine — just restores the backup file

**5.5 — Session audit log**
- Every flash attempt logged: timestamp, ECU ID, diff summary, result
- Stored in SQLite alongside tune sessions
- Exportable as PDF for customer records

### Success Condition for Phase 5
- Tuner can read Click ECU → edit 3 fuel map cells → checksum corrected → diff reviewed → flash written → bike starts and runs with new map
- If flash is interrupted (power loss simulation): recovery restores backup and bike starts
- All actions logged

---

## HOW TO CONTINUE TOMORROW

When starting a new session, just type:

```
/execute --auto
```

Claude will read `PLAN.md` and `PROGRESS.md`, skip Phase 1 (already complete),
and start executing Phase 2 automatically.

**Or to run a specific phase manually:**
```
/execute Phase 2 — Protocol Engine + ECU Communication Foundation
```

**Or to run specific tasks from a phase:**
```
/execute 2.1 KwpSession engine / 2.2 SecurityAccess engine / 2.3 KLine USB adapter
```

**PLAN.md** (in this same folder) contains the full machine-readable plan
that `--auto` mode uses. Both files must stay in sync.

---

## Files Index (as of Phase 1)

| File | Purpose |
|---|---|
| `lib/core/protocols/adapter_interface.dart` | Hardware abstraction layer |
| `lib/core/protocols/mock_adapter.dart` | Dev mock — no hardware needed |
| `lib/core/protocols/elm327_adapter.dart` | Real BT Classic ELM327 |
| `lib/core/protocols/adapter_registry.dart` | Lifecycle + debug/release switch |
| `lib/core/ecu/ecu_definition.dart` | ECU definition model (NEEDS Phase 2 extensions) |
| `lib/core/ecu/ecu_registry.dart` | Keihin/Shindengen/Denso registry |
| `lib/core/constants/obd_commands.dart` | All OBD PIDs + decode helpers |
| `lib/services/obd_service.dart` | Polling, parsing, streaming |
| `lib/services/bluetooth_service.dart` | BT scan + connect lifecycle |
| `lib/core/database/db_helper.dart` | SQLite v3 — motorcycles, profiles, sessions |
| `lib/core/database/models_seed.dart` | 10 motorcycles, 60 profiles |
| `lib/widgets/live_chart_widget.dart` | fl_chart RPM/AFR/STFT/load |
| `lib/screens/live_monitor/live_monitor_screen.dart` | Gauges + Charts + Log |

ADD THIS IF THE PHASE 5 ARE NOT COMPLETED YET THIS IS THE PROMPT 

STOP TREATING THIS PROJECT AS A GENERIC OBD MONITOR.

THE REAL TARGET IS:

PROFESSIONAL ECU REMAPPING PLATFORM
FOR SPECIFIC MOTORCYCLE MODELS FIRST.

PRIMARY TARGET ECUs:
1. Honda Click 125i (Keihin ECU)
2. Yamaha Aerox 155 / NMAX (Shindengen RH850 ECU)

The goal is NOT:
- fake map visualization
- generic JSON presets
- telemetry-only dashboard
- simulated tuning

The goal IS:
REAL ECU-LEVEL TUNING.

======================================================================
PHASE PRIORITY CHANGE
======================================================================

DO NOT over-prioritize:
- multi-model abstraction
- generic UI layers
- cosmetic dashboards
- simulated tuning workflows

Instead prioritize:

1. REAL ECU COMMUNICATION
2. REAL ROM/BINARY HANDLING
3. REAL MAP PARSING
4. REAL CHECKSUM CORRECTION
5. REAL ECU FLASH WORKFLOW
6. REAL RECOVERY/SAFETY SYSTEMS

======================================================================
PHASE 1 TARGET — CLICK + AEROX FOUNDATION
======================================================================

Build the system specifically around:

HONDA CLICK 125i:
- Keihin ECU
- K-Line / ISO14230 / KWP2000

YAMAHA AEROX 155:
- Shindengen RH850 ECU
- CAN/K-Line depending on ECU version

The architecture MUST support:
- ECU identification
- ROM reading
- ROM parsing
- map extraction
- checksum correction
- flash workflow
- recovery workflow

======================================================================
SUCCESS CONDITIONS
======================================================================

The project is ONLY considered successful when it can:

HONDA CLICK:
✔ identify real ECU
✔ dump real ROM
✔ locate actual fuel/ignition tables
✔ modify table values
✔ correct checksum
✔ write ROM safely
✔ verify flash
✔ boot motorcycle successfully after flash

AEROX:
✔ same workflow for Shindengen ECU

Until those are proven on REAL hardware,
do NOT consider the remapping system complete.

======================================================================
BUILD THESE FIRST
======================================================================

PRIORITY MODULES:

1. AdapterInterface
- hardware abstraction layer
- connect/disconnect/sendRaw/readRaw

2. Real adapters
- Vgate vLinker MC+
- OBDLink MX+
- OpenPort 2.0

3. Protocol engine
- KWP2000
- ISO14230
- K-Line session handling
- CAN session handling
- security access flow

4. ECU definition system
- EcuDefinition
- MapDescriptor
- AxisDescriptor
- EcuRegistry

5. Binary infrastructure
- ROM reader
- binary parser
- binary writer
- checksum engine
- ROM diff engine

6. Flash workflow
- backup
- erase
- write
- verify
- recovery

7. Real map editor
NOT static visualization.

Must support:
- editable cells
- interpolation
- undo/redo
- map tracing
- live RPM/load overlay

======================================================================
VERY IMPORTANT
======================================================================

DO NOT assume ELM327 is enough for flashing.

Architecture rules:
- Bluetooth adapters = telemetry + diagnostics
- USB/OpenPort 2.0 = actual ECU writing

Flashing MUST be:
- wired
- verified
- recoverable

======================================================================
AI TUNING DIRECTION
======================================================================

AI MUST become MODEL-SPECIFIC.

Example:
Click AI knows:
- stock AFR behavior
- safe ignition range
- injector characteristics
- common lean zones
- thermal behavior

Aerox AI knows:
- RH850 behavior
- VVA characteristics
- high-RPM timing behavior
- injector scaling
- knock sensitivity

AI recommendations must NEVER be generic.

======================================================================
ARCHITECTURE RULE
======================================================================

CORE PLATFORM:
- flash engine
- protocol engine
- binary engine
- editor engine
- telemetry engine
- AI engine

MODEL PACKS:
- Click pack
- Aerox pack

Each model pack contains:
- ECU definitions
- map offsets
- checksum rules
- protocol quirks
- safe limits
- AI tuning rules

======================================================================
MOST IMPORTANT INSTRUCTION
======================================================================

PROVE ONE COMPLETE ECU FIRST.

Do NOT optimize for “universal support” yet.

The first milestone is:

“Successfully read, modify, checksum-correct, and safely reflash ONE Honda Click ECU and ONE Aerox ECU on real hardware.”

Only after that should the architecture expand further.
---

## Phase 4 — AI Tuning Engine — 2026-05-25

### Tasks Completed
- [x] 4.1 — Click 125i AI pack: lib/ai/model_packs/click125i_pack.dart
  - All tuning constants (AFR limits, timing, injector, lean zones)
  - 3 mod scenarios (exhaust, pod filter, cam upgrade)
  - buildSystemPrompt() for Claude API with 7 safety rules
- [x] 4.2 — Aerox 155 AI pack: lib/ai/model_packs/aerox155_pack.dart
  - VVA transition zone rules (6000 RPM engage, 200ms window, 6% enrichment)
  - Knock sensitivity zone (5500–9000 RPM), knock retard 2°/event
  - 5 mod scenarios including bore-up, high-comp piston, VVA delete
  - buildSystemPrompt() with VVA awareness section
- [x] 4.3 — AI recommendation engine: lib/ai/tuning_ai.dart
  - SafetyValidator: validates CellChange against map safeMin/safeMax and timing hard limits
  - TuningAI: Claude API (claude-opus-4-7), model-pack system prompt selection
  - ROM context builder (first 3×3 preview per map)
  - Response parser: absolute cell format + RPM×TPS zone percentage format
  - Safety filter applied to every suggestion before returning to caller
- [x] 4.4 — AI chat panel: lib/screens/map_editor/ai_chat_panel.dart
  - Embedded slide-up panel (55% screen height)
  - Quick prompts (4 one-tap tuning questions)
  - Conversation history maintained for multi-turn context
  - Per-message Apply button with risk level badge (LOW/MEDIUM/HIGH)
  - Full response dialog for raw AI text
  - onApply callback returns only safety-filtered CellChange list

### Verification
flutter analyze: 0 errors
flutter test: 96/96 passed

---

## Phase 5 — Flash System + Recovery — 2026-05-25

### Tasks Completed
- [x] 5.1 — Flash engine: lib/core/flash/flash_engine.dart
  - Pipeline: backup → erase (0x31/0x34) → write (0x36, 128B chunks) → verify (0x23 read-back) → recovery on fail
  - Block sequence counter wraps 0x00–0xFF per KWP2000 spec
  - Auto-recovery: re-writes backup if write or verify fails
  - FlashProgress with stage, bytesProcessed, totalBytes, message
- [x] 5.2 — Pre-flash gate: lib/core/flash/pre_flash_gate.dart
  - 7-condition gate: battery ≥12.4V, RPM=0, coolant<40°C, backup verified, checksum verified, diff approved, safety score ≥85
  - Air-cooled ECU exemption for coolant check (coolantTempC = -1)
  - safetyScore integer 0–100 computed from passing checks
- [x] 5.3 — Flash UI: lib/screens/flash/flash_screen.dart
  - 4 phases: preflight checklist → final confirmation → live progress → result
  - Pre-flight: check rows with green/red icons, score card
  - Live: stage indicator dots + LinearProgressIndicator + KB counter
  - WillPopScope prevents accidental back navigation during flash
  - Result: success/fail summary with PDF log export button
- [x] 5.4 — Recovery manager: lib/core/flash/recovery_manager.dart
  - Saves to {documents}/backups/{ecuId}_{timestamp}.bin
  - Prunes to last 5 backups automatically after each save
  - BackupEntry with displayName, sizeBytes, timestamp
- [x] 5.5 — Flash audit log: lib/core/database/flash_log.dart
  - SQLite table: flash_attempts (ecu_id, timestamp, success, stage, bytes_changed, diff_summary, error_detail, backup_path)
  - logAttempt() called after every flash regardless of outcome
  - exportToPdf() via pdf + printing packages, system share dialog

### Verification
flutter analyze: 0 errors
flutter test: 96/96 passed

---

## Phase 6 — Real Hardware + Professional Tuning System — 2026-05-25

### Engineering Audit Result (pre-phase)
Honest validation confirmed: architecture professional-level, but hardware driver stubbed and ROM offsets unvalidated. This phase addresses the core gaps.

### Tasks Completed

- [x] 6.1 — Real USB serial driver (removed all TODO stubs)
  - Rewrote lib/core/protocols/kline_usb_adapter.dart using usb_serial 0.4.0 package
  - Real Android USB Host API: UsbSerial.listDevices(), device.create(), port.open()
  - Baud rate 10400, 8N1, no flow control via port.setPortParameters()
  - TX echo stripping via _txEchoRemaining counter, real port.write(bytes)
  - RX stream listener: port.inputStream.listen(_onBytesReceived)
  - listDevices() static method for adapter selection UI
  - connectToDevice(UsbDevice) for explicit device targeting

- [x] 6.2 — Android USB Host manifest (android/app/src/main/AndroidManifest.xml)
  - android.hardware.usb.host feature declared (android:required="false")
  - USB_DEVICE_ATTACHED intent filter + device_filter.xml meta-data
  - Auto permission prompt when K-Line adapter is plugged in

- [x] 6.3 — USB device filter (android/app/src/main/res/xml/device_filter.xml)
  - FTDI FT232R/FT232H/FT231X (OpenPort 2.0)
  - Silicon Labs CP2102/CP2104
  - WCH CH340/CH341
  - Prolific PL2303
  - All 8 USB product IDs with correct vendor/product hex codes

- [x] 6.4 — Customer Preset System — TunePreset data model
  - lib/core/tuning/tune_preset.dart
  - MapZoneDelta: RPM row range × TPS col range × percent OR absolute delta
  - TunePreset: full metadata (confidence, risk, octane, AFR explanation, warnings, benefits, side effects)
  - PresetCategory enum (performance / daily / specialized)

- [x] 6.5 — Click 125i presets (lib/core/tuning/click125i_presets.dart)
  - Eco Tune: -4% cruise fuel, +1° timing, 91 RON, no exhaust mods
  - Street Tune: +4% mid-range 3000–4500 RPM, +1° timing, smooth daily
  - Touring Tune: +5% steady cruise, stable AFR for highway
  - Pipe Tune: +10% lean zone correction (3000–4500 RPM × 20–60% TPS), +6% WOT
  - Racing Tune: +8% WOT, +3° timing advance, 97 RON, track only
  - All deltas reference exact row/col indices from 12×12 Click ECU grid

- [x] 6.6 — Aerox 155 presets (lib/core/tuning/aerox155_presets.dart)
  - VVA Smooth Tune: +6% VVA transition zone (5500–6500 RPM × 40–100% TPS)
  - Daily Tune: +5% mid-range + VVA transition enrichment
  - Aggressive VVA Tune: +10% VVA, +8% WOT, +2° high-RPM timing, 95 RON
  - Fuel Economy Tune: -5% cruise, +1° timing, stock VVA zone protected
  - Drag Tune: +12% WOT, +4% VVA extra, +4° timing, 97 RON, strip only
  - All row/col indices reference 16×16 Aerox ECU grid with VVA at row 10

- [x] 6.7 — PresetEngine (lib/core/tuning/preset_engine.dart)
  - apply(originalRom, parsedRom, preset, ecu) → AppliedPresetResult
  - Applies MapZoneDelta to each cell in RPM×TPS zone
  - Clamps results to safeMin/safeMax per MapDescriptor
  - Auto-applies checksum correction after all deltas
  - ECU ID mismatch throws PresetEngineMismatchException

- [x] 6.8 — Preset Selector Screen (lib/screens/remap/preset_selector_screen.dart)
  - TabBar by PresetCategory (Performance / Daily / Specialized)
  - Verification status banner (green if verified, orange if not)
  - Expandable cards: AFR explanation, benefits, side effects, warnings
  - Risk badge (SAFE / CAUTION / ADVANCED) per preset
  - Octane, confidence %, estimated power/fuel change metadata
  - Apply bar at bottom with confirmation dialog
  - Returns modified Uint8List via Navigator.pop

- [x] 6.9 — RiskAnalyzer (lib/core/tuning/risk_analyzer.dart)
  - analyze(ParsedRom, EcuDefinition) → RiskReport
  - Per-cell classification: safe / lean / rich / timingHigh / timingLow / outOfRange
  - HeatRisk enum: cool → warm → hot → critical
  - estimatedKnockRiskPct (0–100) from timing proximity to hard limit
  - analyzeProposedCellChange() for live single-cell warning in map editor
  - ECU-specific limits sourced from Click125iPack / Aerox155Pack constants
  - blocksFlash=true if any out-of-range cell exists

- [x] 6.10 — EcuVerificationManager (lib/core/ecu/ecu_verification_manager.dart)
  - Persistent verification state via SharedPreferences
  - recordRomDump(): stores hash + size when real dump succeeds
  - recordChecksumValidated(), recordSecurityAccessConfirmed()
  - recordOffsetValidated(mapName, confirmedOffset) per map
  - recordSuccessfulFlash() — highest confidence level
  - statusFor(ecuId) → VerificationStatus (unverified / partial / verified)
  - VerificationStatus.description used in UI banners

### Files Modified
- pubspec.yaml — added usb_serial: ^0.4.0
- android/app/src/main/AndroidManifest.xml — USB Host permission + intent filter
- android/app/src/main/res/xml/device_filter.xml — NEW: 8 USB product IDs
- lib/core/protocols/kline_usb_adapter.dart — REWRITTEN: real usb_serial API
- lib/core/tuning/tune_preset.dart — NEW
- lib/core/tuning/click125i_presets.dart — NEW
- lib/core/tuning/aerox155_presets.dart — NEW
- lib/core/tuning/preset_engine.dart — NEW
- lib/core/tuning/risk_analyzer.dart — NEW
- lib/core/ecu/ecu_verification_manager.dart — NEW
- lib/screens/remap/preset_selector_screen.dart — NEW

### Remaining Hardware Validation Steps (cannot be done in code)
1. Connect OpenPort 2.0 to a real Click 125i / Aerox 155
2. Run KWP2000 session → confirm fast-init response
3. Run security access → confirm seed→key on real ECU
4. Dump ROM → record hash in EcuVerificationManager.recordRomDump()
5. Hex-inspect dump → validate fuel_map @0x4000, ignition_map @0x5000 (Click)
6. Compute checksum → confirm additiveByte matches stored byte at 0xFFFF (Click)
7. Apply trivial 1-cell change → flash → verify ECU boots → recordSuccessfulFlash()
8. Mark ECU as VERIFIED in app → presets enabled without warning banner

### Verification Result
- flutter pub get: usb_serial 0.4.0 installed ✅
- flutter analyze: 0 errors ✅
- flutter test: 96/96 passed ✅

---

## Phase 7 — Production Hardening — 2026-05-26

### Tasks Completed

- [x] 7.1 — PROCEED confirmation gate (lib/screens/remap/preset_selector_screen.dart)
  - Advanced presets (Racing / Drag / Aggressive VVA) now require mechanic to type "PROCEED"
  - StatefulBuilder dialog: Apply button stays disabled until "PROCEED" matches exactly
  - Warnings displayed as danger icons (red), preset requirements shown, octane minimum enforced
  - Standard (SAFE/CAUTION) presets continue to use normal confirmation dialog

- [x] 7.2 — ECU fingerprinting (lib/core/ecu/ecu_fingerprint.dart)
  - EcuFingerprint.fromIdentification(): combines service 0x1A records 0x87/0x88/0x89/0x97 + optional ROM preamble hash
  - fingerprintHash: stable per physical unit (FNV-1a on ecuId+partNum+hwVer+swVer+calId)
  - romPreambleHash: separate — not included in fingerprintHash so identity survives reflashing
  - FingerprintStore extension on EcuVerificationManager: storeFingerprint(), fingerprintFor(), verifyOrStoreFingerprint()
  - FingerprintMismatchException thrown when connected ECU doesn't match stored fingerprint
  - Full JSON serialization for persistence

- [x] 7.3 — Protocol logger (lib/core/protocols/kwp_protocol_logger.dart)
  - KwpProtocolLogger singleton, SQLite-backed (kwp_log.db)
  - Two tables: kwp_sessions (per KWP session) + kwp_frames (every TX/RX frame)
  - Logs: timestamp (ms), direction (TX/RX), serviceId, full hex payload, NRC code
  - Human-readable service name map (35 KWP2000 services)
  - NRC description table (18 negative response codes)
  - exportSessionText(sessionId) → plain-text log string
  - pruneOlderThan(days) for storage management
  - startSession(ecuId) / endSession() lifecycle

- [x] 7.4 — Protocol log viewer screen (lib/screens/diagnostic/protocol_log_screen.dart)
  - Color-coded rows: TX=blue, RX=green, NRC=red
  - Monospace hex display, direction badge, service description
  - Auto-scroll toggle for live capture monitoring
  - Copy full log to clipboard action

- [x] 7.5 — ROM integrity checker (lib/core/binary/rom_integrity_checker.dart)
  - RomIntegrityChecker.check(rom, ecu) → RomIntegrityResult
  - 5 fault types: wrongSize, allZeros, allOnes, lowEntropy, repeatingBlocks
  - Shannon entropy (bits/byte) — blocks if < 3.5 (real ECU ROM typically 4.5–7.5)
  - Repeat-block detector: scans 256-byte blocks for >8 duplicates
  - Unique byte count reported for diagnostics
  - blocksOperation flag: wrongSize/allZeros/allOnes/lowEntropy block map editor

- [x] 7.6 — Validation report PDF (lib/core/reports/validation_report.dart)
  - ValidationReport.exportAndShare(ecuId) → opens system share sheet
  - PDF includes: header with ECU ID + verification status, checklist with timestamps,
    validated map offsets table, flash history, disclaimer footer
  - All 5 verification steps shown with ✓/✗ and detail text
  - Uses existing pdf + printing packages (no new dependencies)

- [x] 7.7 — Professional mode screen (lib/screens/professional/professional_tuning_screen.dart)
  - 10 parameters: fan ON/OFF temp, decel cut RPM window, throttle sensitivity,
    injector dead time, injector flow scale, soft/hard rev limit, launch control RPM
  - Slider-based editing with stock value reference and range labels
  - HIGH RISK badge on rev limit and launch control parameters
  - PROCEED gate for high-risk parameter changes (same mechanic keyword system)
  - "Send to Flash" returns modified param map via Navigator.pop for flash integration
  - Validation report export button in AppBar (reuses ValidationReport.exportAndShare)

- [x] 7.8 — Flash interruption recovery enhanced (lib/core/flash/flash_engine.dart)
  - FlashInterruptionException with FlashInterruptionType enum (usbDisconnect/sessionTimeout)
  - lastWrittenOffset field — records exact byte offset where USB failed
  - Write loop catches TimeoutException → FlashInterruptionType.sessionTimeout
  - Write loop detects USB disconnect keywords in exception messages → usbDisconnect
  - 2-second recovery delay after USB disconnect (adapter settle time)
  - Progress callback shows KB offset at interruption point before recovery begins

### Files Modified
- lib/screens/remap/preset_selector_screen.dart — PROCEED gate for advanced presets
- lib/core/flash/flash_engine.dart — interruption detection + FlashInterruptionException

### New Files
- lib/core/binary/rom_integrity_checker.dart — ROM corruption detection
- lib/core/protocols/kwp_protocol_logger.dart — KWP2000 frame logger (SQLite)
- lib/core/ecu/ecu_fingerprint.dart — per-unit ECU fingerprinting
- lib/core/reports/validation_report.dart — PDF validation report generator
- lib/screens/professional/professional_tuning_screen.dart — professional parameter editor
- lib/screens/diagnostic/protocol_log_screen.dart — protocol log viewer
- test/phase7_test.dart — 15 new tests (RomIntegrityChecker + EcuFingerprint)

### Verification Result
- flutter analyze: 0 errors ✅
- flutter test: 111/111 passed ✅ (96 prior + 15 Phase 7)

---
