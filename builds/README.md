# Winger Android builds

| File | For |
|---|---|
| `Winger-arm64-v8a.apk` | Almost every Android phone from the last 7 years (64-bit ARM) |

Install: copy the APK to the phone, open it, and allow "Install unknown apps" for your file manager when Android asks.

Built from `main` with `flutter build apk --release --split-per-abi`. No API keys are inside this APK: on-phone features (prescription reading, reminders, dose log) work without them.
