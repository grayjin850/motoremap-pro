# MotoRemap Pro — Kumpletong Tutorial

**Para sa mga propesyonal na mekaniko at motorsiklo tuner**

**Bersyon: Phase 7 (2026-05-26)**

---

## Talaan ng Nilalaman

1. [Recommended Hardware](#1--recommended-hardware)
2. [Overview ng Workflow](#2--overview-ng-workflow)
3. [Unang Pagbubukas — Pagpili ng Motor](#3--unang-pagbubukas--pagpili-ng-motor)
4. [Pre-Remap Safety Check](#4--pre-remap-safety-check)
5. [Kumonekta ng USB K-Line Adapter](#5--kumonekta-ng-usb-k-line-adapter)
6. [ECU Identification at ROM Dump](#6--ecu-identification-at-rom-dump)
7. [ROM Integrity Check](#7--rom-integrity-check)
8. [Interactive Map Editor](#8--interactive-map-editor)
9. [AI Tuning Assistant](#9--ai-tuning-assistant)
10. [Customer Preset System](#10--customer-preset-system)
11. [Professional Mode](#11--professional-mode)
12. [Pre-Flash Gate at Risk Analyzer](#12--pre-flash-gate-at-risk-analyzer)
13. [ECU Flash Workflow](#13--ecu-flash-workflow)
14. [Post-Flash Verification](#14--post-flash-verification)
15. [ECU Verification Chain](#15--ecu-verification-chain)
16. [Validation Report PDF](#16--validation-report-pdf)
17. [Protocol Log Viewer](#17--protocol-log-viewer)
18. [Live OBD Monitor](#18--live-obd-monitor)
19. [Session History](#19--session-history)
20. [Troubleshooting](#20--troubleshooting)
21. [Safety Reminders](#21--safety-reminders)
22. [Paano Gumagana ang Buong Sistema](#22--paano-gumagana-ang-buong-sistema)

---

## 1 — Recommended Hardware

### Android Device

| Spec | Minimum | Rekomendasyon |
|---|---|---|
| Android | 8.0 (API 26) | 11+ |
| RAM | 3 GB | 4–6 GB |
| Storage | 1 GB free | 2 GB free |
| Screen | 5.5" phone | 8–10" tablet |
| USB | USB-C o Micro-USB OTG | USB-C na may OTG cable |

**Best tablet picks (2025):**
- Samsung Galaxy Tab A9+ (11") — malaking screen, OTG ready, P8,000–P10,000
- Lenovo Tab M11 (11") — mabilis, maliwanag, P7,500–P9,000
- Redmi Pad SE (11") — value king, P5,500–P7,000

> **Importante:** Kailangan ng USB OTG support para sa K-Line USB adapter. Halos lahat ng modernong Android tablet ay may OTG. I-verify sa Settings → About → USB OTG.

---

### USB K-Line Adapter (Para sa Actual ECU Flash)

Ang MotoRemap Pro ay gumagamit ng **USB wired adapter** para sa ECU reading at flashing. Bluetooth adapters (ELM327) ay para sa **diagnostics at live monitor lamang — hindi sila nagfo-flash**.

| Adapter | Chip | Compatibility | Rekomendasyon |
|---|---|---|---|
| OpenPort 2.0 clone | FTDI FT232R | Click 125i, Aerox 155 | ✅ Top pick sa PH |
| Generic K-Line USB | CP2102 / CH340 | Click 125i, Aerox 155 | ✅ Budget-friendly |
| Autel K-Line Cable | PL2303 | Maraming ECU | ✅ Maganda rin |
| Generic "OBD K-Line" | Walang chip info | Pabiro-biro | ⚠ I-test muna |

**Suportadong USB chips** (awtomatikong nire-recognize ng app):
- FTDI FT232R / FT232H / FT231X — pinaka-stable, OpenPort 2.0
- Silicon Labs CP2102 / CP2104 — mabilis, mura
- WCH CH340 / CH341 — pinakacommon sa PH
- Prolific PL2303 — gumagana sa karamihang adapters

**Connector para sa target ECU:**
- Honda Click 125i → 3-pin Honda diagnostic connector (karaniwang malapit sa battery)
- Yamaha Aerox 155 → 4-pin Yamaha diagnostic connector (malapit sa airbox)

---

### Bluetooth OBD Adapter (Para sa Live Monitor Lamang)

| Adapter | Rekomendasyon |
|---|---|
| Viecar ELM327 v2.1 BT | ✅ Top pick |
| KOBRA OBD2 Bluetooth | ✅ Reliable |
| OBDLink LX | ✅ Premium |
| Generic BLE (Bluetooth LE) | ❌ Hindi compatible — kailangan ng Bluetooth Classic |

---

## 2 — Overview ng Workflow

### Para sa Bagong ECU (Hindi Pa Na-verify)

```
Piliin ang Motor
  → Kumonekta ng USB K-Line Adapter
    → ECU Identification (0x1A records)
      → ROM Dump (service 0x23)
        → ROM Integrity Check
          → Map Editor / Preset Selector
            → Risk Analyzer
              → Pre-Flash Gate (7 conditions)
                → ECU Flash (backup→erase→write→verify)
                  → Post-Flash Verification
                    → ECU Verification Chain — VERIFIED ✅
```

### Para sa Na-verify na ECU (Regular na Remap)

```
Piliin ang Motor
  → Piliin ang Preset o I-edit ang Map
    → Risk Analyzer
      → Pre-Flash Gate
        → Flash
          → Verify
```

---

## 3 — Unang Pagbubukas — Pagpili ng Motor

1. Buksan ang **MotoRemap Pro**. Lalabas ang Splash Screen, pagkatapos ay Home Screen.
2. I-tap ang **"Piliin ang Motorsiklo"** o ang model selector sa itaas.
3. Piliin ang modelo:
   - **Honda Click 125i** — Keihin PGM-FI ECU, K-Line / KWP2000
   - **Yamaha Aerox 155** — Shindengen RH850, K-Line / KWP2000 fast-init
4. I-tap ang **"Piliin ang Motor na Ito"**.

> **Tip:** Ang pagpili ng tamang modelo ay kritikal. Iba-iba ang ROM offsets, checksum algorithm, security access algorithm, at safe limits ng bawat ECU. Huwag gamitin ang Click preset sa Aerox at vice versa.

---

## 4 — Pre-Remap Safety Check

**Saan:** Home Screen → "Pre-Remap Check"

Kailangan ng **85 points o mas mataas** bago makarating sa Map Editor o Flash.

### 4A — Fault Code Scan

1. I-tap ang **"I-scan ang Fault Codes"**.
2. Kung konektado ang Bluetooth OBD, awtomatikong mag-i-scan.
3. Kung wala: i-input nang manu-mano ang bilang ng active fault codes.

**Scoring:**
- 0 fault codes → walang deduction
- 1–2 fault codes → -20 bawat isa (warning)
- 3+ fault codes → **HARD BLOCK** — resolbahin muna

### 4B — Engine Warm-Up

Hintayin ang **70°C coolant temperature** bago magsimula. Kung air-cooled (wala sa listahan), i-tap ang **"I-confirm nang Manu-mano"**.

### 4C — Pre-Remap Checklist (7 Items)

| # | Item | Bakit Kritikal |
|---|---|---|
| 1 | Nakuha na ang ECU backup | Walang rollback kung walang backup |
| 2 | Sapat ang gasolina (min ¼ tank) | Hindi magtatapos ang engine mid-flash |
| 3 | Baterya ≥12.4V | Mababang voltage = corrupt flash |
| 4 | OK ang lahat ng electrical connections | Loose ground = sirang ECU |
| 5 | Handa ang USB K-Line adapter | Hindi maaaring ihinto ang flash sa gitna |
| 6 | Informed ang kliyente | Para sa proteksyon ng lahat |
| 7 | Nakalagay ang motor sa level na lugar | Para hindi mabuwal habang naka-idle |

---

## 5 — Kumonekta ng USB K-Line Adapter

**Saan:** Lumabas sa Pre-Remap Check → USB Connection screen

### Hakbang-hakbang

1. **I-plug ang USB K-Line adapter** sa diagnostic connector ng motor.
   - Click 125i: 3-pin Honda connector, karaniwang nasa ilalim ng seat o malapit sa battery
   - Aerox 155: 4-pin Yamaha connector, sa kaliwa ng airbox
2. **I-plug ang USB cable** mula sa adapter patungong Android tablet via OTG cable.
3. Lalabas ang **"Allow USB access?"** dialog ng Android → I-tap ang **"OK"** o **"Allow"**.
4. Sa app, i-tap ang **"I-scan ang mga USB Adapter"**.
5. Makikita ang listahan ng mga nahanap na USB device (kasama ang chip type: FTDI, CP2102, atbp.).
6. I-tap ang tamang adapter at i-tap ang **"Kumonekta"**.

Makikita ang **"K-Line USB Connected"** na status indicator (berde) kapag matagumpay.

> **Kung hindi nagpapakita ang adapter:** Tingnan ang [Troubleshooting §20](#20--troubleshooting).

---

## 6 — ECU Identification at ROM Dump

### ECU Identification (service 0x1A)

Pagkakonekta ng USB adapter, awtomatikong magpe-perform ang app ng **ECU Identification** gamit ang KWP2000 service 0x1A:

- **Record 0x87** — Part number (e.g., `37820-KYZ-N01`)
- **Record 0x88** — Hardware version
- **Record 0x89** — Software version
- **Record 0x97** — Calibration ID

Ang mga info na ito ay ginagamit para gumawa ng **ECU fingerprint** — unique identifier para sa bawat physical ECU unit. Kapag nagbago ang fingerprint (ibang ECU ang nakakonekta), magla-launch ang warning dialog.

### ROM Dump (service 0x23)

1. I-tap ang **"I-dump ang ROM"**.
2. Ang app ay mag-re-request ng **Security Access** (KWP2000 service 0x27):
   - Click 125i → Keihin XOR algorithm (XOR 0x1234, rotate-left-4, XOR 0x4E21)
   - Aerox 155 → Shindengen RH850 algorithm (XOR 0xA55A, rotate-right-5, XOR 0x5AA5)
3. Pagkatapos ng security unlock, magsisimula ang chunked read (128 bytes per request):
   - Click 125i: 64KB ROM
   - Aerox 155: 128KB ROM
4. Makikita ang progress bar — dumadaan sa bawat 128-byte chunk.
5. Kapag tapos na: ang ROM ay **sine-save bilang `.bin` file** sa `Documents/backups/` ng device.

> **Tandaan:** Ang unang ROM dump mula sa isang bagong ECU unit ay ire-record sa EcuVerificationManager at babahaginan ng fingerprint hash. Gamitin ito bilang reference para sa lahat ng susunod na sessions sa parehong ECU.

---

## 7 — ROM Integrity Check

Bago buksan ang Map Editor o simulan ang flash, awtomatikong ginagawa ng app ang **ROM Integrity Check**:

| Fault Type | Kahulugan | Nakakablock? |
|---|---|---|
| `wrongSize` | ROM size ≠ expected (64KB o 128KB) | ✅ OO |
| `allZeros` | Lahat ng bytes ay 0x00 — blank flash chip | ✅ OO |
| `allOnes` | Lahat ng bytes ay 0xFF — erased flash | ✅ OO |
| `lowEntropy` | Abnormally flat data (<3.5 bits/byte) — posibleng truncated read | ✅ OO |
| `repeatingBlocks` | Maraming identical 256-byte blocks — posibleng corrupt | ⚠ Warning lamang |

**Kung may blocking fault:**
1. Huwag magpatuloy — i-dismiss ang error dialog.
2. I-check ang USB connection — baka nagkaroon ng loose contact sa ROM read.
3. I-retry ang ROM dump.
4. Kung paulit-ulit ang error, subukan ang ibang USB adapter o ibang diagnostic port.

**Kung OK ang integrity check:** Awtomatikong magbubukas ang Map Editor.

---

## 8 — Interactive Map Editor

**Saan:** Pagkatapos ng ROM Integrity Check → Map Editor Screen

### Paano Gamitin ang Map Grid

- **I-tap ang isang cell** — piliin at makita ang raw value + physical value + safe range
- **Double-tap ang isang cell** — mag-input ng bagong value sa keyboard
- **Long-press** — context menu: Edit, Reset to Stock, Interpolate
- **Pinch to zoom** — para sa malaking maps (16×16 ng Aerox)
- **Swipe** — lumipat sa iba pang maps (Fuel Map, Ignition Map, VVA Transition)

### Color Coding ng Cells

| Kulay | Kahulugan |
|---|---|
| 🔵 Asul na malalim | Mayaman (rich) na mixture — mataas na fuel, mababang AFR |
| ⬜ Puti | Stoichiometric (~14.7:1) — perfect combustion |
| 🔴 Pula | Payat (lean) na mixture — mababang fuel, mataas na AFR |
| 🟠 Kahel na frame | Babala — malapit na sa safety limit |
| Pula na frame | **BLOCKED** — labas na sa safe range, hindi ita-flash |

### Axis Labels

- **Rows** = RPM axis (itaas = mas mataas na RPM)
- **Columns** = TPS / Load axis (kanan = mas mataas na throttle)

### Undo/Redo

- I-tap ang **← Undo** (hanggang 50 steps)
- I-tap ang **→ Redo**

### Interpolation

1. Long-press ang unang cell, i-tap ang **"Mark as Interpolation Start"**
2. Long-press ang pangalawang cell (parehong row o column), i-tap ang **"Interpolate"**
3. Ang app ay awtomatikong magko-compute ng smooth values sa pagitan

### Live RPM Overlay

Habang konektado ang OBD (Bluetooth), makikita ang **highlight** sa kasalukuyang active cell base sa live RPM at TPS. Gamitin ito para malaman kung aling cells ang tinamaan ng motor sa actual na pagmamaneho.

### ROM Diff Viewer

Bago mag-flash, i-tap ang **"Tingnan ang mga Pagbabago"** para makita ang:
- Listahan ng bawat binagong cell (mapName, row, col, dati → bago)
- Physical values (hindi raw bytes) para madaling basahin
- **"Approve Changes"** checkbox — kailangan i-tick ito para ma-enable ang Flash button

---

## 9 — AI Tuning Assistant

**Saan:** Map Editor → i-tap ang chat icon (kanang bahagi)

Ang AI Tuning Assistant ay gumagamit ng **Claude Opus 4** at may built-in na kaalaman tungkol sa:
- Honda Click 125i Keihin PGM-FI behavior
- Yamaha Aerox 155 Shindengen RH850 + VVA characteristics
- Safe AFR ranges, timing limits, injector specs, common lean zones

### Paano Gamitin

1. I-tap ang chat icon para buksan ang slide-up panel.
2. Gumamit ng **Quick Prompts** (4 one-tap na tanong):
   - "Bakit parang lean sa 3000 RPM?"
   - "Gusto ng kliyente ng mas mabilis na throttle response"
   - "May exhaust pipe modification — anong irekisa?"
   - "Optimize para sa RON97"
3. O mag-type ng sariling tanong.

### Paano Basahin ang AI Response

- Ang bawat suggestion ay may **risk level badge**: LOW / MEDIUM / HIGH
- I-tap ang **"Apply"** button sa ibaba ng message para i-apply ang mga suggested cell changes
- I-tap ang **"Buong Teksto"** para makita ang buong paliwanag ng AI
- Ang lahat ng AI suggestions ay **nini-filter ng SafetyValidator** bago ipakita — kung ang suggestion ay lumagpas sa hard limits, hindi ito ipapakita

> **Mahalagang tandaan:** Ang AI ay nagbibigay ng mga rekomendasyon base sa modelo-specific na kaalaman, **hindi** generic suggestions. Ang mga halaga na ibinibigay nito ay nakabase sa Keihin o Shindengen ECU behavior, hindi sa generic tuning books.

---

## 10 — Customer Preset System

**Saan:** Home Screen → "Mga Preset" o mula sa Map Editor → Preset icon

Ang Preset System ay may **5 presets para sa Click 125i** at **5 presets para sa Aerox 155**, na naka-organisa sa tatlong kategorya:

### Mga Kategorya

| Kategorya | Kulay | Para Saan |
|---|---|---|
| **Performance** | 🔴 Pula | Racing, drag, aggressive VVA |
| **Daily Use** | 🟢 Berde | Street, touring, eco |
| **Specialized** | 🟡 Dilaw | Pipe tune, VVA smooth |

### Honda Click 125i Presets

| Preset | Risk | RON | Layunin |
|---|---|---|---|
| Eco Tune | SAFE | 91+ | -4% cruise fuel, +1° timing — fuel saving |
| Street Tune | SAFE | 91+ | +4% mid-range 3000–4500 RPM, smoother daily |
| Touring Tune | CAUTION | 91+ | +5% steady cruise, stable highway AFR |
| Pipe Tune | CAUTION | 95+ | +10% lean zone correction + +6% WOT — para sa aftermarket exhaust |
| Racing Tune | **ADVANCED** | **97+** | +8% WOT, +3° timing — track only |

### Yamaha Aerox 155 Presets

| Preset | Risk | RON | Layunin |
|---|---|---|---|
| VVA Smooth Tune | SAFE | 91+ | +6% VVA transition zone — para sa smoother power delivery |
| Daily Tune | SAFE | 91+ | +5% mid-range + VVA correction |
| Aggressive VVA Tune | **ADVANCED** | **95+** | +10% VVA + +8% WOT + +2° timing |
| Fuel Economy Tune | SAFE | 91+ | -5% cruise, VVA zone protected |
| Drag Tune | **ADVANCED** | **97+** | +12% WOT + +4° VVA + +4° timing — strip only |

### PROCEED Gate para sa Advanced Presets

Ang mga preset na may **ADVANCED** na risk level ay may espesyal na kumpirmasyon:

1. I-tap ang preset at i-tap ang **"Apply"**.
2. Lalabas ang **PROCEED dialog** — nagpapakita ng lahat ng warnings at requirements.
3. **I-type ang salitang `PROCEED`** (malalaking titik, eksaktong ganito) sa text field.
4. Kapag nag-match, ma-e-enable ang **"APPLY ADVANCED TUNE"** button.

> **Bakit kailangan ng PROCEED?** Ang mga advanced presets (Racing, Drag, Aggressive VVA) ay idinisenyo para sa kompetisyon at may mataas na panganib ng engine damage kung gagamitin sa maling kondisyon — maling octane, worn piston, hindi verified na ROM offsets. Ang PROCEED ay para masiguro na alam ng mekaniko ang lahat ng risks.

### Verification Banner

Kung ang ECU ay **hindi pa na-verify** sa real hardware, lalabas ang **orange warning banner** sa itaas ng preset list:

> "ECU NOT hardware-validated — ROM offsets are community estimates. Validate before flashing."

Kapag **na-verify na** (kumpleto ang 8-step validation chain), magiging **berde** ang banner:

> "ECU validated on real hardware — presets are safe to apply"

---

## 11 — Professional Mode

**Saan:** Home Screen → "Professional Mode" o mula sa Map Editor → Pro icon

Ang Professional Mode ay nagbibigay ng access sa **10 advanced parameters** na hindi makikita sa standard Map Editor:

### Mga Parameter

| Parameter | Default (Click) | Default (Aerox) | Range |
|---|---|---|---|
| Fan ON Temp | 98°C | 95°C | 80–105°C |
| Fan OFF Temp | 94°C | 91°C | 75–100°C |
| Decel Cut ON RPM | 2,000 RPM | 2,500 RPM | 1,200–4,000 RPM |
| Decel Cut OFF RPM | 1,500 RPM | 1,800 RPM | 800–2,500 RPM |
| Throttle Sensitivity | 100% | 100% | 70–130% |
| Injector Dead Time | 0.80 ms | 0.72 ms | 0.40–1.50 ms |
| Injector Flow Scale | 100% | 100% | 60–160% |
| Soft Rev Limit | 9,000 RPM | 11,000 RPM | 7,000–10,500 RPM |
| Hard Rev Limit | 9,500 RPM | 11,500 RPM | 7,500–11,000 RPM |
| Launch Control RPM | 0 (off) | 0 (off) | 0–5,000 / 6,000 RPM |

### HIGH RISK Parameters

Ang **Rev Limits** at **Launch Control** ay may **HIGH RISK** badge at kailangan ng PROCEED confirmation bago baguhin:

1. I-galaw ang slider ng Soft Rev Limit, Hard Rev Limit, o Launch Control RPM.
2. Lalabas ang PROCEED dialog — i-type ang `PROCEED`.
3. Pagkatapos, ma-a-apply ang bagong value.

### Injector Scaling (Para sa Injector Upgrade)

Kung nag-upgrade ng injectors (mas mataas na flow rate kaysa stock):

1. Alamin ang stock injector flow rate (Click: 90cc/min @ 3 bar, Aerox: 120cc/min)
2. Alamin ang bagong injector flow rate
3. I-compute: `Injector Flow Scale = (stock_cc / new_cc) × 100`
   - Halimbawa: Stock 90cc, bagong injector 120cc → Scale = 90/120 × 100 = **75%**
4. I-set ang Injector Flow Scale sa computed value
5. I-adjust ang Injector Dead Time kung ang bagong injectors ay mas mabilis o mas mabagal

### Send to Flash

Pagkatapos i-set ang lahat ng parameters, i-tap ang **"Send to Flash"** — dadalhin ka sa Flash Screen na may mga parameter changes na handa nang i-apply.

---

## 12 — Pre-Flash Gate at Risk Analyzer

Bago payagan ang flash, **dalawang sistema** ang nag-e-evaluate ng bawat ROM change:

### Risk Analyzer

Awtomatiko itong nagra-run bago buksan ang Flash Screen. Nag-e-evaluate ito ng bawat cell sa bawat map:

| Risk Level | Kahulugan |
|---|---|
| `safe` | Nasa normal na range |
| `lean` | Malapit sa lean limit — detonation risk |
| `rich` | Malapit sa rich limit — fouling risk |
| `timingHigh` | Loob ng 3° sa timing hard limit — premium fuel kinakailangan |
| `outOfRange` | Labas na sa safe range — **BLOCKS FLASH** |

**Heat Risk Levels:**
- 🟢 **Cool** — Lahat ng values OK
- 🟡 **Warm** — Ilan sa cells ay malapit sa limits
- 🔴 **Hot** — Maraming lean o high-timing cells
- 💀 **Critical** — May out-of-range cells o sobrang daming lean cells

**Knock Risk Percentage:** 0–100% estimate ng probability ng detonation base sa timing values vs hard limits.

### Pre-Flash Gate (7 Conditions)

Lahat ng 7 ay kailangan bago payagan ang flash:

| # | Condition | Failure Message |
|---|---|---|
| 1 | Battery ≥12.4V | "Baterya mababa — charge muna" |
| 2 | Engine off (RPM = 0) | "Patayin ang motor bago mag-flash" |
| 3 | Coolant <40°C | "Hintayin pang lumamig ang motor" |
| 4 | Backup file verified | "Walang backup — i-dump muna ang ROM" |
| 5 | Checksum verified sa modified ROM | "Checksum error — mag-retry" |
| 6 | Diff approved ng user | "I-review at i-approve ang changes" |
| 7 | Safety score ≥85 | "Risk score masyadong mababa" |

> **Tandaan:** Condition #3 (coolant check) ay hindi applicable sa mga **air-cooled ECU** — awtomatikong nipa-pass ito.

---

## 13 — ECU Flash Workflow

**Saan:** Pagkatapos ng Pre-Flash Gate → Flash Screen

### Mga Yugto ng Flash

```
1. Backup         → Sine-save ang current ROM sa device storage
2. Erase          → Service 0x34 (RequestDownload) + 0x31 (Erase) → 5 segundo
3. Write          → Service 0x36 (TransferData) — 128 bytes bawat chunk
4. Transfer Exit  → Service 0x37 — isinasara ang transfer session
5. Verify         → Service 0x23 (ReadMemoryByAddress) — byte-per-byte comparison
6. Done / Failed  → Resulta
```

### Paano Basahin ang Progress Screen

- **Stage indicator dots** sa itaas — kinukumpleto ng isa-isa
- **Progress bar** — nagpapakita ng KB written / KB total
- **Status message** — "Writing 32 / 64 KB..."

### Flash Interruption Recovery

Kung **mabigo ang USB connection** habang nasa gitna ng write:

1. Ang app ay **awtomatikong mag-a-detect** ng USB disconnect o timeout
2. Magla-launch agad ang **auto-recovery** pagkatapos ng 2-segundo (para makapag-reconnect ang adapter)
3. Iri-restore ang huling backup ROM sa ECU
4. Lalabas ang mensahe: "Recovery complete. Original ROM restored."

> **Kung mangyari ito sa real flashing session:**
> 1. Huwag putulin ang power ng motor.
> 2. Hintayin ang recovery sequence — 30–60 segundos.
> 3. Kung na-restore ang backup: OK ang ECU, mag-retry ng flash.
> 4. Kung hindi makarating sa recovery: huwag paandarin ang motor — kontakin ang isang ECU recovery specialist.

### Backup System

- Nino-noto ang bawat backup bilang: `{ecuId}_{timestamp}.bin`
- Sinisigurado ang huling **5 backups** — ang lumang backups ay awtomatikong natanggal
- Makikita ang lahat ng backups sa Settings → ROM Backups

---

## 14 — Post-Flash Verification

Pagkatapos ng matagumpay na flash, ipakita ang **Post-Flash Verification screen**:

### Section A — Fault Code Scan

I-scan ang fault codes pagkatapos ng flash. Ang bagong fault codes na lumabas pagkatapos ng flash ay nagpapahiwatig ng problema.

### Section B — Cold Start Verification

I-tick ang 5 items habang pinapanood ang motor:
1. Motor nag-start nang maayos
2. Idle stable, hindi nagta-tango
3. Walang hunting o rough idle
4. Walang unusual tunog o vibration
5. Walang smoke mula sa exhaust

### Section C — Warm-Up Monitor

Hintayin ang **70°C** coolant temperature. Obserbahan ang behavior ng motor habang nagwa-warm up.

### Section D — Test Ride Checklist

Pagkatapos ng maikling test ride:
1. Low RPM (1–3k) — smooth, walang stutter
2. Mid RPM (3–6k) — walang flat spot
3. High RPM (6k+) — walang knock o ping
4. Speed limiter — nag-a-activate sa tamang speed (kung hindi binago)
5. Engine braking — smooth, walang surge

### Section E — Final Assessment

Piliin ang resulta:
- ✅ **Matagumpay** — OK ang lahat
- ⚠ **May Isyu** — kailangan ng dagdag na adjustment
- 🔴 **Rollback** — bumalik sa stock, hindi ligtas

---

## 15 — ECU Verification Chain

Ang **EcuVerificationManager** ay nagtatago ng 8-step validation chain para sa bawat ECU unit. Ang isang ECU ay considered **VERIFIED** lamang kapag kumpleto ang lahat ng steps.

### Mga Validation Steps

| Step | Method sa App | Paano Kumpletuhin |
|---|---|---|
| 1. ROM Dump Hash | `recordRomDump()` | Awtomatiko kapag na-dump ang ROM |
| 2. Checksum Validation | `recordChecksumValidated()` | Kumpirmahing tama ang checksum algorithm sa hex dump |
| 3. Security Access | `recordSecurityAccessConfirmed()` | Kapag nag-succeed ang seed→key exchange |
| 4. Fuel Map Offset | `recordOffsetValidated('fuel_map', offset)` | Hanapin ang fuel map sa hex editor, i-confirm ang offset |
| 5. Ignition Map Offset | `recordOffsetValidated('ignition_map', offset)` | Katulad ng #4 |
| 6. VVA Map Offset | `recordOffsetValidated('vva_transition', offset)` | Aerox 155 lamang |
| 7. Checksum Algo Confirmed | (kasama sa step 2) | Verified kapag tama ang computed == stored |
| 8. Successful Flash + Reboot | `recordSuccessfulFlash()` | Awtomatiko pagkatapos ng matagumpay na flash + verify |

### Verification Status Indicators

| Status | Ibig Sabihin | Banner Color |
|---|---|---|
| **UNVERIFIED** | Walang hardware contact — ROM offsets ay community estimates | 🟠 Orange |
| **PARTIAL** | ROM dump na pero hindi lahat ng steps kumpleto | 🟡 Yellow |
| **VERIFIED** | Kumpleto ang lahat ng steps — safe to flash | 🟢 Green |

### Paano Malalaman ang Verification Status

- Makikita ang status banner sa itaas ng Preset Selector at Professional Mode screens
- I-tap ang **"ECU Verification"** sa Settings para makita ang buong checklist

> **Rekomendasyon para sa Bagong ECU:**
> Huwag mag-apply ng mataas na risk presets (Racing, Drag) hanggang **VERIFIED** ang ECU. Gamitin muna ang **SAFE** na presets habang pinapa-validate ang offsets.

---

## 16 — Validation Report PDF

**Saan:** Professional Mode AppBar → PDF icon | o Settings → "I-export ang Validation Report"

Ang Validation Report ay isang **PDF na dokumento** na naglalaman ng:

- **Header** — ECU ID, petsa, verification status (VERIFIED / PARTIAL / UNVERIFIED)
- **Status Summary** — Paliwanag ng kasalukuyang status
- **Validation Checklist** — Bawat step na may ✓/✗ at timestamp
- **Validated Map Offsets** — Talahanayan ng mga kumpirmadong ROM offsets
- **Flash History** — Bilang ng matagumpay na flashes at petsa ng huli

### Para sa Anong Gamit

- **Customer documentation** — Ibigay sa kliyente bilang patunay na validated ang ECU
- **Shop records** — Para sa accountability at follow-up sessions
- **Debugging** — Para malaman kung aling validation steps ang nailabas pa

I-tap ang **"Share"** para i-send via email, Messenger, o i-save sa device storage.

---

## 17 — Protocol Log Viewer

**Saan:** Settings → "Protocol Log" o diagnostic icon sa Connection screen

Ang Protocol Log ay nagpapakita ng **bawat KWP2000 frame** na ipinadala sa at natanggap mula sa ECU sa kasalukuyang session:

### Paano Basahin ang Log

| Kulay | Ibig Sabihin |
|---|---|
| 🔵 Asul | **TX** — frame na ipinadala ng app patungong ECU |
| 🟢 Berde | **RX** — frame na natanggap mula sa ECU |
| 🔴 Pula | **NRC** — Negative Response Code — sinabi ng ECU na may problema |

### Halimbawa ng Log Entry

```
[14:23:05.142] TX  27  → SecurityAccess Request     |  80 10 F1 02 27 01 AB
[14:23:05.204] RX  67  ← SecurityAccess Response    |  80 F1 10 04 67 01 3C 7A D2
[14:23:05.216] TX  27  → SecurityAccess Key         |  80 10 F1 04 27 02 4B 29 6E
[14:23:05.280] RX  67  ← SecurityAccess Confirmed   |  80 F1 10 02 67 02 51
```

### Mga Gamit ng Protocol Log

- **Debugging ng USB connection issues** — Makikita kung nagpapadala ang app ng frames pero hindi tumatanggap ng response
- **Verifying security access algorithm** — Makikita kung tamang key ang nakukuha
- **Diagnosing NRC errors** — Makikita ang NRC code at ang human-readable na description nito
- **Hardware verification** — Para makumpirma na ang ECU ay sumasagot sa mga commands

### Export ng Log

I-tap ang **Copy icon** sa itaas para i-copy ang buong log bilang plain text. I-paste sa notepad o i-send sa isang ECU specialist para sa mas detalyadong analysis.

### Auto-scroll Toggle

I-toggle ang **auto-scroll switch** para awtomatikong pumunta sa pinakabagong frame habang dumadating ang data.

---

## 18 — Live OBD Monitor

**Saan:** Home Screen → "Live Monitor"

> **Tandaan:** Ang Bluetooth OBD adapter (ELM327) ay para sa **live monitoring at diagnostics lamang**. Hindi ito ginagamit para sa ROM reading o flashing.

### I-konekta ang OBD Adapter

1. I-pair ang ELM327 sa Bluetooth settings ng Android (PIN: **1234** o **0000**).
2. Bumalik sa app → "Live Monitor".
3. Makikita ang **"OBD Connected"** (berde) o **"OBD Disconnected"** (kulay-abo) sa itaas.

### Mga Gauge

| Gauge | Normal Range | Babala | Kritikal |
|---|---|---|---|
| RPM | 1,000–8,000 | 8,000–10,000 | 10,000+ |
| TPS | 0–100% | — | — |
| AFR (est.) | 13.0–14.7 | 12.0–13.0 o 15.0–16.0 | <12.0 o >16.0 |
| Coolant Temp | 70–95°C | 95–105°C | 105°C+ |
| Battery | 12.5–14.5V | 11.5–12.5V | <11.5V |
| IAT | 20–45°C | 45–60°C | 60°C+ |
| Engine Load | 20–80% | 80–95% | 95%+ |
| STFT | -5% hanggang +5% | ±5–10% | ±10%+ |
| LTFT | -10% hanggang +10% | ±10–15% | ±15%+ |
| **Knock Retard** | **0°** | **0.1–3°** | **>3° = STOP** |

### Knock Retard (Kritikal!)

- **0°** = Walang knock, ligtas
- **>0°** = Kinukuha ng ECU ang timing dahil may detonation
- **>3°** = **RED SCREEN** — ihinto ang session

**Kung may RED SCREEN ng knock:**
1. IHINTO ang session ngayon din.
2. Ibaba ang timing advance sa profile o map.
3. Palitan ng mas mataas na octane (RON95 o RON97).
4. I-check ang kondisyon ng piston at compression.
5. Huwag magpatuloy hanggang 0° na ang knock retard.

### Live Chart

Makikita ang real-time na chart ng: RPM, AFR estimate, STFT, at Engine Load.

### Data Logging

1. I-tap ang ● (record) para magsimula.
2. I-tap ang table icon para lumipat sa log view.
3. I-tap ang download icon para mag-export ng CSV.

---

## 19 — Session History

**Saan:** Home Screen → "Sessions"

Makikita ang lahat ng nakaraang sessions kasama ang:
- Petsa at oras, motor at variant
- Pre-remap score at tune safety score
- Resulta: Matagumpay / May Isyu / Rollback
- Pangalan ng kliyente at plate number

I-tap ang isang session para sa buong detalye.

---

## 20 — Troubleshooting

### USB Adapter Hindi Nagpapakita sa App

1. Siguraduhin na ang tablet ay may **USB OTG** support.
2. Gamitin ang tamang **OTG cable** (USB-C female → adapter, o Micro-USB OTG).
3. I-check kung nag-appear ang **"Allow USB access?"** dialog ng Android — dapat i-tap ang "Allow".
4. Kung walang dialog: subukan ng restart ng app pagkatapos i-plug ang adapter.
5. Kung chip ng adapter ay hindi kilala (walang brand marking): baka hindi supported — subukan ang FTDI o CP2102 based adapter.

### "Security Access Failed" Error

1. Siguraduhin na tamang motor ang napili (Click vs Aerox — ibang algorithm).
2. Subukan ng second attempt — ang ilang ECU ay may delay bago pumayag ng security access.
3. Tingnan ang Protocol Log — hanapin ang NRC code. Ang NRC 0x35 (invalidKey) = maling algorithm. Ang NRC 0x37 (requiredTimeDelayNotExpired) = hintayin ng ilang segundo.

### ROM Dump ay Palaging Failing Integrity Check

| Error | Posibleng Dahilan | Solusyon |
|---|---|---|
| `allZeros` | Loose connection sa diagnostic port | Masiguro ang matatag na koneksyon |
| `wrongSize` | Maling motor ang napili | I-verify ang ECU model |
| `lowEntropy` | USB adapter ay may noise | Subukan ang ibang OBD cable |
| `repeatingBlocks` | Intermittent USB connection | Mas maikling OTG cable |

### Flash ay Nag-trigger ng Recovery

Normal ang recovery kung may USB disconnect. Sundin ang instructions sa screen:
- Kung "Recovery complete" → OK ang ECU, mag-retry ng flash
- Kung "Recovery failed" → **HUWAG** paandarin ang motor, kontakin ang ECU specialist

### Preset ay Nag-block ng Flash (outOfRange Cells)

1. Tingnan ang Risk Report para malaman kung aling cells ang labas sa range.
2. Ang preset ay hindi dapat mag-cause ng out-of-range cells — baka corrupted ROM ang pinagapplyan.
3. I-dump muna ang fresh ROM at subukan ulit.

### AI Assistant ay Hindi Naglo-load

1. Siguraduhin na may internet connection.
2. I-check ang app permissions (Internet).
3. Kung paulit-ulit: baka nasa maintenance ang API — subukan ulit pagkatapos ng ilang minuto.

---

## 21 — Safety Reminders

1. **WIRED LAMANG ANG FLASH.** Bluetooth adapters ay **HINDI** ginagamit para sa ROM writing. Ang K-Line USB adapter na nakakonekta via OTG cable lamang ang ginagamit para sa flash.

2. **HUWAG KAILANMAN** mag-flash nang walang ECU backup. Ang backup ay awtomatikong sine-save ng app bago ang bawat flash — siguraduhing **"Backup saved"** ang lumabas sa progress screen bago magpatuloy.

3. **Ang PROCEED keyword** ay para sa seryosong okasyon. Kung pumipili ka ng Racing, Drag, o Aggressive VVA preset, dapat alam mo kung ano ang ginagawa mo — tamang fuel grade, tamang hardware mods, tamang kondisyon ng motor.

4. **Ang VVA transition zone** (5,800–6,500 RPM sa Aerox 155) ay espesyal na sensitive. Huwag payatan ang VVA zone — kailangan ng kahit +6% enrichment para sa maayos na power delivery sa cam switch point.

5. **Kung may knock:** ihinto agad ang lahat. Ang detonation ay makapagpa-pitted ng piston sa loob ng ilang minuto sa mataas na RPM.

6. **Ang UNVERIFIED na ECU** ay nangangahulugang ang ROM offsets ay **community estimates lamang** — hindi pa nakumpirma sa actual na hardware. Ang mga preset ay may built-in na safety clamps, pero hindi ito 100% garantisado hanggang VERIFIED ang ECU.

7. **Ang app** ay isang propesyonal na tool — hindi ito para sa mga hindi trained na gumagamit. Ang maling paggamit ay maaaring magdulot ng permanenteng engine damage o sirang ECU.

8. **Palaging panatilihin ang huling 3 backups** (awtomatiko ang app). Kung may lumang backup na gusto mong i-restore, pumunta sa Settings → ROM Backups.

9. **Para sa unang flash sa isang ECU unit:** Gumawa muna ng **1-cell test change** — palitan ng maliit na halaga ang isang cell sa idle zone, i-flash, i-verify na nag-boot ang motor, at i-check ang `recordSuccessfulFlash()`. Pagkatapos nito, matitiyak mo na gumagana ang buong pipeline bago mag-apply ng mas malaking changes.

10. **Kung hindi sigurado — huwag mag-flash.** Mas mura ang isang araw ng pag-aaral kaysa bagong ECU.

---

## 22 — Paano Gumagana ang Buong Sistema

> Plain-English (Taglish) na paliwanag ng buong ECU remap pipeline — mula sa pag-plug ng cable hanggang sa naka-reflash na ECU.

---

### 22.1 — Ano ang Nangyayari Kapag Nag-Remap Ka?

Sa madaling salita: **binabago mo ang isang memory chip sa loob ng ECU.**

Ang ECU (Engine Control Unit) ay isang maliit na computer na nagkokontrol ng injection timing, ignition timing, at lahat ng engine parameters. Sa loob nito ay may **ROM** — isang flash memory na naglalaman ng lahat ng "recipe" ng engine: gaano karaming gasolina ang i-inject sa bawat RPM at throttle position, kailan mag-fire ng ignition, at iba pa.

Ang remap ay:
1. **Basahin** ang ROM (64KB sa Click, 128KB sa Aerox)
2. **Baguhin** ang ilang values sa loob (fuel map, ignition map)
3. **I-flash pabalik** ang bagong ROM sa ECU

Ganun lang kasimple. Ang lahat ng ibang ginagawa ng app ay para masiguro na **ligtas** at **tama** ang paggawa nito.

---

### 22.2 — Ang Physical na Koneksyon

```
┌─────────────────────────────────────────────────────────────────┐
│                   HARDWARE CONNECTION CHAIN                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Android Phone o Tablet                                        │
│   ┌──────────────────┐                                          │
│   │  MotoRemap Pro   │                                          │
│   │  (ito ang app)   │                                          │
│   └────────┬─────────┘                                          │
│            │ USB-C OTG cable                                    │
│            ▼                                                    │
│   ┌──────────────────┐                                          │
│   │  OpenPort 2.0    │  ← USB K-Line adapter                   │
│   │  (o katulad)     │    (₱2,500 – ₱4,000)                   │
│   └────────┬─────────┘                                          │
│            │ Diagnostic cable                                   │
│            ▼                                                    │
│   ┌──────────────────┐                                          │
│   │  3-pin o 4-pin   │  ← Honda diagnostic port                │
│   │  OBD connector   │    (sa ilalim ng seat o near battery)   │
│   └────────┬─────────┘                                          │
│            │ K-Line wire (single wire, half-duplex)             │
│            ▼                                                    │
│   ┌──────────────────┐                                          │
│   │   ECU ng Motor   │  ← Keihin PGM-FI (Click 125i)          │
│   │                  │    Shindengen RH850 (Aerox 155)          │
│   └──────────────────┘                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Bakit hindi pwede ang Bluetooth para sa flash?**

Ang Bluetooth OBD adapters (ELM327, Vgate, OBDLink) ay gumagamit ng intermediate processor na nagco-convert ng K-Line signals papuntang AT-commands. Ang conversion na ito ay nagdadagdag ng **random na latency** — minsan 5ms, minsan 50ms. Sa ROM writing, kailangan ng **exact na timing** sa bawat byte. Kahit isang timeout error ay pwedeng mag-brick ng ECU. Kaya ang **WIRED USB lamang** ang ginagamit para sa flash.

Ang Bluetooth ay ginagamit lang para sa **live diagnostics** — basahin ang RPM, AFR, knock, at iba pang sensor data habang tumatakbo ang motor.

---

### 22.3 — Ang 10-Step na End-to-End Flow

#### Step 1: Plug In at I-Power ang ECU

I-connect ang OpenPort 2.0 sa Android phone via USB OTG. I-connect ang kabilang dulo sa diagnostic port ng motor. I-on ang ignition key — **huwag simulan ang motor**, key-on lamang para mag-power ang ECU.

#### Step 2: Fast-Init — Gisingin ang ECU

Ang app ay nagpapadala ng **KWP2000 Fast-Init** signal — isang 25ms LOW pulse sa K-Line. Ito ang "tawag" sa ECU para sabihing "may gustong makipag-usap sa iyo."

Tumutugon ang ECU ng **Key Bytes** (0x8F 0xEA o katulad) — ito ang pagsabi ng ECU: "Handa na ako, ito ang aking protocol parameters."

#### Step 3: Security Access — Seed → Key

Hindi agad nagbibigay ng full access ang ECU. Nagpapadala ito ng **random seed** (halimbawa: `0xA3 0x7F`). Kailangang kalkulahin ng app ang tamang **key** gamit ang algorithm ng ECU manufacturer:

- **Keihin (Click 125i):** XOR + bit rotation
- **Shindengen RH850 (Aerox 155):** proprietary algorithm

Kung tama ang key, binubuksan ng ECU ang lahat ng services — kasama na ang ROM read at ROM write.

#### Step 4: ROM Read — I-Download ang Buong Memory

Gamit ang **Service 0x23 (Read Memory by Address)**, nagre-request ang app ng ROM data sa 128-byte chunks:

```
Request:  [0x23] [address_high] [address_mid] [address_low] [length]
Response: [0x63] [128 bytes ng data]
```

Para sa 64KB ROM (Click): **512 requests** = ilang minuto
Para sa 128KB ROM (Aerox): **1,024 requests** = ilang minuto

Habang nagda-download, ipinapakita ng app ang progress bar. Pagkatapos, sine-save ang buong ROM bilang **backup file** na may SHA-256 fingerprint — ito ang "insurance" mo kung may masira.

#### Step 5: ROM Validation

Bago ipakita ang map editor, sinisigurado ng app na:
- Tamang laki ang ROM (64KB o 128KB)
- Hindi lahat zero (brick signal)
- Hindi lahat 0xFF (empty chip)
- May sapat na entropy (random-looking data = real ROM)
- Walang repeating 256-byte blocks (corrupted flash signal)

Kung may nadetektang problema, **BLOCKED** ang lahat ng edit — hindi mo pwedeng baguhin ang isang malamang na corrupted ROM.

#### Step 6: Map Editing

Bukás na ang **Map Editor**. Nakikita mo ang fuel map at ignition map bilang 12×12 (Click) o 16×16 (Aerox) grid ng mga numbers.

- **Fuel map:** Mga values sa tono ng AFR target — gaano karaming gasolina ang i-inject
- **Ignition map:** Degrees ng ignition advance — kailan mag-fire ng spark

Bawat cell ay may color coding:
- 🟢 Green = ligtas na range
- 🟡 Yellow = borderline
- 🔴 Red = BLOCKED — masyadong lean o masyadong advanced, maaaring mag-cause ng engine damage

Pwede ring gumamit ng **AI Tuning Assistant** (Claude API) para sa mga suggestion, o mag-apply ng pre-built **Customer Preset** (Stock → Mild → Performance → Racing).

#### Step 7: Checksum Correction

Pagkatapos mag-edit, **invalid na ang checksum** ng ROM. Ang checksum ay isang numero sa dulo ng ROM na nagpapatunay na hindi corrupted ang data.

Awtomatikong kinalkula ng app ang tamang bagong checksum:
- **Click 125i:** Additive byte sum, ino-overwrite sa `0xFFFF`
- **Aerox 155:** CRC-16, ino-overwrite sa checksum region

Kung hindi naka-correct ang checksum bago mag-flash, **TATANGGIHAN ng ECU ang ROM** at hindi mag-a-accept ng write.

#### Step 8: Pre-Flash Gate — 8 Safety Checks

Bago papayagan ang flash, sinisigurado ng app ang 8 kondisyon:

| # | Check | Bakit |
|---|---|---|
| 1 | USB wired adapter | Bluetooth = hindi pwede, kailangan ng exact timing |
| 2 | Battery ≥ 12.4V | Kung maubusan ng power sa gitna ng flash = bricked ECU |
| 3 | RPM = 0 | Hindi pwede mag-flash habang tumatakbo ang motor |
| 4 | Coolant < 40°C | Hot ECU = unstable flash memory writes |
| 5 | Backup verified | Laging may backup bago mag-overwrite |
| 6 | Checksum valid | Hindi tatanggapin ng ECU ang invalid na ROM |
| 7 | Diff reviewed | Dapat may kamatayang tinitingnan ang tuner bago mag-flash |
| 8 | Safety score ≥ 85% | Lahat ng major checks ay kailangang pumasa |

Advisory (hindi nag-block): Wideband O2 sensor available?

#### Step 9: Flash Write — I-Upload ang Bagong ROM

Gamit ang **Service 0x34 (Request Download)** at **Service 0x36 (Transfer Data)**:

```
0x34 → "Gusto kong mag-write"
ECU → "OK, handa na"
0x36 → [128 bytes ng bagong ROM data]
ECU → "Natanggap, susunod"
... ulit-ulit para sa buong ROM ...
0x37 → "Transfer Complete"
ECU → "Done"
```

Kapag may nasalang ang USB connection sa gitna ng flash — **awtomatikong nag-rollback** ang app at nire-restore ang lumang ROM mula sa backup.

#### Step 10: Readback Verification

Pagkatapos ng flash, bini-basahin ulit ng app ang buong ROM at kinokompara sa na-flash na version:
- Pareho ba ang SHA-256 hash?
- Walang bit flip o corrupted sector?

Pagkatapos: **health check** — ini-initialize ulit ang ECU session at tinitingnan kung nakabukas ito. Kapag pumasa: `recordSuccessfulFlash()` — marked VERIFIED ang unit sa database.

---

### 22.4 — Ang Wideband O2 Sensor — Bakit Kailangan?

Ang app ay may **AFR gauge** mula sa Bluetooth OBD data — pero ito ay **narrowband estimate lamang.**

| | Narrowband (OBD estimate) | Wideband (Innovate LC-2 / PLX SM-AFR) |
|---|---|---|
| Accurate range | Stoichiometric lang (14.7:1 ± 0.3) | 10:1 – 20:1 (buong range) |
| WOT accuracy | ❌ Hindi mapagkakatiwalaan | ✅ Tumpak |
| Lean detection | ❌ Maaaring hindi makita | ✅ Nakikita agad |
| Halaga | Libre (OBD lang) | ₱4,000 – ₱8,000 |

**Ang tunay na validation ay kailangan ng wideband:**
1. I-install ang wideband bung sa exhaust (pagkatapos ng cylinder, bago ng muffler)
2. Kumuha ng dyno run o test ride sa closed road
3. Log ang AFR habang puno ang throttle sa lahat ng RPM ranges
4. Kung may cell na pumunta sa 16.0:1 o mas lean — **MAPANGANIB**, kailangan ng enrichment agad

Ang app ay malinaw na nagba-babala tungkol dito sa Pre-Flash Gate at sa Professional Mode.

---

### 22.5 — Phone vs Laptop — Ano ang Pagkakaiba?

**Ang MotoRemap Pro** ay isang **Android app** — kailangan ng Android phone o tablet para tumakbo.

Kung gusto mong gumamit ng laptop:

```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  Windows Laptop  │──USB──│  OpenPort 2.0    │──K-Line│  ECU ng Motor   │
│  (WinOLS /       │       │  USB K-Line      │        │  (Click/Aerox)   │
│   ECUFlash)      │       │  Adapter         │        │                  │
└──────────────────┘       └──────────────────┘        └──────────────────┘
```

**Parehong OpenPort 2.0 adapter** ang ginagamit — pagkakaiba lamang ay kung saan nakakonekta:
- **Android app:** Phone + USB OTG + OpenPort 2.0 → ECU
- **Laptop software:** Laptop USB + OpenPort 2.0 → ECU

Sa kasalukuyan, **Android lamang** ang suportado ng MotoRemap Pro. Ang laptop/desktop version (Phase 8) ay nasa roadmap na gumagamit ng Flutter Desktop + J2534 API para direktang makipag-usap sa OpenPort 2.0 sa Windows.

---

### 22.6 — Buod ng Buong Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    MOTO REMAP PRO — SISTEMA                     │
├─────────────┬───────────────────────────────────────────────────┤
│ TRANSPORT   │ USB K-Line (KWP2000 / ISO14230-4, 10400 baud)     │
│             │ Bluetooth OBD (ELM327 — diagnostics ONLY)         │
├─────────────┼───────────────────────────────────────────────────┤
│ PROTOCOL    │ Fast-Init → Security Access → ROM Read / Write    │
│             │ Service 0x10 (start session)                      │
│             │ Service 0x27 (seed→key security access)           │
│             │ Service 0x23 (read memory by address)             │
│             │ Service 0x34 / 0x36 / 0x37 (download + transfer) │
├─────────────┼───────────────────────────────────────────────────┤
│ BINARY      │ ROM parse → 12×12 / 16×16 maps                    │
│             │ Edit cells → safety clamp → checksum correct      │
├─────────────┼───────────────────────────────────────────────────┤
│ SAFETY      │ ROM integrity (5 checks) → Pre-flash gate (8)     │
│             │ Backup + SHA-256 readback verify                  │
│             │ Rollback on USB disconnect                        │
├─────────────┼───────────────────────────────────────────────────┤
│ VALIDATION  │ Wideband O2 post-flash AFR check                  │
│             │ Knock monitor (audio) during test ride            │
│             │ Dyno run for full load confirmation               │
└─────────────┴───────────────────────────────────────────────────┘
```

**Sa isang linya:** Binabasa ng app ang ROM ng ECU, binibigyan ka ng tool para baguhin ang fuel at ignition tables, sinisigurado na ligtas at valid ang lahat ng changes, at ino-overwrite ang ROM ng ECU — gamit ang parehong protocol na ginagamit ng OpenPort 2.0 sa lahat ng propesyonal na tuning software.

---

*MotoRemap Pro — Para sa mga propesyonal na mekaniko at tuner sa Pilipinas.*

*Phase 7 — 2026-05-26*
