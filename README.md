# Personal Driver — CommandAGI human-as-robot (iOS / SwiftUI)

The iPhone counterpart to the [Android example](https://github.com/CommandAGI/commandagi-example-human-robot).
This phone registers itself as a robot on [CommandAGI](https://commandagi.com): its **camera fills
the screen and streams up** as the robot's observation, and the **move / turn directions a driver
sends** — move forward / back / turn left / turn right / stop — appear **big at the bottom** for you
(the human) to perform. They can also be **spoken aloud**.

A person (in the web UI), an AI agent, or an SDK client then "drives you" like any other robot. Under
the hood it's the **producer side** of the robot API — `frame` messages up, `control` messages down
(see [the robot developer API](https://commandagi.com/docs/robots)).

> Human control only. The Android example additionally relays to a Wi-Fi drone via an ESP32.

## Build & run

This uses [XcodeGen](https://github.com/yonyz/XcodeGen) so there's no checked-in `.xcodeproj`:

```bash
brew install xcodegen
cd examples/human-robot-ios
xcodegen generate        # writes PersonalDriver.xcodeproj
open PersonalDriver.xcodeproj
```

Then select your iPhone and Run. Grant **camera** permission, tap **⚙ Settings → Connect to
CommandAGI**, and sign in — the app gets an access token via OAuth (no API key to copy). To drive
yourself, open the session in the web app (or point an agent / the SDK at it) and follow the
directions on screen.

### Zero-config build (optional)

Bake an API key at build time so the app auto-connects with no in-app setup:

```bash
xcodebuild -scheme PersonalDriver -destination 'generic/platform=iOS' \
  COMMANDAGI_API_KEY=cagi_… build
```

Never commit a real key — the default is empty and the app prompts you to connect.

## How it works

- **`CameraController`** — `AVCaptureSession` back camera → JPEG frames (~6 fps).
- **`CommandAgiBridge`** — registers the robot (`POST /machines` → `connect-device`), opens a
  `URLSessionWebSocketTask` to the session, announces the `cam-head` channel, streams frames, and
  surfaces incoming `control` actions. Byte-identical wire protocol to the Android bridge.
- **`OAuthManager`** — "Connect to CommandAGI" via `ASWebAuthenticationSession` + PKCE; the issued
  access token is a normal CommandAGI key used as a Bearer.
- **`ContentView`** — fullscreen camera + the big instruction (+ optional text-to-speech) and a
  Settings sheet.

## Notes (dev-speed example)

- Auth is OAuth (PKCE) using the shared `personal-driver` public client and the
  `commandagi-driver://oauth` redirect — the same client as the Android app.
- The YUV→JPEG path uses the simple `CIContext` conversion; tune `compressionQuality` / preset for
  your device.

Built on the CommandAGI robot API. SDKs: [Python](https://github.com/CommandAGI/commandagi-python) ·
[Node](https://github.com/CommandAGI/commandagi-node). MIT licensed.
