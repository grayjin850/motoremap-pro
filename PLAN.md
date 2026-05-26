# MotoRemap Pro — Master Plan

## STATUS
- Phase 1: COMPLETE (commit 1d9c921)
- Phase 2: COMPLETE (2026-05-25)
- Phase 3: COMPLETE (2026-05-25)
- Phase 4: COMPLETE (2026-05-25)
- Phase 5: COMPLETE (2026-05-25)

---

## Phase 2 — Protocol Engine + ECU Communication Foundation

### Tasks
- [ ] 2.1 — Build `KwpSession` engine: ISO14230-4 fast-init, service request/response, NRC handling, keep-alive (lib/core/protocol/kwp_session.dart)
- [ ] 2.2 — Build `SecurityAccess` engine: service 0x27, seed→key for Keihin XOR algorithm, seed→key for Shindengen RH850 algorithm (lib/core/protocol/security_access.dart)
- [ ] 2.3 — Build `KLineUsbAdapter`: OpenPort 2.0 USB serial, 10400 baud K-Line, raw byte send/receive, supportsKLineDirect=true (lib/core/protocols/kline_usb_adapter.dart)
- [ ] 2.4 — Build `EcuIdentifier`: service 0x1A ReadEcuIdentification, Click address 0x10, Aerox address 0x11 (lib/core/ecu/ecu_identifier.dart)
- [ ] 2.5 — Build ROM reader: service 0x23 ReadMemoryByAddress, 128-byte chunks, progress callback, save .bin to device storage (lib/core/ecu/rom_reader.dart)
- [ ] 2.6 — Extend `EcuDefinition` with: kwpTargetAddress, romSizeBytes, SecurityAlgorithm, List<MapDescriptor>, ChecksumDescriptor (lib/core/ecu/ecu_definition.dart)
- [ ] 2.7 — Add Honda Click 125i map offsets to EcuRegistry: fuel map ~0x4000, ignition map ~0x5000, rev limit ~0x0200, checksum at 0xFFFF (lib/core/ecu/ecu_registry.dart)
- [ ] 2.8 — Add Aerox 155 map offsets to EcuRegistry: fuel map ~0x8000, ignition ~0x9000, VVA map ~0xA000, CRC16 checksum blocks (lib/core/ecu/ecu_registry.dart)
- [ ] 2.9 — Write unit tests: KWP2000 framing, seed→key algorithms, checksum, MockKwpAdapter integration (test/kwp_session_test.dart, test/security_access_test.dart)

### Done When
All tests in 2.9 pass. App can open real KWP2000 session with Click ECU via K-Line and dump full ROM.

---

## Phase 3 — Binary Engine + Map Parser + Checksum + Interactive Map Editor

### Tasks
- [ ] 3.1 — Build `RomBinaryParser`: parseRom(Uint8List, EcuDefinition) → ParsedRom, extract each MapDescriptor as ExtractedMap, validate bounds (lib/core/binary/rom_parser.dart)
- [ ] 3.2 — Build `RomBinaryWriter`: applyMapEdit(rom, MapDescriptor, newValues) → Uint8List, inverse scale/offset, clamp to safe limits (lib/core/binary/rom_writer.dart)
- [ ] 3.3 — Build `ChecksumEngine`: verify() and correct() for additiveByte, additiveWord, crc16, keihinCustom, shindengenCustom algorithms (lib/core/binary/checksum_engine.dart)
- [ ] 3.4 — Build `RomDiffEngine`: diff(original, modified) → List<RomDiff>, minimum-diff principle (lib/core/binary/rom_diff.dart)
- [ ] 3.5 — Build interactive map editor screen: tappable grid, color gradient (rich→stoich→lean), undo/redo 50 steps, interpolation, live RPM overlay, map trace mode (lib/screens/map_editor/)
- [ ] 3.6 — Build ROM diff viewer: before/after per changed byte, grouped by map, Approve button gates flash (lib/screens/map_editor/rom_diff_viewer.dart)

### Done When
Tuner can open a Click ROM, edit fuel map cells, checksum auto-corrects, diff viewer shows changes, all values within safe limits.

---

## Phase 4 — AI Tuning Engine (Claude API, Model-Specific)

### Tasks
- [ ] 4.1 — Build Click 125i AI pack: stock AFR behavior, safe ignition range, known lean zones, injector characteristics, common mod scenarios (lib/ai/model_packs/click125i_pack.dart)
- [ ] 4.2 — Build Aerox 155 AI pack: VVA transition zone rules, high-RPM timing limits, injector specs, knock sensitivity, cam upgrade scenarios (lib/ai/model_packs/aerox155_pack.dart)
- [ ] 4.3 — Build AI recommendation engine: analyzeCurrentState(OBDSession, ParsedRom) → TuningRecommendation, Claude API integration, SafetyValidator filter on all outputs (lib/ai/tuning_ai.dart)
- [ ] 4.4 — Build AI chat interface embedded in map editor: natural language → specific cell changes, all suggestions filtered by SafetyValidator before display (lib/screens/map_editor/ai_chat_panel.dart)

### Done When
Tuner types "lean at 3000 RPM partial throttle" and AI returns specific map cells to enrich with reasoning. SafetyValidator blocks any suggestion outside hard limits.

---

## Phase 5 — Real ECU Flash System + Recovery

### Tasks
- [ ] 5.1 — Build `FlashEngine`: backup → erase → write (chunked 128B via service 0x36) → verify (read-back compare) → recovery (auto-trigger on verify fail) (lib/core/flash/flash_engine.dart)
- [ ] 5.2 — Build pre-flash safety gate: battery ≥ 12.4V, RPM = 0, coolant < 40°C, backup verified, checksum verified, diff approved, safety score ≥ 85 — ALL must be green (lib/core/flash/pre_flash_gate.dart)
- [ ] 5.3 — Build flash UI: pre-flight checklist, live progress (backup→erase→write→verify), recovery notification, post-flash summary (lib/screens/flash/flash_screen.dart)
- [ ] 5.4 — Build recovery system: backups in {documents}/backups/{ecuId}_{timestamp}.bin, keep last 5, manual recovery from settings (lib/core/flash/recovery_manager.dart)
- [ ] 5.5 — Build session audit log: every flash attempt logged to SQLite with diff summary, result, exportable as PDF (lib/core/database/flash_log.dart)

### Done When
Click ECU read → 3 cells edited → checksum corrected → diff approved → flash written → bike boots with new map. Power-loss recovery test restores backup successfully.

---

## Architecture Constraints (enforce in every phase)

1. ELM327/Bluetooth = telemetry + diagnostics ONLY. Never flash via Bluetooth.
2. K-Line USB (OpenPort 2.0) = read + write.
3. Flashing = wired only, always backup first, always verify after.
4. AI suggestions = always filtered by SafetyValidator before display.
5. SafetyValidator hard limits are NEVER admin-overridable.
6. Model packs are separate from core platform — Click pack, Aerox pack.
7. Prove ONE ECU completely before expanding to more models.
