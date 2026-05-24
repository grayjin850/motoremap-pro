# Phase 3B — Pre-Remap + Tune Profiles + Map Viewer Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 5 stub screens (pre_remap_screen, fault_code_screen, tune_profiles_screen, fuel_map_screen, ignition_map_screen) with full implementations and introduce a shared map_viewer_screen.dart base widget.

**Architecture:** pre_remap_screen holds all pre-remap checker state as a StatefulWidget (no Riverpod needed — local UI state only). tune_profiles_screen is a ConsumerStatefulWidget that loads profiles from the DB. map_viewer_screen.dart is a new shared base (ConsumerStatefulWidget) consumed by thin wrappers in fuel_map_screen and ignition_map_screen. Safety gates rely entirely on SafetyValidator — no client-side overrides possible.

**Tech Stack:** Flutter 3 / Dart 3, flutter_riverpod 2.5, google_fonts, sqflite via DbHelper, pdf via PdfGenerator, SafetyValidator, FuelMap/TuneProfile models.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/screens/pre_remap/pre_remap_screen.dart` | Modify (replace stub) | OBD scan section, 7-item engine checklist, backup confirmation, live safety score, gated CTA |
| `lib/screens/pre_remap/fault_code_screen.dart` | Modify (replace stub) | DTC detail list with static mock data |
| `lib/screens/tune_profiles/tune_profiles_screen.dart` | Modify (replace stub) | Profile card PageView, VVA dialog, tune safety score per card, CTA buttons |
| `lib/screens/fuel_map/map_viewer_screen.dart` | Create (new file) | Shared 12×12 grid viewer, toggle row, cell color logic, FAB export |
| `lib/screens/fuel_map/fuel_map_screen.dart` | Modify (thin wrapper) | Routes to MapViewerScreen(mapType: MapType.fuel) |
| `lib/screens/ignition_map/ignition_map_screen.dart` | Modify (thin wrapper) | Routes to MapViewerScreen(mapType: MapType.ignition) |

---

## Task 1: PreRemapScreen — full implementation

**Files:**
- Modify: `lib/screens/pre_remap/pre_remap_screen.dart`

### Context you need

- `SafetyValidator.calculatePreRemapScore({activeFaultCodeCount, engineWarmedUp, uncheckedChecklistItems, backupConfirmed})` → `SafetyValidationResult`
- `SafetyValidationResult.score` (int 0–100), `.level` (SafetyLevel enum: hardLock/warning/approved)
- `SafetyLevel.hardLock` → score < 70; `SafetyLevel.warning` → 70–84; `SafetyLevel.approved` → ≥ 85
- `SafetyScore.labelFromScore(score)` → `'LIGTAS'` / `'BABALA'` / `'BLOCKED'`
- `SafetyScore.iconFromScore(score)` → `'🟢'` / `'🟡'` / `'🔴'`
- `AppColors`: background `0xFF0D0D0D`, surface `0xFF1A1A1A`, panel `0xFF242424`, primary `0xFFFF6B00`, safe `0xFF00CC44`, warning `0xFFFFB800`, danger `0xFFFF2D2D`, textPrimary white, textSecondary `0xFFAAAAAA`, cardBorder `0xFF333333`
- Navigation: `Navigator.pushNamed(context, '/tune-profiles')`
- No Riverpod needed — all state is local `setState`

### State variables

```dart
int _faultCodeCount = 0;
bool _scanDone = false;
bool _scanning = false;

// 7 checklist items — index 0 is "engine warmed up"
final List<bool> _checklist = List.filled(7, false);

bool _backupConfirmed = false;
final _backupFilenameController = TextEditingController();
final _backupLocationController = TextEditingController();
```

### Derived values

```dart
bool get _engineWarmedUp => _checklist[0];
int get _uncheckedItems => _checklist.where((v) => !v).length;

SafetyValidationResult get _safetyResult =>
    SafetyValidator.calculatePreRemapScore(
      activeFaultCodeCount: _faultCodeCount,
      engineWarmedUp: _engineWarmedUp,
      uncheckedChecklistItems: _uncheckedItems,
      backupConfirmed: _backupConfirmed,
    );

bool get _canProceed =>
    _safetyResult.level != SafetyLevel.hardLock && _backupConfirmed;
```

- [ ] **Step 1: Write the full PreRemapScreen file**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/safety/safety_validator.dart';
import '../../core/safety/safety_score.dart';

class PreRemapScreen extends StatefulWidget {
  const PreRemapScreen({super.key});

  @override
  State<PreRemapScreen> createState() => _PreRemapScreenState();
}

class _PreRemapScreenState extends State<PreRemapScreen> {
  int _faultCodeCount = 0;
  bool _scanDone = false;
  bool _scanning = false;

  final List<bool> _checklist = List.filled(7, false);

  bool _backupConfirmed = false;
  final _backupFilenameController = TextEditingController();
  final _backupLocationController = TextEditingController();

  static const List<String> _checklistLabels = [
    'Na-warm up na ang engine (70°C+)',
    'Nakumpirma ang fuel grade (RON 95 minimum)',
    'Na-check ang kondisyon ng spark plug',
    'Na-check ang kondisyon ng air filter',
    'Walang kakaibang tunog / knocking',
    'Sapat ang baterya (12.4V+)',
    'Lahat ng koneksyon ay secure',
  ];

  @override
  void dispose() {
    _backupFilenameController.dispose();
    _backupLocationController.dispose();
    super.dispose();
  }

  bool get _engineWarmedUp => _checklist[0];
  int get _uncheckedItems => _checklist.where((v) => !v).length;

  SafetyValidationResult get _safetyResult =>
      SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: _faultCodeCount,
        engineWarmedUp: _engineWarmedUp,
        uncheckedChecklistItems: _uncheckedItems,
        backupConfirmed: _backupConfirmed,
      );

  bool get _canProceed =>
      _safetyResult.level != SafetyLevel.hardLock && _backupConfirmed;

  Future<void> _simulateScan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _scanning = false;
        _scanDone = true;
      });
    }
  }

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.safe;
    if (score >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.rajdhani(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildObdSection() {
    Widget trafficLight;
    if (!_scanDone) {
      trafficLight = const SizedBox.shrink();
    } else if (_faultCodeCount == 0) {
      trafficLight = _statusBadge(
        '🟢  Walang fault codes — ligtas magpatuloy',
        AppColors.safe,
      );
    } else if (_faultCodeCount < 3) {
      trafficLight = _statusBadge(
        '🟡  $_faultCodeCount minor code(s) — i-check muna',
        AppColors.warning,
      );
    } else {
      trafficLight = _statusBadge(
        '🔴  KRITIKAL na codes — HUWAG mag-remap hanggang hindi naaayos',
        AppColors.danger,
      );
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('A — OBD PRE-SCAN'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _simulateScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(_scanning ? 'Nag-i-scan...' : 'I-scan ang Fault Codes'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ilang active fault codes?',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _faultCodeCount.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 0;
                    setState(() => _faultCodeCount = n.clamp(0, 10));
                  },
                ),
              ),
            ],
          ),
          if (_scanDone) ...[
            const SizedBox(height: 12),
            trafficLight,
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/fault-codes'),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Tingnan ang DTC List'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChecklistSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('B — ENGINE CHECKLIST'),
          ...List.generate(_checklistLabels.length, (i) {
            return CheckboxListTile(
              value: _checklist[i],
              onChanged: (v) =>
                  setState(() => _checklist[i] = v ?? false),
              title: Text(
                _checklistLabels[i],
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBackupSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('C — STOCK BACKUP CONFIRMATION'),
          CheckboxListTile(
            value: _backupConfirmed,
            onChanged: (v) =>
                setState(() => _backupConfirmed = v ?? false),
            title: Text(
              'Na-backup na ang stock BIN file sa laptop',
              style: GoogleFonts.inter(
                color: _backupConfirmed
                    ? AppColors.safe
                    : AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.safe,
          ),
          if (!_backupConfirmed)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '⛔ HARD BLOCK — Hindi maaaring magpatuloy nang walang backup.',
                style: GoogleFonts.inter(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _backupFilenameController,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: 'Filename ng backup',
              hintText: 'hal. stock_nmax155_2023.bin',
              labelStyle: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12),
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _backupLocationController,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: 'Location ng backup',
              hintText: 'hal. D:/Backups/2025/',
              labelStyle: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12),
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection() {
    final result = _safetyResult;
    final score = result.score;
    final color = _scoreColor(score);
    final label = SafetyScore.labelFromScore(score);
    final icon = SafetyScore.iconFromScore(score);

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('D — PRE-REMAP SAFETY SCORE'),
          Row(
            children: [
              Text(
                '$icon  PRE-REMAP SCORE: ',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$score/100',
                style: GoogleFonts.rajdhani(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: AppColors.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        w.isBlocking
                            ? Icons.cancel_outlined
                            : Icons.warning_amber_outlined,
                        size: 14,
                        color: w.isBlocking
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w.message,
                          style: GoogleFonts.inter(
                            color: w.isBlocking
                                ? AppColors.danger
                                : AppColors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canProceed
                  ? () => Navigator.pushNamed(context, '/tune-profiles')
                  : null,
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('I-GENERATE ang Reference Sheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canProceed ? AppColors.primary : AppColors.cardBorder,
                foregroundColor: _canProceed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (!_canProceed) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Hindi pwede — ayusin muna ang mga isyu sa itaas',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Pre-Remap Checker',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suriin muna ang kondisyon ng motorsiklo bago mag-tune.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildObdSection(),
            _buildChecklistSection(),
            _buildBackupSection(),
            _buildScoreSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify flutter analyze passes on this file**

```
flutter analyze lib/screens/pre_remap/pre_remap_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Run all tests to ensure nothing broke**

```
flutter test
```

Expected: 58 tests pass.

---

## Task 2: FaultCodeScreen — DTC list

**Files:**
- Modify: `lib/screens/pre_remap/fault_code_screen.dart`

### Context you need

This is a simple informational screen with a static list of mock DTC codes. No DB access needed.

- [ ] **Step 1: Write the full FaultCodeScreen file**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

enum _DtcSeverity { minor, critical }

class _DtcCode {
  final String code;
  final String description;
  final _DtcSeverity severity;

  const _DtcCode({
    required this.code,
    required this.description,
    required this.severity,
  });
}

class FaultCodeScreen extends StatelessWidget {
  const FaultCodeScreen({super.key});

  static const List<_DtcCode> _codes = [
    _DtcCode(
      code: 'P0107',
      description: 'MAP Sensor Circuit Low Input — Malamang may punit na wire o maruming sensor.',
      severity: _DtcSeverity.minor,
    ),
    _DtcCode(
      code: 'P0171',
      description: 'System Too Lean (Bank 1) — Masyadong payat ang halo; suriin ang injector at fuel pressure.',
      severity: _DtcSeverity.minor,
    ),
    _DtcCode(
      code: 'P0302',
      description: 'Cylinder 2 Misfire Detected — Suriin ang spark plug at ignition coil ng cylinder 2.',
      severity: _DtcSeverity.critical,
    ),
    _DtcCode(
      code: 'P0420',
      description: 'Catalyst System Efficiency Below Threshold — Malamang ay naubos na ang catalytic converter.',
      severity: _DtcSeverity.minor,
    ),
    _DtcCode(
      code: 'P0505',
      description: 'Idle Control System Malfunction — Suriin ang idle air control valve at throttle body.',
      severity: _DtcSeverity.minor,
    ),
    _DtcCode(
      code: 'P0562',
      description: 'System Voltage Low — Mababa ang baterya o may problema sa charging system.',
      severity: _DtcSeverity.critical,
    ),
    _DtcCode(
      code: 'C1155',
      description: 'Wheel Speed Sensor (FR) Circuit Open — Naputol o hindi maayos ang koneksyon ng wheel sensor.',
      severity: _DtcSeverity.minor,
    ),
    _DtcCode(
      code: 'U0001',
      description: 'High Speed CAN Communication Bus — Hindi nakaka-communicate ang ECU sa ibang modules.',
      severity: _DtcSeverity.critical,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Fault Codes',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _codes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final dtc = _codes[i];
                final isCritical = dtc.severity == _DtcSeverity.critical;
                final color = isCritical ? AppColors.danger : AppColors.warning;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dtc.code,
                          style: GoogleFonts.rajdhani(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dtc.description,
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isCritical
                                      ? Icons.report_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 13,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCritical ? 'KRITIKAL' : 'Minor',
                                  style: GoogleFonts.inter(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Bumalik'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add '/fault-codes' route to app.dart**

Open `lib/app.dart`. Add import at top:
```dart
import 'screens/pre_remap/fault_code_screen.dart';
```

Add route in the `routes` map after `'/pre-remap'`:
```dart
'/fault-codes': (_) => const FaultCodeScreen(),
```

- [ ] **Step 3: Verify analyze and tests**

```
flutter analyze lib/screens/pre_remap/fault_code_screen.dart lib/app.dart
flutter test
```

Expected: No errors, 58 tests pass.

---

## Task 3: TuneProfilesScreen — full implementation

**Files:**
- Modify: `lib/screens/tune_profiles/tune_profiles_screen.dart`

### Context you need

- `DbHelper.getProfilesByModelId(String motorcycleModelId)` → `Future<List<TuneProfile>>` ordered by safety_score DESC
- `TuneProfile` fields: `type` (ProfileType enum), `nameTaglish`, `descriptionTaglish`, `afrTargetMid`, `afrTargetWot`, `timingAdvanceDeg`, `revLimitRaise`, `removeSpeedLimiter`, `safetyScore`, `expectedBenefits`, `fuelConsumptionNote`
- `ProfileType` enum: `topSpeed`, `cityResponse`, `handling`, `balanced`, `eco`
- `SafetyValidator.calculateTuneSafetyScore({model, profile, backupConfirmed})` → `SafetyValidationResult`
- `SafetyValidator.requiresVvaWarning({model, profile})` → `bool`
- `MotorcycleModel` is passed via route arguments: `ModalRoute.of(context)!.settings.arguments as MotorcycleModel?`
- `SafetyScore.labelFromScore(score)`, `SafetyScore.iconFromScore(score)`
- `AppColors` — same as Task 1

### State variables

```dart
MotorcycleModel? _model;
List<TuneProfile> _profiles = [];
bool _loading = true;
int _selectedIndex = 0;
bool _backupConfirmed = true; // assume pre-remap screen confirmed it
PageController _pageController = PageController();
```

### Profile icons

```dart
String _iconFor(ProfileType type) => switch (type) {
  ProfileType.topSpeed => '🏎️',
  ProfileType.cityResponse => '🏙️',
  ProfileType.handling => '🛣️',
  ProfileType.balanced => '⚖️',
  ProfileType.eco => '🌿',
};
```

- [ ] **Step 1: Write the full TuneProfilesScreen file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/safety/safety_score.dart';
import '../../core/safety/safety_validator.dart';
import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';

class TuneProfilesScreen extends ConsumerStatefulWidget {
  const TuneProfilesScreen({super.key});

  @override
  ConsumerState<TuneProfilesScreen> createState() =>
      _TuneProfilesScreenState();
}

class _TuneProfilesScreenState extends ConsumerState<TuneProfilesScreen> {
  MotorcycleModel? _model;
  List<TuneProfile> _profiles = [];
  bool _loading = true;
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is MotorcycleModel) {
        _model = args;
        _loadProfiles(_model!.id);
      } else {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles(String modelId) async {
    try {
      final profiles = await DbHelper.getProfilesByModelId(modelId);
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _iconFor(ProfileType type) => switch (type) {
        ProfileType.topSpeed => '🏎️',
        ProfileType.cityResponse => '🏙️',
        ProfileType.handling => '🛣️',
        ProfileType.balanced => '⚖️',
        ProfileType.eco => '🌿',
      };

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.safe;
    if (score >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  void _onSelectProfile(int index) {
    final profile = _profiles[index];
    final model = _model;
    if (model == null) return;

    final needsVvaWarning =
        SafetyValidator.requiresVvaWarning(model: model, profile: profile);

    if (needsVvaWarning) {
      _showVvaWarning(profile);
    }
  }

  void _showVvaWarning(TuneProfile profile) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.warning),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            Text(
              'VVA ZONE WARNING',
              style: GoogleFonts.rajdhani(
                color: AppColors.warning,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Ang motorsiklong ito ay may VVA (Variable Valve Actuation) '
          'na nagbabago ng kampo sa paligid ng ${_model?.vvaTransitionRpm ?? 6000} RPM.\n\n'
          'Ang timing advance na ${profile.timingAdvanceDeg}° (higit sa 1°) ay '
          'nangangailangan ng espesyal na pag-iingat sa 5800–6200 RPM zone.\n\n'
          'Siguraduhing malapit na bantayan ang engine habang nire-remap.',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Naiintindihan ko — Magpatuloy',
              style: GoogleFonts.inter(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(TuneProfile profile, int index) {
    final model = _model;
    final SafetyValidationResult tuneSafety = model != null
        ? SafetyValidator.calculateTuneSafetyScore(
            model: model,
            profile: profile,
            backupConfirmed: true,
          )
        : SafetyValidationResult(
            score: profile.safetyScore,
            level: SafetyScore.levelFromScore(profile.safetyScore),
            warnings: const [],
            vvaZoneWarningRequired: false,
            backupRequired: false,
          );

    final score = tuneSafety.score;
    final scoreColor = _scoreColor(score);
    final isSelected = index == _selectedIndex;

    final proposedRevLimit = (model?.stockRevLimitHard ?? 0) + profile.revLimitRaise;
    final revLimitText = profile.revLimitRaise > 0
        ? '+${profile.revLimitRaise} RPM ($proposedRevLimit RPM)'
        : 'Stock';

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _onSelectProfile(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.panel.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Text(
                    _iconFor(profile.type),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nameTaglish.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          profile.descriptionTaglish,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20),
                ],
              ),
            ),

            // Specs
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _specRow('AFR Target',
                      '${profile.afrTargetMid} mid / ${profile.afrTargetWot} WOT'),
                  _specRow('Timing',
                      '+${profile.timingAdvanceDeg}° sa lahat ng RPM range'),
                  _specRow('Rev Limit', revLimitText),
                  _specRow(
                    'Speed Limiter',
                    profile.removeSpeedLimiter ? 'Tinanggal' : 'Stock',
                  ),
                  const Divider(color: AppColors.cardBorder, height: 20),
                  _specRow('Inaasahang Benepisyo', profile.expectedBenefits),
                  _specRow('Gasolina', profile.fuelConsumptionNote),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Tune Safety Score: ',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${SafetyScore.iconFromScore(score)} $score/100 — '
                        '${SafetyScore.labelFromScore(score)}',
                        style: GoogleFonts.rajdhani(
                          color: scoreColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButtons() {
    if (_profiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/fuel-map'),
              icon: const Icon(Icons.grid_on, size: 18),
              label: const Text('I-VIEW ang Fuel Map Reference'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/ignition-map'),
              icon: const Icon(Icons.flash_on_outlined, size: 18),
              label: const Text('I-VIEW ang Ignition Map Reference'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelName = _model != null
        ? '${_model!.brand} ${_model!.model} ${_model!.variant}'
        : 'Pumili ng Profile';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pumili ng Remap Profile',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              modelName,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _profiles.isEmpty
              ? Center(
                  child: Text(
                    _model == null
                        ? 'Walang napiling motorsiklo.\nBumalik at pumili ng modelo.'
                        : 'Walang mga profile para sa modelong ito.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'I-swipe para makita ang mga profile. I-tap para piliin.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _profiles.length,
                        onPageChanged: (i) {
                          setState(() => _selectedIndex = i);
                        },
                        itemBuilder: (context, i) =>
                            _buildProfileCard(_profiles[i], i),
                      ),
                    ),
                    // Dots indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _profiles.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _selectedIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _selectedIndex
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildCtaButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze and tests**

```
flutter analyze lib/screens/tune_profiles/tune_profiles_screen.dart
flutter test
```

Expected: No errors, 58 tests pass.

---

## Task 4: MapViewerScreen — new shared base widget

**Files:**
- Create: `lib/screens/fuel_map/map_viewer_screen.dart`

### Context you need

- `FuelMap.rpmAxis` → `List<int>` length 12: [1000..12000]
- `FuelMap.tpsAxis` → `List<int>` length 12: [0,10,20...100]
- `FuelMap.getCellStatus(tpsIndex, rpmIndex)` → `CellStatus` enum: safe/caution/danger/vvaZone
- `CellStatus.safe` → `AppColors.safe`; `.caution` → `AppColors.warning`; `.danger` → `AppColors.danger`; `.vvaZone` → `AppColors.vvaZone`
- `TuneProfile.fuelMap` → `List<List<double>>` [tpsIndex][rpmIndex]
- `TuneProfile.ignitionMap` → `List<List<double>>` [tpsIndex][rpmIndex]
- `PdfGenerator.generateTechnicalReport({session, model, profile})` needs a SessionLog — for the FAB, just show a snackbar "PDF export kailangan ng session data." if no session is available
- Route arguments: the active `TuneProfile` is passed via `ModalRoute.of(context)?.settings.arguments as TuneProfile?`
- `MotorcycleModel` is not directly passed; for VVA zone detection use `profile.ignitionMap` values to find cells > 38°

### MapType enum and view toggle

```dart
enum MapType { fuel, ignition }
enum _ViewMode { target, safeRange, dangerZone }
```

- `target`: show profile values, color-code by getCellStatus
- `safeRange`: show neutral grid overlay (light color borders)  
- `dangerZone`: cells with value > 38° (ignition) or outside 12.8–13.8 (fuel) shown in AppColors.danger

### Cell color logic (fuel map)

```dart
Color _fuelCellColor(double afr, _ViewMode mode) {
  if (mode == _ViewMode.dangerZone) {
    return (afr < 12.8 || afr > 13.8) ? AppColors.danger.withValues(alpha: 0.7) : AppColors.safe.withValues(alpha: 0.18);
  }
  if (mode == _ViewMode.safeRange) {
    return (afr >= 12.8 && afr <= 13.8) ? AppColors.safe.withValues(alpha: 0.18) : AppColors.warning.withValues(alpha: 0.18);
  }
  // target mode
  final fm = FuelMap(values: [[afr]]);  // can't call getCellStatus with single value
  // Instead inline the logic:
  if (afr >= 12.8 && afr <= 13.8) return AppColors.safe.withValues(alpha: 0.7);
  if (afr >= 12.0 && afr <= 14.7) return AppColors.warning.withValues(alpha: 0.7);
  return AppColors.danger.withValues(alpha: 0.7);
}
```

### Cell color logic (ignition map)

```dart
Color _ignitionCellColor(double deg, _ViewMode mode) {
  if (mode == _ViewMode.dangerZone) {
    return deg > 38 ? AppColors.danger.withValues(alpha: 0.7) : AppColors.safe.withValues(alpha: 0.18);
  }
  if (mode == _ViewMode.safeRange) {
    return deg <= 35 ? AppColors.safe.withValues(alpha: 0.18) : AppColors.warning.withValues(alpha: 0.18);
  }
  // target
  if (deg > 38) return AppColors.danger.withValues(alpha: 0.7);
  if (deg > 35) return AppColors.warning.withValues(alpha: 0.7);
  return AppColors.safe.withValues(alpha: 0.7);
}
```

- [ ] **Step 1: Write the full map_viewer_screen.dart file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../models/fuel_map.dart';
import '../../models/tune_profile.dart';

enum MapType { fuel, ignition }

enum _ViewMode { target, safeRange, dangerZone }

class MapViewerScreen extends ConsumerStatefulWidget {
  final MapType mapType;
  const MapViewerScreen({super.key, required this.mapType});

  @override
  ConsumerState<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends ConsumerState<MapViewerScreen> {
  _ViewMode _viewMode = _ViewMode.target;
  TuneProfile? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile ??=
        ModalRoute.of(context)?.settings.arguments as TuneProfile?;
  }

  bool get _isFuel => widget.mapType == MapType.fuel;

  List<List<double>> get _mapValues {
    if (_profile == null) return _defaultValues;
    return _isFuel ? _profile!.fuelMap : _profile!.ignitionMap;
  }

  List<List<double>> get _defaultValues {
    return List.generate(
        12, (_) => List.filled(12, _isFuel ? 13.0 : 20.0));
  }

  Color _cellColor(double value) {
    if (_isFuel) return _fuelCellColor(value);
    return _ignitionCellColor(value);
  }

  Color _fuelCellColor(double afr) {
    if (_viewMode == _ViewMode.dangerZone) {
      return (afr < 12.8 || afr > 13.8)
          ? AppColors.danger.withValues(alpha: 0.75)
          : AppColors.safe.withValues(alpha: 0.15);
    }
    if (_viewMode == _ViewMode.safeRange) {
      return (afr >= 12.8 && afr <= 13.8)
          ? AppColors.safe.withValues(alpha: 0.25)
          : AppColors.warning.withValues(alpha: 0.15);
    }
    // target
    if (afr >= 12.8 && afr <= 13.8) {
      return AppColors.safe.withValues(alpha: 0.65);
    }
    if (afr >= 12.0 && afr <= 14.7) {
      return AppColors.warning.withValues(alpha: 0.65);
    }
    return AppColors.danger.withValues(alpha: 0.65);
  }

  Color _ignitionCellColor(double deg) {
    if (_viewMode == _ViewMode.dangerZone) {
      return deg > 38
          ? AppColors.danger.withValues(alpha: 0.75)
          : AppColors.safe.withValues(alpha: 0.15);
    }
    if (_viewMode == _ViewMode.safeRange) {
      return deg <= 35
          ? AppColors.safe.withValues(alpha: 0.25)
          : AppColors.warning.withValues(alpha: 0.15);
    }
    // target
    if (deg > 38) return AppColors.danger.withValues(alpha: 0.65);
    if (deg > 35) return AppColors.warning.withValues(alpha: 0.65);
    return AppColors.safe.withValues(alpha: 0.65);
  }

  String _formatValue(double v) {
    return _isFuel ? v.toStringAsFixed(1) : '${v.toStringAsFixed(0)}°';
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<_ViewMode>(
        segments: [
          ButtonSegment(
            value: _ViewMode.target,
            label: Text('Target',
                style: GoogleFonts.inter(fontSize: 11)),
          ),
          ButtonSegment(
            value: _ViewMode.safeRange,
            label: Text('Safe Range',
                style: GoogleFonts.inter(fontSize: 11)),
          ),
          ButtonSegment(
            value: _ViewMode.dangerZone,
            label: Text('Danger Zone',
                style: GoogleFonts.inter(fontSize: 11)),
          ),
        ],
        selected: {_viewMode},
        onSelectionChanged: (s) =>
            setState(() => _viewMode = s.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary.withValues(alpha: 0.85);
            }
            return AppColors.panel;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textPrimary;
            }
            return AppColors.textSecondary;
          }),
        ),
      ),
    );
  }

  Widget _buildAxisLabels() {
    // Column headers — RPM (1k..12k)
    final rpmLabels = FuelMap.rpmAxis
        .map((r) => '${r ~/ 1000}k')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RPM header row
        Row(
          children: [
            const SizedBox(width: 40), // spacer for TPS labels
            ...rpmLabels.map(
              (r) => Expanded(
                child: Text(
                  r,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          'RPM →',
          style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final values = _mapValues;
    final tpsLabels = FuelMap.tpsAxis;

    return Column(
      children: List.generate(12, (tpsIdx) {
        return Row(
          children: [
            // TPS label
            SizedBox(
              width: 40,
              child: Text(
                '${tpsLabels[tpsIdx]}%',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...List.generate(12, (rpmIdx) {
              final value = tpsIdx < values.length &&
                      rpmIdx < values[tpsIdx].length
                  ? values[tpsIdx][rpmIdx]
                  : (_isFuel ? 13.0 : 20.0);
              final bg = _cellColor(value);
              return Expanded(
                child: Container(
                  height: 28,
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatValue(value),
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _legendItem(AppColors.safe, _isFuel ? '12.8–13.8 AFR' : '≤35°'),
          const SizedBox(width: 12),
          _legendItem(AppColors.warning, _isFuel ? '12.0–14.7 AFR' : '35–38°'),
          const SizedBox(width: 12),
          _legendItem(AppColors.danger, _isFuel ? 'Di-ligtas' : '>38°'),
          if (!_isFuel) ...[
            const SizedBox(width: 12),
            _legendItem(AppColors.vvaZone, 'VVA Zone'),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isFuel
        ? 'Fuel Map Reference'
        : 'Ignition Map Reference';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF export kailangan ng session data. '
                'I-export mula sa Post-Remap screen.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(
          'I-EXPORT PDF',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToggleRow(),
          _buildLegend(),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'TPS ↓   /   RPM →',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 500
                      ? MediaQuery.of(context).size.width - 16
                      : 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAxisLabels(),
                      const SizedBox(height: 4),
                      _buildGrid(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

```
flutter analyze lib/screens/fuel_map/map_viewer_screen.dart
```

Expected: No errors.

---

## Task 5: FuelMapScreen and IgnitionMapScreen — thin wrappers

**Files:**
- Modify: `lib/screens/fuel_map/fuel_map_screen.dart`
- Modify: `lib/screens/ignition_map/ignition_map_screen.dart`

- [ ] **Step 1: Replace fuel_map_screen.dart with thin wrapper**

```dart
import 'package:flutter/material.dart';
import 'map_viewer_screen.dart';

class FuelMapScreen extends StatelessWidget {
  const FuelMapScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MapViewerScreen(mapType: MapType.fuel);
}
```

- [ ] **Step 2: Replace ignition_map_screen.dart with thin wrapper**

```dart
import 'package:flutter/material.dart';
import '../fuel_map/map_viewer_screen.dart';

class IgnitionMapScreen extends StatelessWidget {
  const IgnitionMapScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MapViewerScreen(mapType: MapType.ignition);
}
```

- [ ] **Step 3: Verify analyze on all 4 screen directories**

```
flutter analyze lib/screens/pre_remap/ lib/screens/tune_profiles/ lib/screens/fuel_map/ lib/screens/ignition_map/
```

Expected: No errors.

---

## Task 6: Final verification

- [ ] **Step 1: Run full analyze**

```
flutter analyze lib/
```

Expected: No errors or only infos (no errors/warnings that would block build).

- [ ] **Step 2: Run full test suite**

```
flutter test
```

Expected: 58 tests pass, 0 failures.

- [ ] **Step 3: Report complete**

Output: "DONE — 5 screens replaced, 1 new file created, 58 tests pass."
