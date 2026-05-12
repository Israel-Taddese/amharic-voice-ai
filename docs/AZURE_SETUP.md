# Azure Setup

## Create Azure resources

1. Create an Azure account or sign in.
2. Create an Azure AI Speech resource.
3. Create an Azure AI Translator resource.
4. Copy the keys, endpoint, and region values into `backend/.env`.

## Required values

```env
AZURE_SPEECH_KEY=...
AZURE_SPEECH_REGION=eastus
AZURE_TRANSLATOR_KEY=...
AZURE_TRANSLATOR_REGION=global
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com
```

## Language codes used by this project

| Purpose | Amharic | English |
|---|---|---|
| Azure Speech locale | `am-ET` | `en-US` |
| Azure Translator language code | `am` | `en` |
| Azure TTS voice | `am-ET-MekdesNeural` | `en-US-JennyNeural` |

## Security rule

Do not put Azure API keys inside the iOS app. Keep them in the backend environment file or a production secret manager.
