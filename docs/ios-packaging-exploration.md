# iOS Packaging Exploration

## Current recommendation

For the current MVP, the best iOS path is to treat AmharicVoice AI as a web app/PWA-style experience first instead of immediately building a native iOS app.

## Current deployed app

Frontend:

https://amharic-voice-ai-web.onrender.com

Backend:

https://amharic-voice-ai.onrender.com

## Option 1: iOS Add to Home Screen

Users can open the deployed frontend in a mobile browser and add it to the home screen.

Benefits:

- No Apple Developer account required
- No App Store review required
- Fastest path for sharing a mobile-friendly demo
- Good fit for an MVP portfolio project

Limitations:

- Browser and iOS support can vary
- App Store distribution is not included
- Native iOS features are limited compared to a Swift/React Native app

## Option 2: PWA packaging

A future improvement would be to add:

- `manifest.json`
- app icons
- mobile display metadata
- optional service worker for offline shell caching
- install instructions in the README

This would make the web app more app-like and easier to install from supported browsers.

## Option 3: Native iOS app

A future native app could be built with:

- Swift / SwiftUI
- React Native
- Expo
- Capacitor

Benefits:

- Native app-store style experience
- More control over microphone permissions and mobile audio handling
- Better mobile UX

Limitations:

- Requires more development work
- Apple Developer Program may be needed for distribution
- More maintenance and testing

## Decision

For this portfolio MVP, the best next step is to keep the deployed Render web app as the public demo and document iOS Add-to-Home-Screen/PWA packaging as the explored mobile packaging path.
