# Decisions

Why RapidRX is the way it is. Read the relevant entry before changing any of these —
each one is here because the obvious alternative was tried, or thought through, and lost.

---

## The product

### ADR-1 · One Flutter codebase — Android is the product
Flutter 3.47 / Dart 3.13, targeting Android, Windows and web. The APK is what a patient uses;
the Windows and web builds exist so a laptop demo shows exactly what the phone shows.

### ADR-3 · Portrait everywhere
`PhoneShell` frames the app as a 412 × 892 phone on anything wider. A second, wide layout would
be designed once and never used.

### ADR-11 · Onboarding order: identity first, then the role, then role-specific
language → voice → phone + code → name → PIN → **role** → a patient's health profile, or a
caretaker's type and pairing code. Health details only make sense for a patient, so the role
comes before them. The old "family member's number" field is gone: the caretaker's own verified
number arrives in their pairing QR code.

### ADR-39 · Ayushman Bharat is a mock behind an interface
The health screen can look up a PM-JAY card, but there is no PM-JAY integration and there must
not be one without the proper agreements. `MockPmjayClient` is deterministic per ID and the card
says **Demo data**; a real client drops in behind `PmjayClient`. Nothing is saved until the
patient says "Yes, this is me". Age is required; height, weight and the card are optional.

### ADR-19 · The patient lands on a menu, not on today's doses
The first thing a new user needs is to add a prescription; what a returning user needs depends on
the time of day. So the app asks. All three tiles fit without scrolling.

### ADR-23 · The merge engine is plain Dart, and never picks a side
This is the step that decides what reaches a patient's schedule. It is deterministic, inspectable
and identical every run, so no model sits between the evidence and the plan. Where sources
disagree, both are kept and a person decides.

### ADR-29 · Four inputs that cross-question each other
Doctor's words, the prescription photo, the printed bill, the chemist. **Identity** is decided
bill > strip > doctor > prescription, because printed text reads at over 99% on the device and
handwriting at about half. **Timing** is decided doctor > prescription > chemist, because the
bill carries none.

### ADR-31 · The medicine card shows the evidence, not a claim
Every source that mentioned a medicine is quoted in its own words. A red card shows each
conflicting reading side by side and cannot be confirmed until a person picks one.

### ADR-36 · The caregiver gets plain text on WhatsApp, not an app to install
Text arrives on any phone, forwards to a doctor, and pastes into SMS for someone with no
smartphone. Medicine names stay in English letters in the Hindi message: the reader may be
holding the strip.

---

## Accessibility

### ADR-2 · Fonts are bundled, never downloaded
Noto Sans and Noto Sans Devanagari ship in `assets/fonts/`. Runtime Google Fonts would render the
Hindi UI as tofu boxes in a hall with no Wi-Fi.

### ADR-4 · The elderly-first scale lives in `ThemeData`
Body text never below 20pt on a patient screen; every tap target at least 64px. In the theme, so
no screen can quietly break it.

### ADR-12 · Localisation is a typed Dart table
`AppStrings` has a getter per string with English and Hindi side by side. A missing translation
is a compile error, not a blank label on a demo phone.

### ADR-15 · The newest screen owns the voice
`VoiceGuide` holds an owner token. A screen stops the voice on its way out only if it still owns
it; a sentence that finishes loading after its screen has gone is dropped. Without this, a user
who moves quickly hears the previous screen talking over the new one.

### ADR-32 · Kokoro TTS, cached per sentence
Device TTS was robotic and often had no Hindi voice. Kokoro (a public Hugging Face Space) sounds
like a person in both languages. Every sentence is cached on the device, so after one warm
walkthrough the voice works offline. Kokoro → device → silence: silence beats a wrong accent
reading the wrong screen. One failure marks the Space unreachable for the session.

---

## Data and privacy

### ADR-6 · `shared_preferences` now, Firestore for medical data later
This build keeps everything on the phone as JSON. The shapes in `MedicineStore`, `DoseLogStore`
and `VisitRepository` are the documents a Firestore migration would write.

### ADR-14 · Phone, OTP, PIN — all local in this build
The OTP is `1234`, and the screen says so: phone auth needs Firebase's paid plan. The PIN is
stored as a SHA-256 hash, never as itself.

### ADR-20 · A visit is saved after every capture
Not at the end. A phone call or a flat battery mid-visit loses nothing.

### ADR-21 · Consent is a gate, not a checkbox
It is asked before the first capture, in plain words, and nothing is captured on a no.

### ADR-35 · Gemini reads handwriting, and nothing else
The only thing that ever leaves the phone, only after a person presses Read on a card that says
exactly what goes where, and only when online with a key. `gemini-3.8-flash`, temperature 0,
JSON out, four calls per visit, 45 s timeout. Its rows are re-parsed by the same `SigParser` and
land in the same merge: a better reader, not a higher authority.

---

## Extraction

### ADR-25 · The "understanding" step is rules, and says so
Takeaways are produced by `MentionExtractor` + `SigParser`: auditable, instant, no quota, and
nothing invented. The screen says it was read on the phone.

### ADR-27 · Speaking must produce text
Dictation goes through `speech_to_text`. A recording nobody can read cross-checks against
nothing; saving the audio is a separate, optional choice for the family.

### ADR-28 · Photos are read on the device, or the screen says why not
ML Kit on the phone. Everywhere else, `TextRecogniser` returns `unsupported` — never an empty
string, which would be indistinguishable from "your bill was blank".

### ADR-30 · Parser fixes that cross-checking forced out
1. `TELMA 40 TAB` is a strength, not forty tablets: only a single digit or a half can be a count.
2. Bill quantities (`30 NOS`, `1x15`) and prices never land in a name.
3. Double-space columns are cut.
4. `aur` and number words no longer flag clean rows.
5. On a **printed** line, a single digit before `TAB` is a strength (`AMLONG 5 TAB`). Read as a
   count, the line had no strength and no form, and the medicine was dropped from the bill.
6. A sentence that opens with advice ("come back after ten days") is a note, and never attaches
   a duration to the medicine above it.

### ADR-33 · A content gate on every input — that can always be overruled
Strong signals (dosage forms, shorthand, strengths) carry a verdict; weak ones (a word and a
number, a store header) only support one. The words behind a verdict are shown, and every
rejection offers "use it anyway". The bar for speech is lower than for photos.

### ADR-34 · One photo step that reads and labels
Prescription, bill and strips together: find recent, camera, or gallery. Only ticked photos
enter the visit, and only when the step is left. OCR runs once; the text is reused.

---

## Doses and reminders

### ADR-40 · Doctor verification is a checklist, and "not provided" is an answer
Step 2 asks who is verifying. **Doctor** gets one tick per point — name and strength, dose,
timing, food, duration, purpose — each with "Not provided". A row reaches the analysis only when
every point is answered; anything less is an unverified row, left out exactly as an unticked one.
A point marked "not provided" is removed from what the merge sees, so the card shows it missing
rather than guessing it. Verification does not outrank the other sources: a doctor confirming
"morning only" against a prescription reading 1-0-1 is still a red card for a person. **Me** keeps
the tick-and-edit list. A skipped step is recorded on the visit as not provided.

The note for the caretaker (with Low / Medium / High) travels on the prescription record, and a
High note is the first thing on the caretaker's home.

### ADR-41 · Save first, sync later — and nothing late changes a schedule
With no signal, a session is saved on the phone and the person carries on: a banner and one
notification say so, nothing is blocked, and the on-device analysis still gives a result at once.
Work that needs the network — the online handwriting read, the PM-JAY lookup — waits in a
persisted `SyncQueue` and drains in order when the connection returns, retrying with backoff
(15 s doubling, capped at 30 min) and dropping jobs that can never succeed. WhatsApp alerts keep
their own `AlertOutbox` (ADR-36). Anything that arrives after approval is **attached for review**:
a late handwriting reading marks the prescription "new reading to review" and a late PM-JAY card
waits for "yes, this is me". Neither changes the schedule on its own.

### ADR-26 · Two notifications on approval
"Prescription saved" and "Schedule updated" are two different facts.

### ADR-37 · Two reminders per dose, then silence
At the time, and thirty minutes later. By +60 the slot is missed and the **caregiver** is told:
escalation moves to a different person rather than getting louder. Ids come from the slot, so a
re-sync replaces instead of duplicating; every sync is a full replace; confirming a dose cancels
its slot at once. Never for SOS, a finished course, a stopped medicine, or a slot taken.

### ADR-60 · A dose alarm wakes the screen, like an alarm clock
A reminder waiting in the notification shade is easy to miss for the person this app is for. Each
of the two ADR-37 alarms is a **full-screen intent** notification: category *alarm*, on the alarm
audio stream (so "media volume zero" does not silence it), with vibration. `MainActivity` has
`showWhenLocked` and `turnScreenOn`, so the alarm screen opens over the lock screen. Ids, the
two-alarm rule and full-replace syncing are unchanged. The alarms live on a new `dose_alarms`
channel, because Android freezes a channel's sound and importance when it is first created; the
old quiet `dose_reminders` channel is deleted. `USE_FULL_SCREEN_INTENT` is granted by default to
a sideloaded APK; Android 14+ lets a person turn it off per app (the alarm then arrives as a
heads-up, and tapping it opens the same screen), and a Play Store build would have to justify it.

### ADR-61 · The alarm screen asks one question, and "later" writes nothing
The notification carries only the slot and the day (`dose|morning|2026-09-26`); the medicines are
read from the store when the screen opens, so one stopped after the alarm was set is never shown,
and a slot already taken does not ask again. The screen shows each medicine as the strip looks —
its photo when one exists (`ScheduledMedicine.imagePath`; nothing stores one yet), else its form
as a pictogram — the name in English letters, the dose as dots and the food picture, read aloud.
**Yes, taken** writes the same log as the dose screen and cancels the slot's alarms first.
**No / Later** writes nothing: the dose is still due, and a re-sync keeps the +30 nudge if it is
still ahead — never a third alarm. The whole slot is one answer, because a half-answered alarm
is a question nobody is left to ask.

### ADR-62 · Demo tools are a flag, and a demo never writes
`DevFlags.demoTools` shows a small "Demo" link under the patient menu's tiles: show the alarm now,
or ring it in 15 seconds to watch it wake a locked phone. It uses today's nearest slot with its
real medicines, or `DEMO MEDICINE 500` on an empty schedule, and a demo alarm logs nothing,
cancels nothing and tells nobody: a demo "Yes" at 10am must not mark the night dose taken or
message the family. **Turn the flag off for a store build.**

### Missed is derived, never written
Nothing runs at 09:01 to record a miss. Status is computed day to day whenever it is asked for.

---

## Caretaker pairing

### ADR-45 · Pairing is a QR code and a 4-digit code back — no backend, behind an interface
The caretaker says who they are to the patient (family or a paid, non-family caretaker), then
shows a QR code. It carries versioned JSON — `{v, caretakerId, phone, name, type, issuedAt}` —
as `RXC1.<base64url JSON>.<first 8 hex of SHA-256 over that JSON>`. The same text is the "type
or paste" code for a phone with no camera; the caretaker sends it with **Send the code**. A code
works for 15 minutes, then says so and offers **Make a new code** (same caretaker id, new time).

With no server, the patient's phone cannot tell the caretaker's phone that it scanned. So after
a successful scan the patient's phone shows a **4-digit confirmation code**, derived from the
caretaker id (SHA-256, mod 10 000), and the caretaker types it — both phones compute the same
digits offline, and a match proves the patient scanned *this* caretaker's code. A 4-digit code
cannot carry a name, so the caretaker types the patient's name beside it; the patient's success
screen shows both together.

`PairingChannel` is the seam: `LocalPairingChannel` does the above, and a backend replaces it
(the patient's phone posts the link, the caretaker is told, no code to type). The checksum
catches typos and bad scans; it is **not** a signature — anyone can compute SHA-256 — so a
forged code is possible in this build. A real backend signs codes.

"I'll do this later" is remembered, so a relaunch goes to the caretaker home (which offers the
QR again) instead of trapping them on the QR screen.

---

## The voice agent

### ADR-38 · A keypad, not a conversation — and the last rung, not the first
Designed in [`VOICE_AGENT.md`](VOICE_AGENT.md), not built. A misheard "nahi" logged as *taken*
is the worst failure this product could produce; a keypress cannot be misheard.

---

## Feedback

### ADR-55 · Four haptic words, one switch, and a button that gives
Screens never call `HapticFeedback` directly; they call `Haptics` (`lib/core/feedback/haptics.dart`)
with what happened: **tap** (selection click — a tile, Next, Continue), **confirm** (medium
impact — "All taken", Approve, the right OTP, a recording kept), **error** (heavy impact and a
buzz — a wrong OTP or PIN, a missing field, a recording with nothing in it), **alarm** (three
buzzes). One global `Haptics.enabled` switch silences all of it, for a setting, and a test seam
(`debugOverride`, wrapped by `test/support/fake_haptics.dart`) records calls instead of running
the motor. `Haptics.on(callback)` returns null for a null callback, so a disabled button stays
disabled. Primary buttons are wrapped in `Pressable`, which shrinks to 0.97 under the finger via a
`Listener` (outside the gesture arena, so taps and semantics are untouched) and is exactly 1 at
rest, so no golden moves. Saving shows a spinner in the button at once — never a dead tap.
