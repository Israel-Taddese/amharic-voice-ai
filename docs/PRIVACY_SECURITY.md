# Privacy and Security Notes

## MVP privacy defaults

- Do not store raw voice recordings by default.
- Do not log full user transcripts in production unless the user opts in.
- Store only minimal telemetry: language direction, latency, success/failure, and user rating.
- Encrypt data in transit with HTTPS in production.
- Keep Azure keys server-side only.

## GRC-style risk notes

| Risk | Control |
|---|---|
| API keys exposed in mobile app | Keep keys in backend `.env` or secret manager |
| Sensitive voice data stored accidentally | Delete temp recordings immediately after processing |
| Incorrect translation harms user trust | Show transcript and allow user correction |
| High Azure cost from abuse | Add authentication, rate limits, and daily free caps |
| Privacy concerns | Publish clear privacy notice and opt-in data improvement setting |

## Production additions

- Azure Key Vault or cloud secret manager
- Rate limiting
- Authentication
- HTTPS-only API gateway
- Data retention policy
- User delete/export option
