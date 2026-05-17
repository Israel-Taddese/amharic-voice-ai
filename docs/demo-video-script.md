# AmharicVoice AI Demo Video Script

## Goal

Create a short portfolio demo showing the deployed AmharicVoice AI MVP, including text translation, browser microphone recording, speech translation, translated audio playback, and security/deployment highlights.

## Suggested length

2 to 4 minutes.

## Demo outline

### 1. Project intro

Show the GitHub repository and explain:

- AmharicVoice AI is an Azure-powered Amharic ↔ English translation MVP.
- It supports typed text translation and browser-based speech translation.
- The backend uses FastAPI, Azure Speech Services, Azure Translator, and a custom Amharic phrase normalization layer.

### 2. Deployed frontend

Open:

https://amharic-voice-ai-web.onrender.com

Explain:

- The frontend is deployed as a Render static site.
- The backend API is deployed separately on Render.
- The first request may take longer because the backend is on Render's free tier.

### 3. Text translation test

Use:

ሰላም እንዴት ነው?

Show:

- Translation result
- Normalization result
- Raw JSON response if useful

### 4. Browser microphone recording test

Use the Browser Recording section.

Steps:

- Click Start Recording
- Say a short Amharic greeting
- Click Stop Recording
- Play the recording
- Click Translate Speech

Show:

- Transcript
- Translation
- Normalization note
- Generated audio playback

### 5. Security and reliability highlights

Mention:

- `.env` is ignored
- secrets are stored in Render environment variables
- rate limiting is enabled
- upload size limits are enforced
- invalid WAV files are handled clearly
- generated audio cleanup is included
- production CORS is restricted to the deployed frontend

### 6. Close

Explain that this project demonstrates:

- Cloud API integration
- Secure backend development
- Browser audio handling
- Amharic-specific normalization
- Full-stack deployment
- Portfolio-ready documentation

## Notes for recording

- Test the app once before recording.
- Make sure Chrome is using the correct microphone.
- Make sure Windows output is set to speakers/headphones, not the USB microphone.
- Keep the spoken demo concise and show the successful result clearly.
