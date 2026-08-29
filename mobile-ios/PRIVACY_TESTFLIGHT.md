# iOS Privacy and TestFlight Readiness

This document describes the current native iOS data flow and the checks required before an AmharicVoice AI TestFlight beta. It is an engineering readiness record, not a substitute for a published privacy policy or App Store Connect disclosures.

## What leaves the device

- Typed text is sent to the configured FastAPI backend when the user selects Translate. The backend may send it to Azure Translator after applying backend-owned normalization.
- Recorded speech is written temporarily as a 16 kHz, mono, 16-bit PCM WAV file and sent to the FastAPI backend only after the user selects Translate recording. The backend sends the audio to Azure Speech Services for transcription, sends text to Azure Translator, and may use Azure Speech Services to synthesize translated audio.
- Backend health checks send no typed text, transcript, or recording.

The app contains no Azure or Render credentials. Release builds use `https://amharic-voice-ai.onrender.com`; Debug builds use a separate local configuration that can be overridden with a credential-free backend origin.

## Storage and retention

- The app does not use `UserDefaults`, Core Data, a local database, analytics storage, or a conversation-history store.
- Typed text, transcripts, translations, and normalization details exist only in the current in-memory SwiftUI state.
- Recordings use app-owned `amharicvoice-*.wav` files in the system temporary directory. They are deleted after successful upload, failed upload, cancellation, replacement, direction changes, or app scene deactivation. Stale app-owned WAV files are removed when the recorder is next initialized; unrelated temporary files are preserved.
- Translated MP3 data is downloaded with an ephemeral `URLSession`, held in memory for playback, and is not saved by the app.
- The backend temporarily stores generated translated MP3 files under opaque UUID URLs and enforces its own retention policy.

Render, Azure, and operating-system service metadata may have separate handling rules. Confirm production Azure diagnostic settings, Render access-log behavior, and vendor retention terms before completing App Store Connect privacy answers. Apple defines data as collected when it is retained beyond what is needed to service a real-time request; confirm the deployed service behavior still matches the empty collected-data declaration in `PrivacyInfo.xcprivacy` before submission.

## Privacy manifest and networking

- Tracking is disabled and no tracking domains or advertising/analytics SDKs are present.
- The manifest declares file metadata access with required reason `C617.1` because the app reads file size and regular-file metadata for app-owned temporary WAV validation and cleanup.
- Release uses the default ATS policy with no exceptions and a fixed HTTPS backend origin.
- Debug alone includes `NSAllowsLocalNetworking` for loopback/LAN backend testing.
- Generated audio URLs must use the configured backend origin and the `/audio/<file>.mp3` path shape; credentials, query strings, fragments, alternate ports, traversal, and unexpected hosts are rejected.

## Validation checklist

### macOS and Xcode

- [ ] Run a clean Release build with the current supported Xcode version.
- [ ] Run the complete XCTest suite on an available iOS Simulator.
- [ ] Confirm the built Release `Info.plist` has no ATS exception or local-network usage description.
- [ ] Generate and review Xcode's privacy report; confirm `PrivacyInfo.xcprivacy` is included and valid.
- [ ] Inspect the Release archive for `http://`, loopback/LAN endpoints, credentials, and unexpected SDKs.

### Physical iPhone

- [ ] Install and launch a Debug build on a supported physical iPhone.
- [ ] Verify microphone permission Allow starts recording only after the user taps Record speech.
- [ ] Reset permission and verify denial/restriction produces clear UI without recording.
- [ ] Translate typed Amharic to English and English to Amharic.
- [ ] Record and translate Amharic speech.
- [ ] Record and translate English speech.
- [ ] Play translated audio and verify interruption/route behavior.
- [ ] Interrupt text, upload, and audio-download requests by disabling networking; verify clear recovery and no retained WAV.
- [ ] Background and foreground the app while recording, with a recording ready, during upload, and during playback; verify recording/upload cancellation, temporary-file cleanup, and stopped playback.
- [ ] Reach the recording-duration limit; verify automatic stop, clear messaging, and no multipart request larger than the backend's 5 MiB limit.
- [ ] Verify the Release build contacts only the production HTTPS backend.
- [ ] Review device and macOS Console logs for typed text, transcripts, recording paths, response bodies, audio locators, credentials, or other sensitive data.
- [ ] Relaunch after force termination during recording and verify stale app-owned WAV cleanup.

### TestFlight and App Store Connect

- [ ] Configure the Apple development team, signing certificate, App ID, and provisioning profiles outside Git.
- [ ] Create and validate a Release archive without signing secrets in the repository.
- [ ] Upload the build and resolve all App Store Connect privacy-manifest diagnostics.
- [ ] Confirm App Store privacy answers against the deployed FastAPI, Render, and Azure data-retention behavior.
- [ ] Supply a public privacy-policy URL and accurate microphone/audio-processing explanation.
- [ ] Install the TestFlight build and repeat the production-backend, permission, interruption, playback, cleanup, and device-log checks.
