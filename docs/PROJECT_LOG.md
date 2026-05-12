\# AmharicVoice AI Project Log



\## Project Overview



AmharicVoice AI is an Azure-powered Amharic ↔ English speech and text translation project. The goal is to build a practical translation assistant for Amharic speakers, English speakers, and Ethiopian/Eritrean communities who need better language support from modern AI tools.



This project is being developed as a flagship portfolio project demonstrating cloud AI integration, backend API development, language-aware product design, and security-conscious handling of cloud credentials and generated user audio.



\---



\## Current Milestone Summary



\### Milestone 1, Local Backend Setup



\*\*Completed:\*\* Yes



\*\*What was done:\*\*

\- Set up the project locally on Windows.

\- Created and activated a Python virtual environment using Python 3.12.

\- Installed backend dependencies from `requirements.txt`.

\- Started the FastAPI backend with Uvicorn.

\- Confirmed `/health` returned a successful response.



\*\*Technical value:\*\*

\- Demonstrates Python environment setup, FastAPI development, backend testing, and local API debugging.



\---



\### Milestone 2, Azure AI Resource Setup



\*\*Completed:\*\* Yes



\*\*What was done:\*\*

\- Created an Azure Speech Services resource.

\- Created an Azure Translator resource.

\- Configured `.env` with Azure API keys, endpoint, and region values.

\- Fixed the initial `401 Unauthorized` issue caused by placeholder credentials.



\*\*Technical value:\*\*

\- Demonstrates cloud AI integration, Azure resource configuration, API authentication, and environment-based secrets management.



\---



\### Milestone 3, Text Translation



\*\*Completed:\*\* Yes



\*\*What was done:\*\*

\- Tested English → Amharic text translation.

\- Tested Amharic → English text translation.

\- Confirmed that browser-based `/docs` testing handled Amharic Unicode correctly.

\- Identified that Windows PowerShell displayed Amharic characters incorrectly, while the browser handled them properly.



\*\*Technical value:\*\*

\- Demonstrates REST API testing, multilingual Unicode troubleshooting, and practical debugging.



\---



\### Milestone 4, Generated Test Audio



\*\*Completed:\*\* Yes



\*\*What was done:\*\*

\- Created a Python script to generate test WAV files using Azure Text-to-Speech.

\- Generated `english\_hello.wav` and `amharic\_hello.wav`.

\- Used generated audio instead of microphone recordings to continue testing without a quiet environment.



\*\*Technical value:\*\*

\- Demonstrates creative test-data generation, Azure Speech SDK usage, and repeatable speech testing.



\---



\### Milestone 5, Speech Translation Pipeline



\*\*Completed:\*\* Yes



\*\*What was done:\*\*

\- Tested WAV audio uploads through FastAPI `/docs`.

\- Confirmed Amharic WAV audio could be transcribed with Azure Speech.

\- Confirmed transcribed Amharic could be translated into English.

\- Confirmed translated text could be converted back into MP3 speech output.



\*\*Technical value:\*\*

\- Demonstrates a full speech-to-text → translation → text-to-speech workflow.



\---



\### Milestone 6, Amharic Phrase Normalization



\*\*Completed:\*\* Yes



\*\*Problem found:\*\*

Azure translated the phrase:



`ሰላም እንዴት ነው?`



as:



`How is peace?`



This was technically literal but contextually wrong because `ሰላም` is commonly used as a greeting.



\*\*Improvement made:\*\*

\- Added an Amharic-aware phrase normalization layer.

\- Normalized greeting phrases before translation.

\- Improved the output from literal translation to:



`Hello. How are you?`



\*\*Technical value:\*\*

\- Demonstrates product thinking, language-specific quality improvement, and rule-based NLP enhancement.



\---



\### Milestone 7, Clean Audio URL Output



\*\*Completed:\*\* Yes



\*\*Problem found:\*\*

The API originally returned a very large `audio\_base64` string in the JSON response, which made Swagger output hard to read.



\*\*Improvement made:\*\*

\- Updated the backend to save generated MP3 files locally.

\- Mounted a static `/audio` route.

\- Replaced `audio\_base64` with a clean `audio\_url`.



\*\*Example output:\*\*



```json

{

&#x20; "translated\_text": "Hello. How are you?",

&#x20; "audio\_url": "/audio/translation\_example.mp3",

&#x20; "audio\_mime\_type": "audio/mpeg"

}

