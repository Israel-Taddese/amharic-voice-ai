\# Privacy and Security Checklist



This checklist documents the privacy and security controls considered for the AmharicVoice AI local MVP. The project handles user-provided text, uploaded speech audio, generated translated audio, and Azure API credentials, so the main security goals are to protect secrets, limit resource abuse, reduce unnecessary data retention, and prepare the application for safer future deployment.



\---



\## Current MVP Security Controls



| Control Area | Status | Notes |

|---|---|---|

| Secrets management | Complete | Azure API keys are stored in a local `.env` file and are not committed to GitHub. |

| Example environment file | Complete | `.env.example` documents required configuration without exposing real keys. |

| Git ignore rules | Complete | `.env`, generated audio, sample WAV files, backup files, and local test outputs are ignored. |

| Server-side Azure calls | Complete | Azure Speech and Translator keys stay in the backend instead of being placed in the browser or mobile client. |

| Rate limiting | Complete | Local API rate limiting reduces repeated request abuse against Azure-backed endpoints. |

| Upload size limits | Complete | Speech uploads are limited to 5 MB. |

| Chunked upload validation | Complete | Uploaded audio is read in chunks before processing to reduce memory pressure from oversized files. |

| Invalid WAV handling | Complete | Invalid or renamed audio files return a user-friendly error instead of exposing a low-level Azure SDK call stack. |

| Generated audio cleanup | Complete | Old generated MP3 files are deleted through cleanup logic before saving new generated audio. |

| CORS hardening | Complete | Local frontend origins are explicit, and wildcard CORS is blocked in production configuration. |



\---



\## Privacy Considerations



| Data Type | Current Handling | Privacy Risk | Planned Improvement |

|---|---|---|---|

| Typed text | Sent from UI to backend, then to Azure Translator | User text may contain sensitive content | Add a user-facing privacy notice before public deployment. |

| Uploaded audio | Temporarily saved for speech transcription, then deleted after processing | Audio may contain personal or sensitive speech | Add clearer upload consent language and avoid long-term audio storage. |

| Generated translated audio | Saved as local MP3 output for playback | Generated speech can remain accessible while stored | Improve cleanup to run on startup, schedule, or before serving audio. |

| Azure API keys | Stored locally in `.env` | Key exposure could allow unauthorized Azure usage | Rotate keys if exposure is suspected and use managed secrets in production. |

| Logs | Local server logs show endpoint activity | Logs could expose request patterns or errors | Avoid logging full transcripts, translations, or uploaded audio content. |



\---



\## Deployment Readiness Checklist



Before public deployment, the following controls should be reviewed or implemented:



\- \[ ] Deploy only over HTTPS.

\- \[ ] Use production environment variables instead of local `.env` files.

\- \[ ] Store production secrets in a managed secret store.

\- \[ ] Restrict CORS to the deployed frontend domain.

\- \[ ] Add authentication or API access control if the service is exposed publicly.

\- \[ ] Add a clear privacy notice explaining how text and audio are processed.

\- \[ ] Avoid storing uploaded audio longer than needed for processing.

\- \[ ] Improve generated audio cleanup so retention is enforced even when the app is idle.

\- \[ ] Add monitoring for repeated failed requests and abnormal upload behavior.

\- \[ ] Review Azure logging and retention settings.

\- \[ ] Review dependency updates before merging.

\- \[ ] Document incident response steps for leaked keys, abusive usage, or exposed user data.



\---



\## Current Known Limitations



\- The project is a local MVP and is not yet intended for public production use.

\- The browser UI currently uploads WAV files instead of recording directly into a supported format.

\- Renamed `.m4a` files are not valid WAV files and will fail validation.

\- Generated audio cleanup currently runs when new generated audio is saved, not continuously in the background.

\- Authentication is not yet implemented.

\- Formal privacy notice and terms of use are not yet written.



\---



\## Security Rationale



This checklist supports the project’s security direction by documenting practical controls around secrets management, data handling, input validation, CORS configuration, generated audio retention, and deployment readiness. These controls align with common application security concerns such as security misconfiguration, unrestricted resource consumption, and sensitive data exposure.



\---



\## Portfolio Relevance



This document demonstrates GRC-style thinking by connecting technical implementation to risk reduction, privacy considerations, and future control requirements. It can be referenced in a resume, GitHub portfolio, or interview when explaining how the project was built with security and privacy in mind.

