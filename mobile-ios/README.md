# iOS Starter Notes

This folder contains Swift files you can paste into a new Xcode SwiftUI app named `AmharicVoiceAI`.

You do not need paid Apple Developer Program membership to run the app on your own iPhone through Xcode. You will need the paid membership later for TestFlight and App Store distribution.

## Setup

1. Open Xcode.
2. Create a new project: iOS App, SwiftUI, Swift.
3. Name it `AmharicVoiceAI`.
4. Replace the generated `ContentView.swift` with the file in this folder.
5. Add `AudioRecorder.swift`, `APIClient.swift`, and `Models.swift` to the project.
6. Add the microphone permission from `Info.plist.snippet` into your app's Info.plist.
7. Start the backend locally at `http://127.0.0.1:8000`.
8. If testing on a physical iPhone, replace `localhost` in `APIClient.swift` with your Mac's local IP address, for example `http://192.168.1.20:8000`.

## Important

Never put Azure keys directly in the iOS app. The app should call your backend. The backend calls Azure.
