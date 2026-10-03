# Winger

**WhatsApp location is a dot nobody is watching. Winger is the one watching, and it talks to you.**

Winger is a voice-first personal safety app for women (India first). It is built by **Team AfterBurners** for CodeBlitz (ElevenLabs track).

It is proactive: Winger notices when something is wrong and asks, so she never has to find and press a button. It is disguised: on the phone it looks like a wallpaper app. It keeps working offline, because every safety path has an on-phone fallback.

> Winger helps you get help faster. It is not a guarantee of safety. In danger, call 112.

**Live demo:** https://wingercodeblitz.web.app. It opens as "Wallpapers". Type `2580` in the search box and press Enter, then Continue → Continue → Finish. Allow the microphone to talk to Riya.

---

## The three-minute demo

1. **The disguise.** The app opens as *Wallpapers*. Type the PIN (`2580` in the demo) in its search box and Winger appears. Long-pressing any wallpaper is a silent SOS.
2. **Active duty.** Tap it and a phone call from "Riya" starts. It looks like the phone's own call screen. Riya is an **ElevenLabs Conversational AI** agent; with no network, an offline companion speaks instead.
3. **Safe phrase.** Mid-call, say *"did you feed the cat"*. The call carries on as normal while guardians get a **silent SMS** with her location and a live tracking link.
4. **Listening.** End the call and Winger goes silent but keeps listening. A scream or "help me" makes it ask **"Are you okay?"**. With no answer it climbs the ladder: **Nudge → Ask → Guardian → 112**.
5. **False alarm.** On the call, open Keypad and dial the PIN, then `#`. Everything stops and guardians are told she is safe. The **duress PIN** (`1379`) looks identical but keeps alerting in secret.

## Features

| | |
|---|---|
| **Wallpaper disguise** | 14 wallpapers drawn in code. The launcher, web title and recent-apps title all say "Wallpapers". |
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
app/                      Flutter (Android + web), portrait, light theme
  lib/core/               pure Dart, unit-tested: ladder, pin_vault, evidence_chain,
                          threat_judge, journey_monitor, companion, help_guide, geo
  lib/services/           platform edges: alerts (SMS/call), voice (TTS), ear (speech),
                          live_agent + chat_agent (ElevenLabs), cloud_service (Firebase), geo
  lib/state/              AppState (ChangeNotifier via InheritedNotifier), WingmanCall
  lib/ui/                 one file per screen
  web/track.html          the guardian's live tracking page
backend/
  functions/index.js      Cloud Functions (asia-south1): `api` + scheduled `deadman`
  firestore.rules         clients have no direct access; everything goes through `api`
firebase.json             Hosting (web app + /t/** tracking) and rewrites /api/** → api
```

**Backend design.** The app never touches Firestore and needs no Firebase SDK or sign-in. It calls `POST /api/session/start`, which returns a session id and a random write key (only its hash is stored). After that it sends `beat` every 15 s with location and status, and finally `end`. The guardian page polls `GET /api/track/<id>`. Firestore rules deny all client reads and writes.

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

## Tests

`flutter test` runs 28 tests. The core engine is covered (ladder, PINs, tamper-evident evidence chain, journey corridor, threat score, companion turn-taking), along with every step of the demo path as a flow test and the Help chat guides.

## Honest limits

- On the phone, listening uses the platform speech recogniser. On web the in-app browser may block the microphone, so the live screen has a **Demo: scream** button.
- SMS and calls are real on Android and simulated (logged) on web.
- The Help chat guides were written from general knowledge and have **not** been reviewed by a lawyer.
- Still to do: a foreground service for screen-off use, and the agent phoning guardians.

---

Team AfterBurners · CodeBlitz 2026
