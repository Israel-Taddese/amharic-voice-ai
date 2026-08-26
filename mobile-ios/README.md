# AmharicVoice AI for iOS

This directory contains a native SwiftUI app and unit-test target for the existing AmharicVoice AI FastAPI backend. Phase D supports backend health checks and Amharic ↔ English text translation. Speech recording and upload are intentionally deferred.

## Requirements

- macOS with Xcode 16 or later
- iOS 17 or later simulator or device
- No Azure or Render credentials in the app

Open `AmharicVoiceAI.xcodeproj` in Xcode, select the `AmharicVoiceAI` scheme, and run the app or its tests.

## Backend configuration

- Debug builds default to `http://127.0.0.1:8000`.
- Release builds use `https://amharic-voice-ai.onrender.com`.
- To test a Debug build on a physical device, set the scheme environment variable `AMHARICVOICE_BACKEND_URL` to a safe local backend URL such as `http://192.168.1.20:8000`.

The Debug override accepts only an HTTP or HTTPS origin without credentials, query parameters, fragments, or an application path. Invalid values fall back to the loopback URL. Local networking is allowed for development; the Release backend remains HTTPS.

The app sends backend requests through an ephemeral `URLSession` and contains no cloud credentials. The FastAPI backend remains the trust boundary and performs all normalization and Azure access.

## API coverage

- `GET /health`
- `POST /api/text-translate` with JSON `text` and `direction`

The `direction` values match the backend contract: `am-en` and `en-am`. Response models include the backend normalization metadata.

## Tests

The `AmharicVoiceAITests` target covers:

- backend configuration and URL construction
- request methods, headers, paths, and JSON bodies
- health, text, and current speech response decoding
- mocked network and backend error handling
- view-model idle, loading, success, and error transitions

Tests inject protocol-backed fakes and never contact Render or Azure. Run them in Xcode with Product > Test or from macOS with:

```bash
xcodebuild test \
  -project AmharicVoiceAI.xcodeproj \
  -scheme AmharicVoiceAI \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>'
```

Use an available simulator identifier reported by `xcrun simctl list devices available`. The GitHub Actions workflow performs this selection dynamically.

## Deferred speech prototype

`AmharicVoiceAI/AudioRecorder.swift` and `AmharicVoiceAI/Info.plist.snippet` are retained as Phase E reference material but are not members of the Phase D Xcode target. The app does not request microphone permission or implement speech upload in this phase.
