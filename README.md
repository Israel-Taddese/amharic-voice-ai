\# AmharicVoice AI



AmharicVoice AI is an Azure-powered Amharic ↔ English speech and text translation project. It is designed to support Amharic speakers, English speakers, and Ethiopian/Eritrean communities with a practical AI translation assistant that can process text, transcribe speech, translate meaning, and generate spoken audio output.



This project is being developed as a flagship portfolio project focused on cloud AI integration, backend API development, language-aware product design, and security-conscious handling of cloud credentials and generated audio.



\---



\## Project Status



\*\*Current stage:\*\* Local backend MVP working



The backend currently supports:



\- English ↔ Amharic text translation

\- Amharic speech-to-text from WAV audio

\- English speech-to-text from WAV audio

\- Speech transcript translation

\- Text-to-speech MP3 generation

\- Clean audio URL responses

\- Amharic phrase normalization for common greeting patterns

\- FastAPI Swagger/OpenAPI testing through `/docs`



\---



\## Problem Statement



Many modern AI products provide stronger support for widely used global languages than for Amharic. Basic translation tools can also translate Amharic too literally, missing the conversational meaning of common expressions.



During testing, the phrase:



```text

ሰላም እንዴት ነው?

```



was originally translated as:



```text

How is peace?

```



That translation is too literal because `ሰላም` can mean “peace,” but in this context it functions as a greeting. The improved output is:



```text

Hello. How are you?

```



This project adds an Amharic-aware normalization layer so the app can handle common conversational patterns more naturally instead of relying only on direct word-by-word translation.



\---



\## Key Features



\### Text Translation



The backend supports text translation in both directions:



| Direction | Meaning |

|---|---|

| `am-en` | Amharic text → English text |

| `en-am` | English text → Amharic text |



\### Speech Translation



The backend accepts WAV audio uploads and performs the following workflow:



```text

User uploads Amharic or English WAV audio

→ Backend sends audio to Azure Speech-to-Text

→ Backend translates the transcript with Azure Translator

→ Backend generates translated speech with Azure Text-to-Speech

→ Backend returns transcript, translation, normalization details, and audio URL

```



\### Amharic Phrase Normalization



The app includes custom phrase normalization logic for common Amharic greetings.



Example successful API response:



```json

{

&#x20; "direction": "am-en",

&#x20; "speech\_locale": "am-ET",

&#x20; "source\_language": "am",

&#x20; "target\_language": "en",

&#x20; "transcript": "ሰላም እንዴት ነው?",

&#x20; "translated\_text": "Hello. How are you?",

&#x20; "normalized\_text": "ሰላም። እንዴት ነው?",

&#x20; "normalization\_applied": true,

&#x20; "normalization\_note": "Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation.",

&#x20; "audio\_url": "/audio/translation\_example.mp3",

&#x20; "audio\_mime\_type": "audio/mpeg"

}

```



\### Clean Audio Output



The first version returned a large `audio\_base64` string in the JSON response. The backend was improved to save generated MP3 files locally and return a clean `audio\_url` instead.



Example:



```json

{

&#x20; "audio\_url": "/audio/translation\_example.mp3",

&#x20; "audio\_mime\_type": "audio/mpeg"

}

```



\---



\## Tech Stack



| Area | Technology |

|---|---|

| Backend | FastAPI |

| Language | Python |

| Cloud AI | Azure Speech Services |

| Translation | Azure Translator |

| Speech-to-text | Azure Speech SDK |

| Text-to-speech | Azure Speech SDK |

| API testing | FastAPI Swagger UI |

| Environment management | Python virtual environment |

| Secrets management | `.env` file for local development |



\---



\## Architecture



```text

Client or browser

&#x20;   ↓

FastAPI backend

&#x20;   ↓

Azure Speech-to-Text

&#x20;   ↓

Amharic/English phrase normalization

&#x20;   ↓

Azure Translator

&#x20;   ↓

Azure Text-to-Speech

&#x20;   ↓

Generated MP3 audio URL

```



\---



\## Folder Structure



```text

backend/

&#x20; app/

&#x20;   config.py

&#x20;   main.py

&#x20;   models.py

&#x20;   normalizer.py

&#x20;   speech.py

&#x20;   translator.py

&#x20; scripts/

&#x20;   make\_test\_audio.py

&#x20; requirements.txt

&#x20; .gitignore



docs/

&#x20; AZURE\_SETUP.md

&#x20; PRIVACY\_SECURITY.md

&#x20; PRODUCT\_PLAN.md

&#x20; PROJECT\_LOG.md

&#x20; TEST\_PLAN.md



mobile-ios/

&#x20; SwiftUI starter files



.env.example

README.md

```



\---



\## Backend Setup, Windows



From the repository root:



```powershell

cd backend

py -3.12 -m venv .venv

.\\.venv\\Scripts\\Activate.ps1

python -m pip install --upgrade pip setuptools wheel

pip install -r requirements.txt

```



Create a local `.env` file inside the `backend` folder:



```powershell

notepad .env

```



Use this format:



```env

AZURE\_SPEECH\_KEY=your\_speech\_key\_here

AZURE\_SPEECH\_REGION=eastus



AZURE\_TRANSLATOR\_KEY=your\_translator\_key\_here

AZURE\_TRANSLATOR\_REGION=global

AZURE\_TRANSLATOR\_ENDPOINT=https://api.cognitive.microsofttranslator.com



APP\_ENV=development

ALLOWED\_ORIGINS=\*

```



Start the backend:



```powershell

python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

```



Open the health endpoint:



```text

http://127.0.0.1:8000/health

```



Expected response:



```json

{

&#x20; "status": "ok",

&#x20; "service": "amharic-voice-ai"

}

```



\---



\## API Documentation



FastAPI provides interactive local API documentation at:



```text

http://127.0.0.1:8000/docs

```



Use this page to test:



\- `/health`

\- `/api/text-translate`

\- `/api/speech-translate`



\---



\## Test Text Translation



Example request body for Amharic to English:



```json

{

&#x20; "text": "ሰላም እንዴት ነው?",

&#x20; "direction": "am-en"

}

```



Example request body for English to Amharic:



```json

{

&#x20; "text": "Hello, how are you?",

&#x20; "direction": "en-am"

}

```



\---



\## Test Speech Translation



Use the generated test audio files or upload your own WAV files.



Example values in `/docs`:



| Field | Value |

|---|---|

| `direction` | `am-en` |

| `speak\_output` | `true` |

| `audio` | `amharic\_hello.wav` |



The response should include:



\- Transcript

\- Translated text

\- Normalized text, if applicable

\- Normalization status

\- Audio URL

\- Audio MIME type



\---



\## Generated Test Audio



A helper script is included to generate sample WAV files using Azure Text-to-Speech.



From the `backend` folder:



```powershell

python .\\scripts\\make\_test\_audio.py

```



Expected generated files:



```text

samples/english\_hello.wav

samples/amharic\_hello.wav

```



These files make it possible to test the speech pipeline without using a microphone.



\---



\## Security and Privacy Notes



This project is currently a local development MVP. It should not be deployed publicly without additional protections.



Current practices:



\- Azure API keys are stored in `.env`.

\- `.env` should not be committed to GitHub.

\- Generated audio files should not be committed to GitHub.

\- Backend runs locally on `127.0.0.1` during development.

\- Azure keys stay server-side and are not placed inside the iOS/mobile client.



Before public deployment, planned improvements include:



\- Rate limiting

\- Authentication or API access control

\- HTTPS deployment

\- Restricted CORS origins

\- File size limits

\- Audio file cleanup

\- Logging policy that avoids storing sensitive speech/text

\- Privacy notice for uploaded audio and translated text



\---



\## Portfolio Value



This project demonstrates:



\- Cloud AI integration

\- Backend API development

\- Azure Speech Services

\- Azure Translator

\- Speech-to-text workflows

\- Text-to-speech workflows

\- Multilingual Unicode troubleshooting

\- Amharic language support

\- Rule-based NLP/phrase normalization

\- Secure API key handling

\- API usability improvements

\- Product-minded AI development

\- Security and privacy awareness



\---



\## Roadmap



\### Phase 1, Backend MVP



\- \[x] Create FastAPI backend

\- \[x] Configure Azure Speech Services

\- \[x] Configure Azure Translator

\- \[x] Add text translation endpoint

\- \[x] Add speech translation endpoint

\- \[x] Generate test WAV files

\- \[x] Add Amharic phrase normalization

\- \[x] Replace base64 audio output with audio URL



\### Phase 2, Local Web UI



\- \[ ] Create browser interface

\- \[ ] Add text translation panel

\- \[ ] Add speech upload panel

\- \[ ] Add audio player

\- \[ ] Display transcript and translated text

\- \[ ] Display normalization notes

\- \[ ] Add screenshots for GitHub



\### Phase 3, Security Hardening



\- \[ ] Confirm `.env` is ignored

\- \[ ] Add `.env.example`

\- \[ ] Add rate limiting

\- \[ ] Add upload file size limits

\- \[ ] Add generated audio cleanup

\- \[ ] Restrict production CORS settings

\- \[ ] Add privacy/security checklist



\### Phase 4, Deployment



\- \[ ] Choose deployment platform

\- \[ ] Configure production environment variables

\- \[ ] Deploy backend with HTTPS

\- \[ ] Test deployed API

\- \[ ] Add public demo instructions



\### Phase 5, Mobile/Web App



\- \[ ] Build frontend prototype

\- \[ ] Add microphone recording

\- \[ ] Add translated audio playback

\- \[ ] Prepare demo video

\- \[ ] Explore iOS app packaging



\---



\## Resume Summary



\*\*AmharicVoice AI\*\* is an Azure-powered Amharic ↔ English speech and text translation project built with FastAPI, Azure Speech Services, and Azure Translator. The project supports text translation, speech transcription, translated speech output, and Amharic-aware phrase normalization to improve natural translation quality for common conversational phrases.



\---



\## Current Status



The backend MVP is working locally and is being prepared for GitHub portfolio presentation, frontend development, and future deployment.

