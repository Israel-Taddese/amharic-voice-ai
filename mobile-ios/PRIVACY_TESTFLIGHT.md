# iOS Privacy and TestFlight Readiness

This document describes the current native iOS data flow and the checks required before an AmharicVoice AI TestFlight beta. It is an engineering readiness record, not a substitute for a published privacy policy or App Store Connect disclosures.

## Processing permission and policy access

- Privacy is always available from the native toolbar, including before consent. The full policy is compiled into the app and can be read offline; [PRIVACY_POLICY.md](PRIVACY_POLICY.md) is the matching public-document source.
- Before recording or sending text/audio, the app explains that submissions go through the Render-hosted backend to Microsoft Azure Translator and Azure Speech. The user must choose Allow translation processing. Not now/dismissal leaves permission denied and does not queue or retry the action.
- Processing permission is kept only in memory for this app process. A fresh launch requires a new choice; no UserDefaults/database or new required-reason category is introduced for consent.
- The API client denies text, multipart construction, speech uploads, and generated-audio downloads without permission. Health checks are exempt and may send ordinary connection metadata but no user text or audio.
- Withdrawal invalidates authorization tokens, cancels client work, stops playback, clears text/results, and attempts to delete pending app-owned WAVs. A later grant cannot make an old response valid again. Withdrawal cannot retract bytes already transmitted or guarantee that backend/Azure work already accepted is cancelled.
- The current support link is the existing public GitHub issue tracker. Warn users not to post sensitive content there. **Owner follow-up before submission:** add a private support/privacy contact and publish/verify a stable HTTPS policy URL for App Store Connect. Do not enter a future URL as if it is already live.

## What leaves the device

- Typed text is sent to the configured FastAPI backend when the user selects Translate. The backend may send it to Azure Translator after applying backend-owned normalization.
- Recorded speech is written temporarily as a 16 kHz, mono, 16-bit PCM WAV file and sent to the FastAPI backend only after the user selects Translate recording. The backend sends the audio to Azure Speech Services for transcription, sends text to Azure Translator, and may use Azure Speech Services to synthesize translated audio.
- Backend health checks send no typed text, transcript, or recording.

The app contains no Azure or Render credentials. Release builds use `https://amharic-voice-ai.onrender.com`; Debug builds use a separate local configuration that can be overridden with a credential-free backend origin.

## Storage and retention

- The app does not use `UserDefaults`, Core Data, a local database, analytics storage, or a conversation-history store.
- Typed text, transcripts, translations, and normalization details exist only in the current in-memory SwiftUI state.
- Recordings use app-owned `amharicvoice-*.wav` files in the system temporary directory. Deletion is attempted after successful upload, failed upload, cancellation, replacement, direction changes, or app scene deactivation. Stale app-owned WAV cleanup is attempted when the recorder is next initialized; unrelated temporary files are preserved. Operating-system or filesystem failures can prevent deletion.
- Translated MP3 data is downloaded with an ephemeral `URLSession`, held in memory for playback, and is not saved by the app.
- The backend temporarily stores generated translated MP3 files under opaque UUID URLs and enforces its own retention policy.

Render, Azure, and operating-system service metadata may have separate handling rules. Confirm production Azure diagnostic settings, Render access-log behavior, and vendor retention terms before completing App Store Connect privacy answers. Apple defines data as collected when it is retained beyond what is needed to service a real-time request; confirm the deployed service behavior still matches the empty collected-data declaration in `PrivacyInfo.xcprivacy` before submission.

## Privacy manifest and networking

- Tracking is disabled and no tracking domains or advertising/analytics SDKs are present.
- The manifest currently declares the FileTimestamp category with reason `C617.1` for app-owned file metadata. The Swift code reads `fileSizeKey` and `isRegularFileKey`; these high-level keys alone do not establish use of an API in [Apple's covered-API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Confirm the category against the built app and linked code before submission; retain it only if a covered API is actually used for this reason.
- Release uses the default ATS policy with no exceptions and a fixed HTTPS backend origin.
- Debug alone includes `NSAllowsLocalNetworking` for loopback/LAN backend testing.
- Generated audio URLs must use the configured backend origin and the `/audio/<file>.mp3` path shape; credentials, query strings, fragments, alternate ports, traversal, and unexpected hosts are rejected.

## Validation checklist

### macOS and Xcode

- [ ] Run a clean Release build with the current supported Xcode version.
- [ ] Run the complete XCTest suite on an available iOS Simulator.
- [ ] Confirm the built Release `Info.plist` has no ATS exception or local-network usage description.
- [ ] Generate and review Xcode's privacy report; confirm `PrivacyInfo.xcprivacy` is included and valid.
- [ ] Inspect the Release binary and linked code for covered required-reason APIs; confirm or remove the provisional FileTimestamp declaration based on actual use, not merely a high-level file metadata call.
- [ ] Inspect the Release archive for `http://`, loopback/LAN endpoints, credentials, and unexpected SDKs.

The current GitHub Actions workflow runs Debug simulator tests. A passing run does not establish Release compilation, archive validity, signing, or a completed privacy report.

### Physical iPhone

- [ ] Install and launch a Debug build on a supported physical iPhone.
- [ ] Verify microphone permission Allow starts recording only after the user taps Record speech.
- [ ] On a fresh app launch, decline processing and verify that Translate/Record opens the disclosure without sending content or requesting the microphone. Allow must not automatically retry the action; choose it again deliberately.
- [ ] Read the in-app policy while offline; check Privacy and public support access before accepting.
- [ ] Withdraw during text translation, ready recording, upload, and audio download/playback; verify clearing/cancellation and that regrant never restores an old response.
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
- [ ] Populate the currently empty `AppIcon` slot with owned final 1024x1024 opaque artwork and validate it in the archive.
- [ ] Create and validate a Release archive without signing secrets in the repository.
- [ ] Upload the build and resolve all App Store Connect privacy-manifest diagnostics.
- [ ] Confirm App Store privacy answers against the deployed FastAPI, Render, and Azure data-retention behavior.
- [ ] Supply a public privacy-policy URL and accurate microphone/audio-processing explanation.
- [ ] Replace public-only GitHub support with an appropriate private privacy-contact option. Verify policy wording against actual Render/Azure diagnostics, retention, and the compiled in-app copy before publishing.
- [ ] Check the declared iPad layout, rotation, accessibility text sizes, and privacy sheet on supported devices/simulators.
- [ ] Install the TestFlight build and repeat the production-backend, permission, interruption, playback, cleanup, and device-log checks.

## Release assets and separate security follow-ups

- [ ] Use Apple's [App Store Asset Best Practices](https://developer.apple.com/app-store/asset-best-practices/) and [product-page guide](https://developer.apple.com/app-store/product-page/) for final icon, screenshots, previews, and metadata. Show the shipped native experience with readable Amharic and synthetic, non-sensitive example content; do not imply unimplemented chatbot or account features.
- [ ] Check Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) when exporting assets. Validate both iPhone and the declared iPad experience; do not substitute mockups for actual device validation.
- [ ] Before a wider beta, assess server-side abuse controls separately: trusted proxy/IP handling, edge request-size limits, shared rate limiting if needed, bounded concurrency, timeouts, and Azure cost caps. The existing per-process MVP limiter is not a complete production abuse-control layer. Use [OWASP ASVS](https://github.com/OWASP/ASVS) and [API resource-consumption guidance](https://api-security.owasp.org/editions/2023/en/0xa4-unrestricted-resource-consumption/) as review references, not drop-in security guarantees.

Processing consent is not authentication. The current app has no accounts or database. If accounts or saved user records are introduced, design authentication and authorization in a focused change using upstream [FastAPI security guidance](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/); never embed a shared privileged API key in iOS. Database row-level security applies only if a suitable database is added: [Supabase's Postgres RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security) is a reference, not a dependency choice. Test owner/non-owner access and keep privileged service keys server-side.
