# RapidRX — project handoff

Team AfterBurners · Hack-e-Awadh · PS-01  
Repo: https://github.com/shikharshahi/RapidRX-Hack-E-Awadh  
Local Flutter: `C:\flutter\bin\flutter.bat` (not on PATH). Use `tools/run.ps1`
and `tools/web.ps1`.

Read this, then [`README.md`](../README.md), [`DECISIONS.md`](DECISIONS.md),
[`GOTCHAS.md`](GOTCHAS.md), [`RUNBOOK.md`](RUNBOOK.md),
[`VOICE_AGENT.md`](VOICE_AGENT.md).

---

## What the product is

Four sources (doctor words, prescription photo, pharmacy bill, chemist note)
cross-check. The merge engine never silently picks a side and never invents a
dose. Verified medicines become a schedule, reminders, a dose log, and
WhatsApp alerts to the linked caretaker.

House rules that still apply:

- Every user-facing string through `AppStrings` (English + Hindi), or a
  feature extension (`strings_*.dart`).
- Large, senior-friendly UI (`OnboardingScaffold`, `BigTextField`,
  `BigChoiceTile`, `OptionalTag`).
- Logic in controllers/stores, not widgets.
- Platform code is `_io.dart` / `_stub.dart`.
- **Never silently pick between sources. Never invent a dose.**

There is still **no backend** for pairing, OTP, or medical records. UI says
“Demo” where that matters.

---

## Done on `main` (shippable for a hall demo)

### Onboarding and health

- Order: language → voice → phone + OTP (`1234`) → name → PIN → **role**.
- Patient: `HealthProfileScreen` (age required; height/weight/Ayushman
  optional). `MockPmjayClient` only — no real PM-JAY.
- Caretaker: family vs paid → QR (`qr_flutter`, 15 min, checksum) →
  confirm with the 4-digit code from the patient’s phone (`PairingChannel`).

### New prescription

- Doctor verification: Doctor checklist vs Me, “Not provided”, caretaker
  note + Low/Medium/High.
- Combined photos, chemist step, on-device extract, medicine cards,
  placement, approve.
- Pharmacy: Dart conflict finder + a question dialog (pick A / pick B /
  neither / not sure). “Not sure” stays red.
- Recording: pulsing red while listening, green chip with duration,
  amber if too short/silent.

### Daily use

- Schedule, take-dose with two gates, month calendar.
- Offline save + `SyncQueue` drain on reconnect; visit sync chip.
- Dose **alarm screen** (full-screen intent on Android), Yes / Later.
  Demo tools behind `DevFlags.demoTools` — a demo never writes the log.
- Voice: cached Kokoro → live Kokoro (~4 s first byte) → device TTS →
  on-screen text. Debug status line in debug builds.

### Pairing (patient phone)

- Menu tile **Scan caretaker QR** (under New / My / Schedule).
- `mobile_scanner` on Android; stub = type the code (web/desktop/tests).
- Commercial: patient sets a 4-digit PIN (hashed like `AppPrefs.hashPin`).
- Linked caretaker shown in the account sheet; unlink is explicit.
- WhatsApp alerts use `alertPhone` (linked caretaker, else old backup).

### Feedback

- Shared `Haptics` + `Pressable`. Tests stub haptics.

---

## Not done — leave these, in this order

Priority for the next session. Do not start 5–8 until 1–4 are green.

### 1. Commercial caretaker PIN gate (still Phase 1)

The **patient** sets the PIN at scan time. The **caretaker home does not
ask for it** and does not hide health/Ayushman/photos. Needed:

- PIN entry every time the paid caretaker opens the patient view.
- 5 wrong tries → 5 minute lock.
- Restricted view: today’s doses, schedule, caretaker notes only.

Without a server, copy the PIN hash onto the caretaker phone during the
existing 4-digit confirm, or keep a local demo seam on `PairingChannel`.

### 2. Encrypted local records + restore (~5 s check)

Still in **plain** `shared_preferences` (`MedicineStore`, `DoseLogStore`,
visits). A stopped agent only added vault packages to a **worktree
pubspec** — **do not merge that** until the store exists.

Build `SecureRecordStore`: AES-256-GCM, Keystore data key, PIN wrap
(PBKDF2), one-time migration, backup at `Documents/RapidRX/` via
MediaStore (**no** `MANAGE_EXTERNAL_STORAGE`), web stub in IndexedDB.
Restore screen before language; injectable duration; demo fixture when
nothing is found (`DevFlags.demoRestore`). Never half-load.

### 3. Data wipe after doctor verification

Skippable ~2.5 s screen. Must actually delete transcripts, audio, note
text, OCR temps. Keep structured records. Wait if a Gemini job still
needs the raw clip.

### 4. Twilio missed-dose calls (Functions, not the APK)

Designed in [`VOICE_AGENT.md`](VOICE_AGENT.md). Auth token must never
ship in the client. App-check / shared-secret to Functions. Dedupe per
slot. Demo “Call demo” with a confirm. **Ask before creating a Firebase
project, Blaze, secrets, or `firebase deploy`.**

### 5. Family web portal (`myrapidrx.web.app`)

Overview / alerts / APK download / demo. Minimal cloud copy only (dose
status, names, times, alert events). Update ADR-6. `--pwa-strategy=none`.

A worktree already has `firebase.json` + `functions/` **and a full
`node_modules`**. **Never merge that commit.** Copy source files by hand
if you reuse them.

### 6. Stitch UI

Not installed. Only from an official/verified source; otherwise skip and
keep `app_colors.dart` / `app_theme.dart`.

### 7. Device and live checks (do not claim until run)

- Release APK on Android 11+.
- Alarm over a **locked** screen.
- Kokoro cold vs warm Space, EN/HI, Android and web.
- Restore after uninstall; tampered backup; hex dump unreadable.
- QR pairing on two phones (family and paid).
- Airplane mode visit, then sync.
- Portal + Functions emulator tests.

---

## Tests and honesty

Golden dumps belong in `test/failures/` locally; they are gitignored.
Do not commit them.

Report the `flutter test` count in the README badge after a full run.
Do not claim a phone or Firebase check that was not executed.

Known gaps already in the runbook: OTP is `1234`; pairing has no server;
voice agent not built; missed alerts fire when the app opens; full-screen
alarm not confirmed on a physical device in this repo’s tests; no strip
photo stored for the alarm screen.

---

## Layout (where to look)

```
lib/
  domain/          merge, sig, schedule — pure Dart
  features/
    onboarding/    splash → role → health / caretaker type
    health/        profile + MockPmjayClient
    pairing/       QR, scan, confirm, channel
    wizard/        visit wizard, doctor + pharmacy questions
    recording/     live meter + recorded chip
    doses/         schedule, log, alarm screen
    caregiver/     home, WhatsApp, notes (high first)
    sync/          SyncQueue
  core/voice/      Kokoro chain
  core/feedback/   Haptics, Pressable
  platform/        reminders, scanner, network, OCR
test/              unit, widget, goldens (EN + HI)
docs/              this file, decisions, gotchas, runbook
```

Worktrees live under `.claude/worktrees/` (gitignored). Safe to delete
after you are sure nothing unique remains except the two WIP commits
called out above.

---

## Next commit messages (style)

Short, why not what. Examples already on `main`:

- `Patient scan: link a caretaker from their QR, and remember who they are`
- `Pharmacy questions: when the counter disagrees, ask before anything turns green`

Do not put “WIP (stopped at session limit)” on `main` again.
