# RapidRX — reference screenshots

Every image here is a **golden screenshot**: the real app rendered headlessly at phone size
(412×892, taller where a screen scrolls), with the bundled Noto fonts and real data driven through
the real controller. They are not mockups — if the parser or the merge engine changes what a row
says, these pictures change with it.

Regenerate from the repo with:

```bash
flutter test --update-goldens
```

Source of truth: `test/goldens/` in this repository.

The brand marks live in `assets/images/` — `logo_mark.png` (the R★ mark, and the launcher
icon on Android, Windows and web) and `logo.png` (the full lockup).

---

## 01-onboarding/ — nine questions, one decision per screen

| File | Screen |
|---|---|
| `01-splash-english.png` | Logo + tagline *Every dose, on time* — 3s |
| `02-splash-hindi.png` | *हर दवाई, सही समय* — the same 3s, in Hindi |
| `03-choose-language.png` | The only bilingual screen: the user has not chosen yet |
| `04-saving-preference-hindi.png` | 3s loader. **The whole app switches language after this** |
| `05-voice-help-hindi.png` | Voice help — if yes, every screen reads its ask aloud every 10s |
| `06-phone-number.png` | 10 digits, +91 |
| `07-otp.png` | Code is **hardcoded 1234** — no SMS (Firebase phone auth needs Blaze) |
| `08-name-and-backup-number-hindi.png` | Name + **optional backup number** — this is where caregiver alerts go |
| `09-set-pin.png` | 4-digit PIN, stored as a SHA-256 hash |
| `10-role-english.png` / `11-role-hindi.png` | PATIENT / CAREGIVER |

## 02-patient/

| File | Screen |
|---|---|
| `01-menu-english.png` / `02-menu-hindi.png` | The patient lands on a **menu**, not on today's doses |
| `03-prescriptions-empty-hindi.png` | Empty state |
| `04-prescriptions-filled.png` | One card per approved visit |
| `05-visit-capture-english.png` / `06-visit-capture-hindi.png` | The four-capture visit screen |

## 03-wizard/ — adding a prescription, eight steps

| File | Step |
|---|---|
| `step1-doctor-words-english.png` / `-hindi.png` | **1** Speak or write what the doctor said. Skip allowed |
| `step2-takeaways-english.png` / `-hindi.png` | **2** Tick and edit what the phone understood — deterministic rules, not an LLM |
| `step3-photos-labelled.png` | **3** One combined step: prescription + bill + strips, read on device, labelled, *"are these right?"* The holiday photo is turned away **with its reason shown** |
| `step4-pharmacy-page.png` | **4** The pharmacy page — bill plus the chemist's note or voice note |
| `step5-chemist-takeaways.png` | **5** The chemist gets the same checkpoint — a substitution at the counter is exactly what this catches |
| `step6-processing-on-device.png` | **6** Judge → extract → verify, on the device. *(Shown offline; with a key and a connection, a consent-gated "read the handwriting online" card appears here)* |
| `step7-medicine-cards.png` | **7** One card per medicine |
| `step7-medicine-cards-with-sources.png` | **7** The same, with the bill agreeing on one row and contradicting another — the card shows **the evidence, not a claim** |
| `step8-placement-and-approve.png` | **8** Where new medicines sit, with a labelled reason, then Approve |

## 04-daily/

| File | Screen |
|---|---|
| `01-taking-a-dose-hindi.png` | Tick each medicine; **सब ले ली** stays locked until all are ticked |
| `02-schedule-and-calendar-english.png` | Slots with live status + the month calendar |
| `03-schedule-and-calendar-hindi.png` | The same in Hindi |

## 05-caregiver/

| File | Screen |
|---|---|
| `01-caregiver-home-populated.png` | Today per slot, the family number, send status / share plan, the plan in plain words |
| `02-caregiver-home-empty-english.png` | Before any prescription is added |
| `03-caregiver-home-hindi.png` | The same in Hindi |

---

## Two notes for the demo

- The **banner** on the schedule screenshots ("Reminders only work in the Android app") is correct: these are rendered on a desktop test runner, which has no alarm service. On the phone it is absent.
- The screenshots show the state with **no Gemini key configured** — processing runs entirely on the device, which is the honest offline story, and is what the judges should see first.
