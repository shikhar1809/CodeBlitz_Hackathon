# Session handoff — 26 Sep 2026 (afternoon)

Continue from here. This session ran out of context after parallel agents
were stopped and their branches were merged.

## What this session finished

- Patient scan UI is wired: menu tile **Scan caretaker QR**, camera/stub
  scanner, typed-code fallback, commercial PIN on the patient phone, unlink
  from the account sheet, alerts go to `AppPrefs.alertPhone`.
- Pairing goldens for the patient scan / found / linked screens (EN + HI).
- Accidental `test/failures/*.png` dumps from a WIP merge were removed from
  git and ignored.
- This file plus [`HANDOFF.md`](HANDOFF.md) (project status).

## What was already on `main` before this wrap-up

Merged from agent worktrees (feature commits, not the “WIP snapshot”
messages):

| Area | On `main` |
|---|---|
| Health profile + PM-JAY mock | yes |
| Doctor verification + caretaker notes | yes |
| Offline `SyncQueue` | yes |
| Caretaker type + QR | yes |
| Haptics / pressable | yes |
| Dose alarm screen + demo tools | yes |
| Voice fallback chain | yes |
| Recording pulse / green chip | yes |
| Pharmacy conflict questions | yes |
| Patient pairing logic | yes (`4f64df36`) |

## Do not merge these worktrees

| Worktree branch | Why |
|---|---|
| `worktree-agent-ab7586f11e57b2657` (`f0a0548a`) | Firebase Functions **plus `functions/node_modules`**. Snapshot only. Do not merge. |
| `worktree-agent-a9ed929b1643f7d10` (`28c771e3`) | `pubspec.yaml` only: `cryptography`, `flutter_secure_storage`, `file_picker`, `web`. No vault code. Leave until encrypted-store work starts. |

The other `worktree-agent-*` branches were already merged; leftover “WIP”
commits are merge parents on `main`. Do not rebase them off history unless
you rewrite with the team’s agreement.

## Stopped work — not in this commit

See [`HANDOFF.md`](HANDOFF.md) for the full leftover list. Nothing below
was started in this wrap-up:

- Commercial caretaker **PIN gate** and restricted home (patient still sets
  the PIN; the caretaker home does not lock).
- Encrypted medical vault, restore check, demo user.
- After-verify data wipe.
- Twilio / Cloud Functions / family portal (`myrapidrx.web.app`).
- Stitch plugin (not installed; do not install from an unverified source).
- Live Kokoro measurement on a cold Space (opt-in test exists, skipped).
- Release APK on a real phone.

## How to keep going

```powershell
.\tools\run.ps1 -Device windows
C:\flutter\bin\flutter.bat test
```

`main` is ahead of `origin/main`. Push only when asked.
