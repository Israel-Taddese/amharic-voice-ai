# AmharicVoice AI Codex Guidance

## Project purpose

AmharicVoice AI is an Amharic ↔ English text and speech translation application. The current stack is FastAPI, HTML/CSS/JavaScript, Azure Speech Services, Azure Translator, Render, and a Swift/iOS starter. The long-term direction is a native mobile app and, later, an Amharic-first conversational AI assistant.

## Security boundaries

- Never access `backend/.env`: do not read, print, summarize, modify, copy, or commit it.
- Never expose or place Azure, Render, or other API credentials in source code, client code, logs, tests, fixtures, documentation, or Git.
- Keep Azure service calls and all cloud credentials server-side.
- Preserve existing CORS restrictions, rate limiting, upload validation, WAV validation, temporary-file cleanup, and generated-audio protections.
- Treat user text, transcripts, uploaded audio, and generated audio as potentially sensitive. Avoid unnecessary logging, persistence, or disclosure.

## Architecture boundaries

- Treat the FastAPI backend as the trust boundary and stable API for web and mobile clients.
- Never place cloud credentials or direct privileged cloud access in web or mobile clients.
- Keep Amharic normalization authoritative in the backend; do not duplicate normalization rules in clients.
- Preserve the behavior and contracts of the current text and speech translation APIs unless a change is explicitly approved.
- Add future chatbot functionality through a separate, versioned conversational API; do not replace the translation endpoints.

## Development workflow

- Inspect relevant code and documentation before editing.
- Use a feature branch for each focused change.
- Keep pull requests small, reviewable, and limited to one concern.
- Do not bundle unrelated security, backend, frontend, or mobile changes.
- Explain every file changed and why.
- Run relevant tests before recommending a merge, and report the commands and results.
- State security and privacy implications, including when a change has none.
- When asked to stop for review, do not commit or push without explicit approval.

## Current priorities

1. Keep the deployed web MVP stable.
2. Address known dependency and security findings.
3. Add automated tests.
4. Build the native iOS client against the existing backend.
5. Later, design the Amharic conversational assistant.

## Important project references

Start with `README.md` for the project overview, architecture, local setup, API usage, deployment status, and roadmap. Use these existing files for deeper context:

- `docs/PRODUCT_PLAN.md` — product vision and roadmap.
- `docs/PROJECT_LOG.md` — project history and implementation context.
- `docs/PRIVACY_SECURITY.md` — current controls, privacy risks, and deployment-readiness checks.
- `docs/TEST_PLAN.md` — current manual cases and MVP acceptance criteria.
- `docs/AZURE_SETUP.md` — Azure resource and language configuration guidance.
- `docs/ios-packaging-exploration.md` — iOS packaging options and current recommendation.
- `backend/app/main.py` — FastAPI routes and request, upload, cleanup, and CORS behavior.
- `backend/app/models.py`, `backend/app/normalizer.py`, `backend/app/speech.py`, and `backend/app/translator.py` — API models and translation pipeline.
- `backend/app/config.py`, `backend/app/rate_limiter.py`, `backend/requirements.txt`, and `backend/run.sh` — runtime configuration, protections, dependencies, and startup.
- `frontend/index.html`, `frontend/styles.css`, and `frontend/app.js` — deployed web client.
- `mobile-ios/README.md` and `mobile-ios/AmharicVoiceAI/` — SwiftUI starter setup, API client, models, recording, and UI.
