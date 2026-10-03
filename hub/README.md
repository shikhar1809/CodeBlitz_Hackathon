# Winger Hub

Winger Hub turns a spare computer (an old laptop works well) into your household's Winger server. It is a Flutter desktop app with a built-in HTTP server.

It does the job of Winger's cloud backend at home:

- **Live guardian links.** The phone sends a heartbeat every 15 s. Guardians open `/t/<id>` in any browser to see a live map, status and timeline.
- **Dead-man switch.** If a phone stops checking in for 3 minutes during a session, the session is marked "phone went dark" and the guardian's page turns red.
- **Pairing.** Phones pair once with a 6-digit code that expires after 10 minutes. Only token hashes are stored, and a phone can be removed at any time.

**The phone never depends on the Hub.** With the Hub off, every alert still goes out from the phone by SMS and call.

> Winger helps you get help faster. It is not a guarantee of safety. In danger, call 112.

## Run it (Windows)

1. Unzip `WingerHub-windows-x64.zip` anywhere and run `WingerHub.exe`.
2. When Windows Defender Firewall asks, allow it on **private networks**. Phones on your Wi-Fi need this to reach the Hub.
3. The Hub shows its address (for example `http://192.168.1.20:8787`) and a QR code. Scan the code with your phone to check that it can reach the Hub.
4. Point Winger at that address. Today that is a build setting: `--dart-define=WINGER_CLOUD_URL=http://192.168.1.20:8787`.
5. Keep the laptop plugged in, and set it not to sleep when the lid is closed (Control Panel → Power Options → *Choose what closing the lid does*).

### Guardians outside your home

Links use the home-network address by default, which only works on your Wi-Fi. To reach guardians anywhere, give the Hub a public HTTPS address and enter it under **Settings → Public address**. [Tailscale Funnel](https://tailscale.com/kb/1223/funnel) gives one free, with no domain needed:

```bash
tailscale funnel 8787
```

## Privacy

- The Hub's window and its home page never show names, phone numbers or locations. They show only counts and anonymous events, because the laptop is a household screen. A live session is visible only to the guardians who were sent its link.
- Guardian numbers never leave the Hub, and the tracking API does not return them.
- An ended session's link stops working after 24 hours, and the session is deleted.
- Data lives in a single JSON file under `%APPDATA%\Team AfterBurners\Winger Hub\hub.json`. Writes are atomic.

## API

The Hub speaks the same API as the Firebase backend (`backend/functions/index.js`), so the phone app works with either one.

| Route | Auth | Purpose |
|---|---|---|
| `POST /api/session/start` `{name, kind, guardians[]}` → `{id, key, trackUrl}` | a paired phone's token, or none while *Accept phones that are not paired* is on | Start a live session |
| `POST /api/session/beat` `{id, key, lat, lon, status, note?}` | the session's write key | Heartbeat |
| `POST /api/session/end` `{id, key, reason}` | the session's write key | End it |
| `GET /api/track/<id>` and `GET /t/<id>` | unguessable 128-bit id | The guardian's view |
| `POST /api/pair` `{code, name}` → `{deviceId, token}` | the one-time code | Pair a phone |
| `GET /api/health` | none | Version and uptime only |

Rate limits: 30 session starts per minute and 10 pairing attempts per 10 minutes, per client address.

## Develop

```bash
cd hub
flutter pub get
flutter test
flutter run -d windows
```

`lib/server/` is plain Dart with no Flutter imports, so it can also run headless later. `test/server_test.dart` drives a real server on a loopback port with a fake clock. It also checks that `assets/web/track.html` matches `app/web/track.html`. `tools/build_site.ps1` copies the file across and builds the release zip.

Linux and macOS builds use the same code: `flutter build linux` / `flutter build macos`. They are not packaged yet.
