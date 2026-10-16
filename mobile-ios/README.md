# AmharicVoice AI for iOS

This directory contains a native SwiftUI app and unit-test target for the existing AmharicVoice AI FastAPI backend. The app supports backend health checks plus Amharic ↔ English text and speech translation.

## Requirements

- macOS with Xcode 16 or later
- iOS 17 or later simulator or device
- No Azure or Render credentials in the app

Open `AmharicVoiceAI.xcodeproj` in Xcode, select the `AmharicVoiceAI` scheme, and run the app or its tests.

## Backend configuration

- Debug builds default to `http://127.0.0.1:8000` and use the Debug-only local-network ATS allowance.
- Release builds use `https://amharic-voice-ai.onrender.com` with default ATS protections and no exceptions.
- To test a Debug build on a physical device, set the scheme environment variable `AMHARICVOICE_BACKEND_URL` to a safe local backend URL such as `http://192.168.1.20:8000`.

The Debug override accepts only an HTTP or HTTPS origin without credentials, query parameters, fragments, or an application path. Invalid values fall back to the loopback URL. Local networking is allowed for development; the Release backend remains HTTPS.

The app sends backend requests through an ephemeral `URLSession` and contains no cloud credentials. The FastAPI backend remains the trust boundary and performs all normalization and Azure access.

Microphone permission is requested only when the user starts a recording. Recordings use 16 kHz, mono, 16-bit linear PCM WAV files with unique names in the system temporary directory. The app attempts to delete each temporary recording after upload success, upload failure, cancellation, or replacement; recordings are not persisted by default.

See [`PRIVACY_TESTFLIGHT.md`](PRIVACY_TESTFLIGHT.md) for the native data flow, privacy-manifest rationale, and macOS, physical-iPhone, and TestFlight validation checklist.

## Processing permission

Privacy is available from the toolbar before any translation. The app explains Render/Microsoft Azure processing and offers Allow translation processing or Not now. Allowing only changes the current session's permission; the user must deliberately choose Translate or Record again. A fresh app process starts denied, without persisting consent or user content.

The API client also enforces permission before constructing text/multipart requests or downloading generated audio. Health checks contain no translation content and remain available. Withdrawal cancels client work, clears current input/results, and attempts to delete pending recordings; it cannot recall data already sent. The in-app policy is available offline and matches [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md).

Project support currently uses public GitHub issues. Never post sensitive translation content there. A private privacy-contact option and a verified public policy URL remain owner follow-ups before submission.

## API coverage

- `GET /health`
- `POST /api/text-translate` with JSON `text` and `direction`
- `POST /api/speech-translate` with multipart `audio`, `direction`, and `speak_output`

The `direction` values match the backend contract: `am-en` and `en-am`. Response models include the backend normalization metadata. Generated speech uses the current `audio_url` response contract. Relative audio paths are resolved only against the configured backend origin, unexpected hosts are rejected, and MP3 data is played from memory with native AVFoundation playback.

## Tests

The `AmharicVoiceAITests` target covers:

- backend configuration and URL construction
- text request JSON and speech multipart request construction
- health, text, and current speech response decoding
- mocked network and backend error handling
- text and speech view-model state transitions, permission denial, cancellation, and cleanup
- WAV recording settings and generated-audio origin validation
- denied-by-default processing permission, withdrawal/regrant, and late-response rejection

Tests inject protocol-backed fakes and never contact Render or Azure. Run them in Xcode with Product > Test or from macOS with:

```bash
xcodebuild test \
  -project AmharicVoiceAI.xcodeproj \
  -scheme AmharicVoiceAI \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>'
```

Use an available simulator identifier reported by `xcrun simctl list devices available`. The GitHub Actions workflow performs this selection dynamically.
