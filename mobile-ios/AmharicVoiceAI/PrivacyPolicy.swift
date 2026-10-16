import Foundation

struct PrivacyPolicySection: Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

enum PrivacyPolicy {
    static let version = "October 15, 2026"
    static let supportURL = URL(string: "https://github.com/Israel-Taddese/amharic-voice-ai/issues")!

    static let disclosure = """
    When you choose Translate, your text or recording goes to the AmharicVoice AI backend hosted on Render. The backend uses Microsoft Azure Translator and Azure Speech as needed to translate text, transcribe recordings, and create spoken translations.

    Microphone permission is separate and is requested only when you choose to record. Generated translated audio is temporarily accessible through an unlisted URL. Anyone who obtains that URL can listen while it is valid.

    Permission lasts for this app session. Allowing does not start a translation or recording. You can withdraw permission here; withdrawal cannot recall data already sent.
    """

    static let publicSupportWarning = "GitHub issues are public. Do not post recordings, transcripts, personal text, audio URLs, or credentials."

    // Keep the public policy in mobile-ios/PRIVACY_POLICY.md aligned with these sections.
    static let sections = [
        PrivacyPolicySection(
            title: "What you submit",
            body: """
            When you choose Translate, AmharicVoice AI sends your typed text or selected recording, translation direction, and spoken-output preference to our backend hosted on Render. Your submissions may contain personal information. Submit only content you are comfortable processing through these services.

            A backend availability check may run when the app opens. It sends no typed text or recording, but the network connection still exposes ordinary connection metadata to the hosting service.
            """
        ),
        PrivacyPolicySection(
            title: "Microsoft Azure processing",
            body: """
            The backend applies its Amharic normalization rules and uses Microsoft Azure Translator where needed. Speech translation sends recordings to Azure Speech for transcription, translates the transcript, and optionally sends translated text to Azure Speech to generate spoken output. Cloud credentials stay on the backend.
            """
        ),
        PrivacyPolicySection(
            title: "On your device",
            body: """
            Typed text, transcripts, translations, and downloaded playback audio are held in the current app memory rather than a conversation-history database. The app uses temporary app-owned WAV recordings and attempts deletion after upload, failure, cancellation, replacement, or app inactivity. If iOS terminates unexpectedly, recordings may remain until the next recorder initialization removes stale app-owned files. Operating-system or filesystem conditions can prevent deletion.

            The app keeps your processing permission in memory for this app session only. It does not save this choice or translation content in UserDefaults, an account, or a local database. Downloaded translated audio uses an ephemeral network session and is not deliberately saved by the app.
            """
        ),
        PrivacyPolicySection(
            title: "On our backend",
            body: """
            Uploaded recordings are temporarily written for transcription. Deletion is attempted when processing completes, including ordinary failures. Unexpected service termination may leave temporary files until the hosting environment removes them.

            Generated translated MP3s are stored temporarily for playback. New requests for audio older than one hour are rejected. Physical deletion is triggered by audio access or later audio generation and may occur later during inactivity. Audio URLs are randomly named and unlisted, but require no login. Anyone who obtains a URL may access it while valid. Expiry cannot remove copies already downloaded.
            """
        ),
        PrivacyPolicySection(
            title: "Service metadata",
            body: """
            The backend uses network-address metadata for rate limiting. Render, Microsoft Azure, and the operating system may process connection metadata, diagnostics, and access logs under their settings and terms. Access logs may include request paths, including generated-audio locators. We do not promise that every provider retains no data or deletes every copy immediately.
            """
        ),
        PrivacyPolicySection(
            title: "Your choices",
            body: """
            You can decline processing and still read this policy and project support information. Choose Privacy to withdraw permission. Withdrawal blocks new translation requests, cancels active client work where possible, stops playback, attempts to delete pending app-owned recordings, and clears current text and translation results.

            Withdrawal cannot recall data already transmitted, guarantee that processing already received by the backend or Azure stops, or erase copies already downloaded. Microphone access is a separate iOS permission that you manage in Settings.
            """
        ),
        PrivacyPolicySection(
            title: "Tracking and accounts",
            body: """
            The native app has no advertising or analytics SDK, tracking integration, account creation, or saved conversation-history service. We do not operate a model-training feature using your submissions. This does not override the service providers' handling of their own metadata and diagnostics.
            """
        ),
        PrivacyPolicySection(
            title: "Project support",
            body: """
            Project support is available through the public GitHub issue tracker at https://github.com/Israel-Taddese/amharic-voice-ai/issues.

            GitHub issues are public. Do not post recordings, transcripts, personal text, audio URLs, or credentials.
            """
        )
    ]
}
