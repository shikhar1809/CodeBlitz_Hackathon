# The voice agent — a phone call for the patient no app can reach

> **Status: designed, not built.** Everything below is specified to the point where it can be
> built in a sitting, and the pieces it plugs into — `CaregiverNotifier`, the once-per-slot
> dedupe keys, `AlertOutbox`, the Kokoro cache — exist. Nothing here is running yet.

## Why a phone call

RapidRX already has two outbound channels, and both assume something:

| Channel | Assumes |
|---|---|
| Local notification | The patient has the app, on this phone, and looks at the screen |
| WhatsApp | The *caregiver* has a smartphone and WhatsApp |

Neither reaches the patient who cannot read, does not use WhatsApp, or has a feature phone. A
ringing phone interrupts, needs no literacy and no app, and works on a ₹1,200 handset.

It is the **last rung**, not the first:

```
dose due ──▶ notification at 08:00, nudge at 08:30
                 │ nothing by 09:00
                 ▼
          caregiver told on WhatsApp — "Morning medicines were missed"
                 │ no caregiver number, or the caregiver asks for it
                 ▼
          📞 a call to the patient
                 │ no answer, no keypress — twice
                 ▼
          the caregiver is told the call went unanswered
```

Phoning someone about a tablet they took ten minutes ago is how a family unplugs the phone.

## Two directions

**Outbound — the missed-dose call.** RapidRX rings the patient, says in their language which
medicines are due, and asks for a key. The keypress writes back to the dose log, so answering is
a real confirmation, not a reminder that vanishes.

**Inbound — "what do I take now?"** The patient dials the RapidRX number from any phone and hears
today's plan. The whole app, over a phone line, for someone who never opens it.

## Call flow

```
OUTBOUND
  Twilio rings the patient ─▶ answered
    <Play>   "Namaste. RapidRX se, yeh ek automatic call hai.
              Subah ki dawai ka samay ho gaya: TELMA 40, GLYCOMET 500."
    <Gather numDigits=1 timeout=8>
             "Le li hai to 1 dabaiye. Abhi nahi to 2. Madad chahiye to 9."
      1 ▶ log TAKEN            "Shukriya."                       hang up
      2 ▶ still due            "Theek hai, baad mein yaad dilayenge."
      9 ▶ tell the caregiver   "Aapke gharwaalon ko bata diya gaya hai."
      nothing ▶ ask once more, then "Koi baat nahi." ▶ caregiver told: unanswered

INBOUND
  caller id ─▶ which patient
    1 ▶ today's plan, slot by slot
    2 ▶ the next slot: "Agli dawai raat 9 baje: GLYCOMET 500, khane ke baad."
    unknown number ▶ "Yeh number RapidRX me darj nahi hai." ▶ hang up
```

## A keypad, not speech recognition (ADR-38)

The caller is elderly, often in a noisy room, often hard of hearing, with a regional accent — the
audio speech recognition does worst on. A misheard *"nahi"* logged as **taken** is a silent false
record in a medical log, the single worst failure this product can produce. A keypress cannot be
misheard, costs less, and works on a bad line.

Free speech for the *inbound* "what do I take now?" is a fair phase two: a misunderstanding there
reads the plan back instead of writing to it.

## The voice is Kokoro, not `<Say>`

The app already speaks with Kokoro; the call should sound the same, or it sounds like a robocall
from someone else. Sentences come from the Kokoro cache as WAV, are hosted at a public URL, and
are played with `<Play>`. If the cache misses or the Space is asleep, `<Say language="hi-IN">`
is the fallback. The fixed phrases are generated the night before; only the medicine list varies.

## What the agent never does

1. Never gives medical advice. It reads back what a person already approved.
2. Never says why a medicine was prescribed unless the doctor's own words were captured — and
   then it quotes them.
3. Identifies itself at once: "RapidRX se, yeh ek automatic call hai."
4. Never claims to be a medical or emergency service. Pressing 9 tells the **caregiver**.
5. No calls between 22:00 and 07:00. A night-slot miss waits for the morning.
6. At most one call per slot per day, on the existing `date/slot/kind` dedupe key, and a hard
   cap of about twenty calls a day.
7. Hangs up politely after two unanswered prompts.
8. Opt-in, chosen during onboarding beside voice help, and switchable off.

## The honest part: it needs a backend

This is the first thing in RapidRX that is not offline-first. Twilio must reach a public HTTPS
webhook when a call connects, and a phone in a pocket cannot serve one.

| Option | When |
|---|---|
| Firebase Cloud Functions | The real answer, beside the Firestore migration (ADR-6) |
| Node/Express + a tunnel | The hackathon answer: twenty minutes, one URL |

```
POST /voice/dose            call connected   → prompt + <Gather>
POST /voice/dose-response   <Gather> action  → log the keypress, reply
POST /voice/inbound         inbound call     → identify the caller, offer the menu
POST /voice/inbound-menu    <Gather> action  → read the day, or the next slot
POST /voice/status          Twilio status    → no-answer / busy / failed → tell the caregiver
```

Every webhook validates `X-Twilio-Signature`: an unsigned POST to a public URL could otherwise
write a false "taken" into someone's medical log.

**The phone owns the dose log.** The webhook writes a keypress to a shared record; the app
reconciles it on next open, exactly as it already reconciles missed doses. If they disagree, the
phone wins for "taken" and the call wins for nothing — a webhook replay must never undo a
confirmation.

## The Dart side

```dart
enum CallOutcome { placed, notConfigured, outsideCallingHours, alreadyCalled, failed }

class VoiceCallChannel {
  /// 07:00–22:00 only. A reminder is not worth waking someone for.
  static bool withinCallingHours(DateTime at) => at.hour >= 7 && at.hour < 22;

  Future<CallOutcome> callAboutSlot({
    required String phone, required DoseSlot slot, required String patientId,
  });
}
```

It sits beside `WhatsAppAlerts`, behind `CaregiverNotifier`, and inherits the dedupe and the
outbox. Placing a call is `POST …/Calls.json` with the same Basic auth as WhatsApp, and
`MachineDetection=Enable` so a voicemail box is not a person who declined to press a key.

## Before a live demo

- A Twilio **trial** account only calls verified numbers. Verify both demo phones the night
  before — this cannot be fixed from the stage.
- A trial call plays Twilio's own preamble first. Know it is coming.
- A US Twilio number calling an Indian mobile needs no regulatory paperwork.
- Keep a call under ~45 seconds; the script already does.

## Tests it would ship with

| Test | Covers |
|---|---|
| `withinCallingHours` | 06:59 no, 07:00 yes, 21:59 yes, 22:00 no |
| TwiML builder | the XML, in both languages |
| Keypress | 1 logs taken, 2 does not, 9 tells the caregiver, anything else re-prompts |
| Escalation | no caregiver number still calls; a slot already taken never calls |
| Dedupe | two runs place one call |
| `Calls.json` | `To`, `From`, `Url`, and the auth header |
| Signature | a bad `X-Twilio-Signature` is rejected |
