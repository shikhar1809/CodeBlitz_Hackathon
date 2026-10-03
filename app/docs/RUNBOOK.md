# Runbook

## Machine

| Need | Version |
|---|---|
| Flutter / Dart | 3.47.2 / 3.13.2 |
| Android | SDK 36, JDK 17, licences accepted (`flutter doctor --android-licenses`) |
| Node | any recent — only for `tools/serve.js` |

`flutter doctor -v` should be green for Android and for Windows or Chrome. On the build machine
Flutter lives at `C:\flutter` and is not on `PATH`; the scripts find it there.

## Keys

The repository is public; no key is ever committed.

```bash
cp tools/keys.example.ps1 tools/keys.local.ps1
```

Fill in what you have. All of it is optional:

| Key | Without it |
|---|---|
| `GEMINI_API_KEY` | The "read the handwriting online" card never appears; everything else runs on the phone |
| `TWILIO_*` | Dose alerts do not send themselves; sharing and "send today's status" open WhatsApp for a person to press send |

The scripts write them to `build/dart_defines.json` (gitignored) and pass
`--dart-define-from-file`. A key built into an APK can be extracted from it: rotate it after the
event. The real fix — a proxy with App Check — is not hackathon work.

## Everyday

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter analyze
```

Goldens are the UI spec. After an intended visual change:

```bash
flutter test --update-goldens
```

## Run

```powershell
.\tools\run.ps1 -Device windows
```

```powershell
.\tools\web.ps1
```

`web.ps1` builds a release with `--pwa-strategy=none` and serves it on `localhost:8080`;
`-NoBuild` serves the last build instantly.

## Build the APK

```powershell
.\tools\run.ps1 -Build apk
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`, debug-signed so it installs
straight onto a demo phone.

## Before the demo

In `lib/core/dev_flags.dart`:

```dart
static const bool alwaysShowOnboarding = false;
static const bool voiceEnabled = true;
```

- [ ] **Warm the Kokoro cache**: online, with voice help on, walk every screen once. If the Space
      is asleep the first line takes ~30 s — do this early. After that the voice works offline
- [ ] Put the Gemini key in `tools/keys.local.ps1`
- [ ] Build the release APK and install it on **both** phones
- [ ] On a real phone, test the camera, the microphone, dictation, ML Kit reading a bill, and
      "find recent photos" — the browser exercises none of these
- [ ] **Watch a reminder fire**: set a medicine for the next slot, lock the phone, wait
- [ ] **Watch the alarm wake a locked phone** — see *Test the dose alarm* below
- [ ] Decide on `DevFlags.demoTools`: on for the demo, **off for any store build**
- [ ] Run the whole flow end to end: onboarding → new prescription → approve → take a dose →
      caregiver home → send status
- [ ] Record a backup video
- [ ] Rotate the Gemini key after the event

## Test the dose alarm on a phone

The full-screen alarm is platform code: no test on a laptop can show it waking a phone.

1. Install the APK. On first open of the schedule, allow notifications and "Alarms & reminders".
2. Android 14+: Settings → Apps → RapidRX → Notifications → allow **full screen notifications**.
   A sideloaded APK normally has it; check anyway.
3. Patient menu → **Demo** → *Dose demo* → **Ring in 15 seconds**. Lock the phone at once
   (screen **off**) and do not open the schedule meanwhile — a sync replaces every alarm.
4. Within ~15 s the screen turns on and the alarm screen shows over the lock screen, ringing on
   the alarm stream and vibrating. With the screen on and unlocked, Android shows a heads-up
   instead — by design; tapping it opens the same screen.
5. Tap **Yes, taken**: a demo writes nothing (the banner says so). For the real flow, add a
   medicine whose slot is a few minutes away, or temporarily change `DoseClock.nominalHour`, lock
   the phone and wait. Then check: **Yes** ticks the slot on the schedule and the +30 nudge never
   rings; **No / Later** leaves the slot due and the nudge rings 30 minutes after the first alarm.
6. Cold start: force-stop the app (Settings → Apps → Force stop), ring the demo again from a
   fresh open, swipe the app away, lock. The alarm must open straight onto the alarm screen.

`adb shell dumpsys notification --noredact | grep -A3 dose_alarms` shows the channel and
whether full-screen intents are allowed.

## Known gaps — say them before anyone finds them

- **No cloud database.** Everything persists on the phone. The migration path is ADR-6.
- **The OTP is `1234`.** Phone auth needs Firebase's paid plan, and the screen says so.
- **Caretaker pairing has no server.** The patient scans the caretaker's QR code, and the
  caretaker types the 4-digit code the patient's phone shows (ADR-45). Nothing travels between
  the phones except what the two people carry; the screens say "Demo".
- **A paid caretaker's PIN is set on the patient's phone, but the caretaker home is not gated
  yet.** Family vs paid is stored; the restricted view is not.
- **Medical records are still plain SharedPreferences.** The encrypted vault and restore
  check are not built. See [`HANDOFF.md`](HANDOFF.md).
- **The voice agent is designed, not built** ([`VOICE_AGENT.md`](VOICE_AGENT.md)), and it is the
  one part that needs a backend.
- **Missed-dose alerts fire when the app opens**, not at the minute a dose is missed.
- **The full-screen alarm has not been seen on a real phone from this build's tests.** Its
  details are unit-tested (full-screen, alarm category, alarm stream, vibration); waking a
  locked phone is checked by hand, above.
- **No strip photo is stored yet**, so the alarm screen shows the form as a pictogram, read from
  the printed name.
- **Reminders, camera, microphone and ML Kit are platform code.** Their decisions are tested on a
  laptop; the handoff to Android must be seen on a phone (the checklist above).

## If you are behind — cut in this order

Chemist audio → every-N-days and SOS → the voice.

**Never cut:** the prescription photo, the verification cards, the red-card lock, the daily tick
and **"सब ले ली"**, the caregiver message, the calendar.
