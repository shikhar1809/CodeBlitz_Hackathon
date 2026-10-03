<p align="center"><img src="brand/winger-mark.svg" width="96" alt="Winger logo"></p>

<h1 align="center">Winger</h1>

<p align="center"><b>WhatsApp location is a dot nobody is watching. Winger is the one watching, and it talks to you.</b></p>

Winger is an **open-source, voice-first wingman**. One engine watches over you, checks in when something seems off, and brings in your people if you don't answer. **Presets** point that engine at one job each, starting with getting home safe (India first). It is built by **Team AfterBurners** for CodeBlitz (ElevenLabs track).

It is proactive: Winger notices when something is wrong and asks, so you never have to find and press a button. It keeps working offline, because every safety path has an on-phone fallback.

> Winger helps you get help faster. It is not a guarantee of safety. In danger, call 112.

**Website:** https://wingercodeblitz.web.app is the intro page, with the Winger Hub download.
**Live demo:** https://wingercodeblitz.web.app/app/. Onboarding comes prefilled, so press Continue → Continue → Finish. Allow the microphone to talk to Riya. The demo PIN is `2580` and the duress PIN is `1379`.

## Presets

| Preset | For | Watches | Checks in by | Brings in | Status |
|---|---|---|---|---|---|
| **Women Companion** | Getting home safe | Continuously, during a journey or Active duty | Call from "Riya", "Are you okay?", PIN | Guardians (SMS + call), then the 112 dialler | Live |
| **Prescription Agent** | Right medicine, on time | Each scheduled dose | "Taken" buttons, per-pill confirm | A nudge at +30 min, then family at +60 min | In progress |
| **ADHD Companion** | Starting and finishing | Each task or time block | "Started yet?", a tiny first step, a body-double call | An opt-in buddy | Coming soon |

Safety always outranks everything else: a dose or task reminder never interrupts, hides or delays a safety alert. Presets may only use actions from an allowlist, and only the built-in safety preset can reach 112.

## Winger Hub

<img src="hub/assets/brand/mark.png" width="48" align="left" alt="">

**Winger Hub turns a spare computer into your household's Winger server.** It is a Flutter desktop app (Windows now, with Linux and macOS from source). It speaks the same API as the cloud backend and serves guardian live links from home. It also runs the dead-man switch and pairs phones with a one-time code.

The Hub's window never shows names, numbers or locations, because a laptop at home is a household screen. **The phone never depends on the Hub:** with it off, every alert still goes out from the phone.

Download it from the [website](https://wingercodeblitz.web.app/#hub), or see [`hub/README.md`](hub/README.md) for setup, the API and the privacy rules.

---

## The demo (Women Companion)

1. **Active duty.** Tap it and a phone call from "Riya" starts. It looks like the phone's own call screen. Riya is an **ElevenLabs Conversational AI** agent; with no network, an offline companion speaks instead.
2. **Safe phrase.** Mid-call, say *"did you feed the cat"*. The call carries on as normal while guardians get a **silent SMS** with her location and a live tracking link.
3. **Listening.** End the call and Winger goes silent but keeps listening. A scream or "help me" makes it ask **"Are you okay?"**. With no answer it climbs the ladder: **Nudge → Ask → Guardian → 112**.
4. **False alarm.** On the call, open Keypad and dial the PIN, then `#`. Everything stops and guardians are told she is safe. The **duress PIN** (`1379`) looks identical but keeps alerting in secret.

## Features

| | |
|---|---|
| **Wingman call** | A Google-Phone-style dialler with a live ElevenLabs voice agent. The agent has `silent_alert` and `alert_guardians` tools. Hold Mute for a silent alert. Keypad, then PIN + `#`, cancels. |
| **Escalation ladder** | Nudge (vibrate), then Ask (full-screen check-in), then Guardian (SMS to all, call the first), then a 112 countdown. |
| **Threat judge** | Heard sounds and phrases feed a fading risk score (20 s half-life). Score ≥ 0.6 asks; ≥ 1.6 alerts. |
| **Safe phrases** | Her own phrases: add, record, test. Matching runs on the phone. |
| **Two PINs** | Salted SHA-256 only. The duress PIN fakes a cancel and alerts covertly; the status line turns yellow. |
| **Blackbox and Locker** | Every 5 s, an AES-256-GCM chunk is chained by SHA-256 hash. Any edit shows as "Changed". There is a "Share proof of integrity" button. |
| **Set route** | OpenStreetMap, Nominatim search and OSRM routing. Winger stays quiet unless she leaves the corridor, stops too long or runs late. |
| **Help chat** | 12 offline step-by-step guides (blackmail, stalking, morphed photos, FIR refused, …) with helpline buttons (112 / 181 / 1930 / 1091). An ElevenLabs text agent tailors a guide when online. |
| **Guardian live link** | *Firebase.* Each session gets an unguessable `/t/<id>` page with a live map, status and timeline. Guardians need no app. |
| **Dead-man switch** | *Firebase.* A scheduled Cloud Function marks a session "phone went dark" after 3 minutes without a heartbeat, and texts guardians if an SMS provider is configured. |

## Architecture

```
app/                      Flutter phone app (Android + web), portrait, light theme
  lib/core/               pure Dart, unit-tested: presets + validator, step ladder, arbiter,
                          clock, schedule, dose_book, pin_vault, evidence_chain, threat_judge,
                          journey_monitor, companion, help_guide, geo
  lib/presets/            preset-specific code (prescription, …)
  assets/presets/*.json   preset files: watch, ladder, check-in, priority, copy
  lib/services/           platform edges: alerts (SMS/call), voice (TTS), ear (speech),
                          live_agent + chat_agent (ElevenLabs), cloud_service (Firebase or Hub), geo
  lib/state/              AppState (ChangeNotifier via InheritedNotifier), WingmanCall
  lib/ui/                 one file per screen
  web/track.html          the guardian's live tracking page
hub/                      Winger Hub: Flutter desktop app with a dart:io HTTP server
  lib/server/             pure Dart: hub_server (API, dead-man, pairing), store (JSON file)
site/                     the landing page served at /
brand/                    the logo (SVG + PNG); tools/make_icons.py renders every app icon from it
backend/
  functions/index.js      Cloud Functions (asia-south1): `api` + scheduled `deadman`
  firestore.rules         clients have no direct access; everything goes through `api`
tools/build_site.ps1      assembles public/: landing at /, demo at /app/, /t/** tracking, Hub zip
firebase.json             Hosting (public/) and rewrites /api/** → api
```

**Backend design.** The app talks to one backend URL, either the Firebase function or a Winger Hub, and both speak the same API. The app never touches Firestore and needs no Firebase SDK or sign-in. It calls `POST /api/session/start`, which returns a session id and a random write key (only its hash is stored). After that it sends `beat` every 15 s with location and status, and finally `end`. The guardian page polls `GET /api/track/<id>`. Firestore rules deny all client reads and writes.

**Privacy.** PINs are stored only as salted hashes. Evidence is encrypted on the phone. Location leaves the phone only while a session runs. The ElevenLabs agents are public and connect by id alone, so **no API key ships in the app or this repo**.

## Run it

Requirements: Flutter 3.47 (Dart 3.13). For the backend, Node 20 and the Firebase CLI.

```bash
cd app
flutter pub get
flutter test
flutter run -d chrome
```

Web is always a demo build: onboarding comes prefilled (PIN `2580`, duress PIN `1379`) and check-ins run every 60 s. For Android:

```bash
flutter build apk --release --split-per-abi --dart-define=WINGER_DEMO=true --dart-define=WINGER_AGENT_ID=<voice agent id> --dart-define=WINGER_CHAT_AGENT_ID=<chat agent id>
```

| `--dart-define` | Meaning |
|---|---|
| `WINGER_DEMO=true` | Prefilled onboarding, 60 s check-ins, simulated walk |
| `WINGER_AGENT_ID` | ElevenLabs voice agent for the call. Empty means the offline companion only. |
| `WINGER_CHAT_AGENT_ID` | ElevenLabs text agent for the Help chat. Empty means bundled guides only. |
| `WINGER_CLOUD_URL` | Backend base URL (default `https://wingercodeblitz.web.app`). Empty turns the cloud off. |

### Backend

```bash
cd backend/functions && npm install && cd ../..
```

```bash
firebase deploy --project wingercodeblitz
```

Optional SMS from the dead-man switch: set `TWILIO_SID`, `TWILIO_TOKEN` and `TWILIO_FROM` on the `deadman` function.

### Winger Hub

```bash
cd hub
flutter test
flutter run -d windows
```

### Website and deploy

`tools/build_site.ps1` builds the web demo with `--base-href /app/`, builds the Hub for Windows and zips it, then assembles `public/`. Agent ids are read from `agents.env` when it is present.

```bash
powershell -File tools/build_site.ps1
```

```bash
firebase deploy --only hosting --project wingercodeblitz
```

To change the logo, edit `brand/winger-mark.svg` and the matching geometry in `tools/make_icons.py`, then run `python tools/make_icons.py`. It rewrites the web, Android and Hub icons.

## Tests

`flutter test` in `app/` The core engine is covered (ladder, PINs, tamper-evident evidence chain, journey corridor, threat score, companion turn-taking), along with every step of the demo path as a flow test and the Help chat guides. `flutter test` in `hub/` drives a real Hub server on a loopback port with a fake clock: the session API, wrong keys, input clamping, the dead-man switch, link expiry, pairing and revocation, and persistence.

## Honest limits

- On the phone, listening uses the platform speech recogniser. On web the in-app browser may block the microphone, so the live screen has a **Demo: scream** button.
- SMS and calls are real on Android and simulated (logged) on web.
- The Help chat guides were written from general knowledge and have **not** been reviewed by a lawyer.
- Still to do: a foreground service for screen-off use, and the agent phoning guardians.
- The phone app reaches a Hub through a build setting (`WINGER_CLOUD_URL`). An in-app Hub address field and phone-side pairing are not built yet, so the Hub accepts unpaired phones by default. Turn that off in its Settings once phones can pair.
- Guardian links from a Hub only work outside the home Wi-Fi when it has a public address, such as a Tailscale Funnel. The Hub does not send SMS itself; the phone does.
- The Windows build is not code-signed, so SmartScreen warns on first run.

---

Team AfterBurners · CodeBlitz 2026
