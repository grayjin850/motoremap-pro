# MotoRemap Pro — Complete Step-by-Step Tutorial

**Para sa mga propesyonal na mekaniko at motorsiklo tuner**

---

## Recommended Hardware

### Android Device
| Option | Minimum | Recommended |
|---|---|---|
| Android | 8.0 (API 26) | 10+ |
| RAM | 2 GB | 4 GB |
| Screen | 5" phone | 8–10" tablet (para makita ang gauges nang mas malinaw) |
| Storage | 500 MB free | 1 GB free |

**Best tablet picks (2024–2025):**
- Samsung Galaxy Tab A9 (8.7") — magaan, maliwanag ang screen, P6,000–P7,500
- Lenovo Tab M10 Plus (10.6") — malaking screen, mahusay na baterya, P6,500–P8,000
- Redmi Pad SE (11") — value pick, P5,500–P7,000

### OBD-II Bluetooth Adapter (ELM327)
| Adapter | Compatibility | Rekomendasyon |
|---|---|---|
| Viecar ELM327 v2.1 BT | Maganda para sa Yamaha/Honda FI | ✅ Top pick |
| KOBRA OBD2 Bluetooth | Wide compatibility | ✅ Reliable |
| Generic v1.5 (blue chip) | Minsan may bug sa ISO 15765-4 | ⚠ Avoid clones |
| OBDLink LX | Premium, wide support | ✅ Best pero mahal |

**Mahalagang tandaan:** Gamitin lamang ang **Bluetooth Classic** (Hindi BLE/Bluetooth LE) na adapter. Ang karamihang Yamaha at Honda FI bikes sa Pilipinas ay ISO 15765-4 (CAN Bus) o ISO 14230 (KWP2000).

### Flash Tool Hardware (Para sa Actual ECU Flash)
Ang app ay isang **reference/safety tool lamang** — hindi ito direktang nagfo-flash ng ECU. Para sa actual flashing, kailangan mo ng:

| Brand | Tool | Gumagana Para Sa |
|---|---|---|
| Yamaha | YSST (Yamaha Substation Special Tool) | Yamaha Aerox, NMAX, MT-15 |
| Yamaha | DiagBox / YDS-Express | Lahat ng Yamaha EFI |
| Honda | Honda HDS (Honda Diagnostic System) | Honda CBR150R, CB150R, Click |
| Universal | Flashtec K-TAG | Multi-brand, propesyonal |
| Universal | Alientech KESSv3 | Multi-brand, opisyal na tool |
| Budget | TuneECU (para sa Triumph/KTM) | Ilang European brands |

---

## Overview ng Workflow

```
Pumili ng Motor → Pre-Remap Check → Piliin ang Profile → 
Tignan ang Maps → Live Monitor → Post-Remap Verify → Save Session
```

---

## STEP 1 — I-install at I-buksan ang App

1. I-install ang **MotoRemap Pro** APK sa iyong Android device.
2. I-tap ang icon para buksan. Makikita mo ang **Splash Screen** na may logo at version.
3. Hihintay ng ilang segundo, pagkatapos ay awtomatikong mapupunta sa **Home Screen**.

---

## STEP 2 — Pumili ng Motorsiklo

**Saan ka mapupunta:** Home Screen → "Piliin ang Motorsiklo" button

1. I-tap ang **"Piliin ang Motorsiklo"** sa Home Screen.
2. Makikita mo ang listahan ng mga suportadong modelo:
   - Yamaha Aerox 155 VVA
   - Yamaha NMAX 155 VVA
   - Yamaha MT-15 VVA
   - Honda CBR150R DOHC
   - Honda CB150R DOHC
   - Honda Click 125i
   - Yamaha R3 DOHC 321cc
3. I-tap ang modelo ng motor na nasa harap mo.
4. Makikita ang **detalye ng motor**: displacement, compression ratio, VVA status, stock rev limit, at safe AFR range.
5. I-tap ang **"Piliin ang Motor na Ito"** button (orange button sa baba).
6. Awtomatikong babalik sa Home Screen. Makikita mo na ang pangalan ng motor sa itaas.

> **Tip:** Ang pagpili ng tamang motor ay kritikal. Ang safety limits (maxTimingAdvance, safeAfrMin/Max) ay base sa compression ratio ng bawat modelo.

---

## STEP 3 — Pre-Remap Safety Check

**Saan ka mapupunta:** Home Screen → "Pre-Remap Check" button

Ang Pre-Remap Check ay binubuo ng tatlong bahagi. Dapat maabot ang **85 points o mas mataas** bago magpatuloy.

### 3A — Fault Code Scan

1. I-tap ang **"I-scan ang Fault Codes"** button.
2. Makikita ang **Fault Code Screen**.
3. Kung konektado ang OBD adapter, awtomatikong mag-i-scan.
4. Kung walang OBD, i-input nang manu-mano ang bilang ng fault codes.
5. I-tap ang **"Bumalik"** para dalhin ang resulta sa Pre-Remap screen.

**Scoring:**
- 0 fault codes: walang deduction
- 1–2 fault codes: -20 bawat isa (warning zone)
- 3+ fault codes: **automatic BLOCK** — resolbahin muna bago magpatuloy

### 3B — Engine Warm-Up

1. I-konekta ang OBD adapter (kung available). Lalabas ang live coolant temperature.
2. Paandarin ang motor at hintayin na maabot ang **70°C** ang coolant temp.
3. Kapag naabot na, lalabas ang green checkmark.
4. Kung walang OBD: i-tap ang **"I-confirm nang Manu-mano"** — iyong responsibilidad bilang mekaniko.

**Scoring:** Hindi warmed up → -15 points

### 3C — Pre-Remap Checklist (7 Items)

I-tick ang bawat item kapag nakumpirma mo na:

| # | Checklist Item | Bakit Mahalaga |
|---|---|---|
| 1 | Nakuha na ang ECU backup | KRITIKAL — walang rollback kung walang backup |
| 2 | Sapat ang gasolina (min. ¼ tank) | Hindi magtatapos ang engine mid-session |
| 3 | Maayos ang baterya (≥12.5V) | Ang mababang voltage ay makakasama sa flash |
| 4 | Okay ang lahat ng electrical connections | Loose ground = corrupt flash |
| 5 | Handa ang flash tool at software | Para hindi ka mahinto sa gitna |
| 6 | Informed ang kliyente sa mga panganib | Para sa proteksyon ng lahat |
| 7 | Nakalagay ang motor sa level na lugar | Para hindi mabuwal habang naka-idle |

**Scoring:** -10 bawat hindi natitick na item (max 7 items)

### Paano Basahin ang Score

| Score | Level | Kahulugan |
|---|---|---|
| 85–100 | ✅ APPROVED (berde) | Pwede nang magpatuloy |
| 70–84 | ⚠ WARNING (dilaw) | Pwede pero kailangan ng extra care |
| 0–69 | 🔴 HARD LOCK (pula) | **Hindi makakarating sa susunod na hakbang** |

4. Kapag **APPROVED** ang score, i-tap ang **"Magpatuloy sa Tune Profiles"**.

---

## STEP 4 — Pumili ng Tune Profile

**Saan ka mapupunta:** Awtomatikong papunta dito mula sa Pre-Remap Check

Makikita ang mga profile na specifically para sa napiling motor. **Swipe pakaliwa/pakanan** para mag-browse.

### Paano Basahin ang Profile Card

**Itaas ng card:**
- Pangalan ng profile (Taglish)
- Maikling paliwanag kung para saan ito

**Score ring:**
- Tune Safety Score (0–100)
- LIGTAS = 85+, BABALA = 70–84, BLOCKED = 0–69

**Mga specs:**
- **AFR Mid** — Air-Fuel Ratio sa mid-throttle. Normal range: 13.0–14.7 para sa partload.
- **AFR WOT** — Air-Fuel Ratio sa wide-open throttle. Safe range: 12.5–13.5 para sa power.
- **Timing Advance** — Kung ilang degree idadagdag sa stock ignition timing.
- **Rev Raise** — Kung ilang RPM itataas ang rev limiter (kung meron).

**Mga babala (kung lalabas):**
- 🟡 **VVA** chip — ang profile ay nangangailangan ng extra care sa 5,800–6,200 RPM zone.
- 🔴 **Hindi compatible** banner — ang profile ay hindi para sa motor na ito (kailangan ng ibang engine feature).
- ⛽ **RON97/RON95** — kailangan ng mas mataas na octane fuel para sa profile na ito.
- ⚠ **Speed limiter removed** — inalis ang speed limiter sa profile na ito.

### Mga Uri ng Profile (16 Types)

| Icon | Type | Para Saan |
|---|---|---|
| ⚡ | Top Speed | Maximum power output, speed limiter removed |
| ⚖ | Balanced | All-around improvement, pang-araw-araw |
| 🏙 | City Response | Mas mabilis na throttle response sa traffic |
| ⚡ | Throttle Sharpening | Agresibong throttle feel, sport riding |
| 〰 | Throttle Smoothing | Mas malambot na throttle, pang-beginner |
| ⊙ | Idle Quality | Mas maayos na idle, walang hunting |
| 🌿 | Eco | Fuel saving mode, maximum efficiency |
| ↗ | Handling | Balanced for cornering and mid-range torque |
| ⊙ | Endurance | Para sa mahabang biyahe, pang-long distance |
| 📈 | VVA Transition | Optimized para sa VVA crossover zone |
| ↑ | Rev Limiter Raise | Itaas ang rev limit para sa mas mataas na top speed |
| ↓ | Decel Fuel Cut | I-optimize ang deceleration fuel cutoff |
| ❄ | Cold Start | Mas maayos na pag-start sa umaga |
| ⛰ | Altitude Compensation | Para sa mga lugar na mataas (Baguio, etc.) |
| 💨 | Exhaust Tune | Para sa mga motor na may aftermarket exhaust |
| 🏆 | Track | Full aggressive tune para sa race track lamang |

### Pumili ng Profile

1. I-swipe para hanapin ang tamang profile para sa kliyente.
2. I-tick ang **"Nakunan na ng ECU backup"** checkbox sa baba.
3. I-tap ang **"Fuel Map"** o **"Ignition Map"** para makita ang aktwal na mapa.

> **Kung VVA Warning ang lalabas:** Lalabas ang dialog box na nagpapaliwanag ng panganib sa VVA transition zone. I-tap ang "Naintindihan, Magpatuloy" kapag handa ka na.

---

## STEP 5 — Tignan ang Fuel Map

**Saan ka mapupunta:** Tune Profiles → "Fuel Map" button

Makikita ang isang **color-coded grid** ng fuel injection values:

- **Rows** = Load (MAP kPa), ibaba = mababa, itaas = mataas
- **Columns** = RPM, kaliwa = mababa, kanan = mataas
- **Kulay**: 🟢 berde = safe, 🟡 dilaw = babala, 🔴 pula = detonation risk

**Paano basahin:**
- Hanapin ang cell na may pinakamataas na load at pinakamataas na RPM.
- Ito ang WOT (Wide Open Throttle) na area — dito dapat ang pinaka-mayaman na mixture (pinakamababang AFR value = mas maraming gasolina).
- Ang idle area (mababang load, mababang RPM) ay dapat lean-to-stoichiometric (13.5–14.7).

I-tap ang **"Bumalik"** para makabalik sa profile selection.

---

## STEP 6 — Tignan ang Ignition Map

**Saan ka mapupunta:** Tune Profiles → "Ignition Map" button

Katulad ng Fuel Map ngunit para sa ignition timing:

- **Mas mataas na halaga** = mas maaga ang spark (mas aggressive)
- **Pula na cells** = nasa o lampas na sa maxTimingAdvance ng motor (BAWAL na zone)
- **VVA transition zone** (5,800–6,200 RPM) ay may espesyal na highlight sa mga VVA bikes

**Tandaan:** Ang maxTimingAdvance ay computed mula sa compression ratio:
- 11.5:1 o mas mataas → max +3°
- 11.0:1 hanggang 11.4:1 → max +4°
- Mas mababa sa 11.0:1 → max +5°

**Hindi ito pwedeng baguhin ng admin settings.** Ito ay hard safety floor.

---

## STEP 7 — Live OBD Monitor

**Saan ka mapupunta:** Home Screen → "Live Monitor" button

### I-konekta ang OBD Adapter

1. I-pair ang ELM327 adapter sa Bluetooth settings ng Android device.
   - Default PIN ng karamihang ELM327: **1234** o **0000**
2. Bumalik sa app at i-tap ang **"Live Monitor"** sa Home Screen.
3. Makikita ang status bar sa itaas: "OBD Connected" (berde) o "OBD Disconnected" (kulay-abo).

### Mga Gauge na Makikita

| Gauge | Normal Range | Babala | Kritikal |
|---|---|---|---|
| RPM | 1,000–8,000 | 8,000–10,000 | 10,000+ |
| TPS | 0–100% | — | — |
| AFR (est.) | 13.0–14.7 | 12.0–13.0 o 15.0–16.0 | <12.0 o >16.0 |
| Coolant Temp | 70–95°C | 95–105°C | 105°C+ |
| Battery | 12.5–14.5V | 11.5–12.5V | <11.5V |
| MAP Sensor | 20–100 kPa | — | — |
| **Knock Retard** | **0°** | **0.1–3°** | **>3° = STOP AGAD** |

### Ang Knock Retard Gauge (Kritikal!)

Ang **Knock Retard** (PID 01A6) ay nagpapakita kung ilang degree ang binu-bura ng ECU dahil sa detonation/knock.

- **0°** = Walang knock, ligtas
- **>0°** = May knock na nakita ng ECU — **warning ang lalabas**
- **>3°** = Seryosong knock — **RED SCREEN ang lalabas na mag-o-override sa buong display**

> **KUNG MAY RED SCREEN NG KNOCK:**
> 1. IHINTO ang remap session ngayon din.
> 2. Ibaba ang timing advance sa profile.
> 3. Suriin ang gasolina — baka kailangan ng mas mataas na octane.
> 4. I-check ang compression ratio at kondisyon ng piston.
> 5. Huwag magpatuloy hanggang 0° na ang knock retard.

**Tandaan:** Hindi lahat ng motorcycle ECU ay sumusuporta sa PID 01A6. Kung "--" ang lalabas sa Knock Retard gauge, normal lang ito — ang ECU ng motor ay hindi nag-re-report ng knock data via OBD.

### Pag-record ng Log

1. I-tap ang ● (record) button para magsimula ng data logging.
2. I-tap ang table icon sa itaas para lumipat sa log view.
3. Makikita ang timestamp, RPM, TPS, temp, voltage, O2 voltage, at knock retard para sa bawat reading.
4. I-tap ang download icon para mag-export ng CSV file.
5. I-tap ang ■ (stop) button para ihinto ang recording.

---

## STEP 8 — Post-Remap Verification

**Saan ka mapupunta:** Home Screen → "Post-Remap Verify" button

Gawin ito **pagkatapos mag-flash ng bagong ECU map** sa motor.

### Section A — Post-Remap Fault Code Scan

1. I-tap ang **"I-scan ang Fault Codes"**.
2. Makikita ang fault codes na lumabas pagkatapos ng flash.
3. I-tap ang "Bumalik" para dalhin ang resulta.

**Scoring:**
- 0 fault codes: +30 points
- 1–2 fault codes: +15 points (kailangan ng follow-up)
- 3+ fault codes: +0 points (kailangan ng rollback)

### Section B — Cold Start Verification

I-tick ang lahat ng 5 items habang pinapanood ang motor:

1. Motor nag-start nang maayos
2. Idle stable, hindi nagta-tango
3. Walang hunting o rough idle
4. Walang unusual tunog o vibration
5. Walang smoke mula sa exhaust

Lahat ng 5 = **+20 points**

### Section C — Warm-Up Monitor

Hintayin ang motor na umabot sa **70°C** coolant temperature. Kung konektado ang OBD, awtomatiko itong mag-a-advance. Kung hindi, i-tap ang manual confirm button.

**+20 points** kapag naabot ang 70°C.

### Section D — Test Ride Checklist

Pagkatapos ng maikling test ride, i-tick ang 5 items:

1. Low RPM (1–3k) — smooth, walang stutter
2. Mid RPM (3–6k) — walang flat spot
3. High RPM (6k+) — walang knock o ping
4. Speed limiter — nag-a-activate sa tamang speed
5. Engine braking — smooth, walang surge

Lahat ng 5 = **+30 points**

### Section E — Final Assessment

**Piliin ang resulta ng session:**
- ✅ **Matagumpay** — OK ang lahat, hindi kailangan ng follow-up
- ⚠ **May Isyu** — kailangan ng dagdag na adjustment o pagbabalik ng kliyente
- 🔴 **Rollback** — bumalik sa stock ECU map, hindi ligtas ang remap

**Score interpretation:**
| Total | Rekomendasyon |
|---|---|
| 80–100 | Matagumpay |
| 60–79 | May Isyu |
| 0–59 | Rollback |

**Isulat ang impormasyon ng kliyente** (opsyonal):
- Pangalan ng kliyente
- Plate number

**Isulat ang mga tala ng mekaniko**: anumang obserbasyon, isyu, o rekomendasyon para sa susunod na visit.

I-tap ang **"I-save ang Session at Tapusin"**. Ire-redirect ka sa Sessions list.

---

## STEP 9 — Tingnan ang Session History

**Saan ka mapupunta:** Home Screen → "Sessions" button

Makikita ang lahat ng nakaraang sessions:

- **Petsa at oras** ng bawat session
- **Motor** at **variant**
- **Score** ng pre-remap at tune safety
- **Resulta**: Matagumpay / May Isyu / Rollback
- **Pangalan ng kliyente** at plate number (kung nalagay)

I-tap ang kahit anong session para makita ang buong detalye, kabilang ang mga babala na nai-trigger at tala ng mekaniko.

---

## STEP 10 — Admin Settings (Para sa Advanced Users)

**Saan ka mapupunta:** Home Screen → gear icon (itaas-kanan)

**Mahalaga:** Ang admin settings ay para sa pagbabago ng default na values ng profiles. **HINDI** pwedeng baguhin ang safety limits na base sa compression ratio (maxTimingAdvance). Ito ay hard-coded sa bawat modelo.

Maaaring baguhin:
- Default na AFR targets para sa bagong profiles
- Rev limit raise defaults
- Custom profile na pangalan

**Hindi maaaring baguhin:**
- maxTimingAdvance (compression-derived safety floor)
- safeAfrMin at safeAfrMax ng bawat motor
- Knock detection thresholds

---

## Troubleshooting

### OBD Hindi Kumokonekta
1. Siguraduhin na ang ELM327 ay **Bluetooth Classic** (hindi BLE).
2. I-pair muna sa Android Settings → Bluetooth → mag-tap sa device.
3. Kung nakita sa Bluetooth pero hindi gumagana sa app: subukan ang ibang OBD app (OBD Car Doctor) para makumpirma na gumagana ang adapter.
4. Ang ilang Yamaha models (Aerox, NMAX) ay gumagamit ng **ISO 14230** (KWP2000) — siguraduhin na sumusuporta ang adapter mo.

### Walang Fault Codes na Lumabas
- Hindi lahat ng ELM327 ay compatible sa proprietary Yamaha/Honda DTCs.
- Para sa proprietary fault codes, gumamit ng dedicated Yamaha YSST o Honda HDS tool.
- Ang generic OBD-II fault codes (Pxxx) ay makikita ng karamihang ELM327 adapters.

### Profile Hindi Lumalabas
- Siguraduhin na napili ang tamang modelo ng motor.
- Ang mga profile ay specifically para sa isang modelo lamang — hindi sila interchangeable.
- Kung bagong installation: ilaan ng ilang segundo para ma-seed ang database sa unang pagbubukas.

### Knock Retard ay Laging "--"
- Normal ito para sa karamihang motorcycle ECU — hindi sila nag-re-report ng knock data via standard OBD-II PIDs.
- Ang PID 01A6 (Spark Advance) ay optional at maraming ECU ang hindi sumusuporta nito.
- Para sa mas detalyadong knock monitoring, gumamit ng dedicated ECU logger o dyno.

### Safety Score ay Mababa Kahit Okay Naman ang Motor
- I-check ang checklist — siguraduhing nai-tick ang lahat ng items.
- Kung may active fault codes: resolbahin muna bago mag-remap.
- Timing advance ng profile ay baka masyadong agresibo para sa compression ratio ng motor — pumili ng ibang profile.

---

## Safety Reminders

1. **HUWAG KAILANMAN** mag-remap nang walang ECU backup. Kung may mangyaring mali sa flash, kailangan mo ang backup para ma-restore ang stock map.
2. **HUWAG KAILANMAN** gumamit ng profile na para sa ibang modelo ng motor — ang safety limits ay iba-iba.
3. **Ang VVA transition zone** (5,800–6,200 RPM) ay espesyal na sensitive sa mga Yamaha VVA bikes. Mag-monitor nang mabuti sa unang test ride.
4. **Track profiles** ay para sa **RACE TRACK LAMANG** — hindi ligtas para sa pang-araw-araw na paggamit sa kalsada. Kailangan din ng RON97 fuel.
5. **Kung may knock**: ihinto agad ang lahat, huwag magpatuloy. Ang knock ay maaaring magdulot ng nabubulok na piston sa loob ng ilang minuto.
6. Ang app na ito ay **reference at safety tool**. Hindi ito ang aktwal na nag-fla-flash ng ECU — ikaw pa rin ang responsable bilang mekaniko.

---

*MotoRemap Pro — Para sa mga propesyonal na mekaniko at tuner sa Pilipinas.*
