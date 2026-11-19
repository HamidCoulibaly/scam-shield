# Scam Shield for iPhone

An app plus a call-blocking extension. Each day it downloads `scamlist.json` from your collector, checks it against its `.sha256` file, and hands the numbers to iOS. iOS then **blocks** (silently) or **labels** ("Likely scam…") those callers itself. Numbers you report in the app are blocked straight away.

## Build (first time)

```bash
brew install xcodegen
cd ~/Downloads/scam-shield/ios
xcodegen
open ScamShield.xcodeproj
```
Expected from `xcodegen`: `Created project at …/ScamShield.xcodeproj`.

In Xcode:
1. Click **ScamShield** (blue icon, top left), then for **both** targets (ScamShield and CallBlock) go to **Signing & Capabilities** and set **Team** to your Apple ID (Personal Team, or your paid team).
2. Plug in your iPhone and select it as the run destination at the top. The first time, the iPhone asks you to turn on **Developer Mode** (Settings > Privacy & Security), and then restarts.
3. Press **Run** (⌘R). Expected: "Build Succeeded" and the app opens on the phone.
   - If it says the developer is untrusted: Settings > General > VPN & Device Management > your Apple ID > Trust.
4. On the iPhone: Settings > Apps > Phone > **Call Blocking & Identification** > turn **Scam Shield** on.
5. In the app, tap **Update now**. Expected: Protection **On**, a list version and date, and *Blocked 0 · Labelled 0* (your list is empty for now).

## Test it

Ask someone whose number isn't in your contacts to call you. Add their number in the app under *Report a scam number* and have them call again. Expected: your phone doesn't ring and the call goes straight to voicemail. Swipe left on the number to delete it, and calls ring normally again.

## Notes

- **Free Apple ID signing:** the app stops opening after 7 days, and you re-run it from Xcode to renew. A paid developer account removes the limit and lets you use TestFlight or the App Store later. If Xcode refuses the "App Groups" capability on a free account, tell me and I'll switch to a setup that doesn't need it.
- **Daily refresh:** iOS decides the exact time, usually overnight while charging. Pulling down on the screen updates straight away.
- **Contacts:** a number saved in your contacts can still be blocked if it's on the list. Your allowlist secret in the collector stops that from happening.
- **Phone reports to the shared list:** tap *Copy for collector*, paste into Terminal inside `scam-shield/collector`, then `git add data && git commit -m "Reports" && git push`.
