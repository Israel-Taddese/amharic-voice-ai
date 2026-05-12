# Test Plan

## Manual test cases

| ID | Direction | Input | Expected result |
|---|---|---|---|
| T001 | Amharic → English | ሰላም እንዴት ነህ? | English greeting translation |
| T002 | English → Amharic | Where is the airport? | Amharic travel translation |
| T003 | Amharic → English | Noisy short phrase | Transcript should be reasonable or error gracefully |
| T004 | English → Amharic | Please call me tomorrow. | Correct Amharic meaning |
| T005 | Amharic → English | Name/date/number phrase | Names and numbers should remain clear |

## Quality scoring

Score each translation from 1 to 5:

- Speech transcript accuracy
- Meaning accuracy
- Amharic grammar/naturalness
- English fluency
- Speed/latency
- TTS pronunciation

## Acceptance criteria for MVP

- 80%+ of simple phrases translate acceptably in quiet conditions.
- App never exposes Azure keys on the client.
- Backend deletes temporary audio files after processing.
- User receives a clear error if speech is not recognized.
