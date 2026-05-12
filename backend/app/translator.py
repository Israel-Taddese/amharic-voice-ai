import uuid
import requests
from .config import settings


def translate_text(text: str, target_language: str, source_language: str | None = None) -> str:
    """Translate text using Azure AI Translator REST API."""
    settings.validate()

    url = f"{settings.azure_translator_endpoint.rstrip('/')}/translate"

    params = {
        "api-version": "3.0",
        "to": target_language,
    }

    if source_language:
        params["from"] = source_language

    headers = {
        "Ocp-Apim-Subscription-Key": settings.azure_translator_key,
        "Content-Type": "application/json; charset=UTF-8",
        "X-ClientTraceId": str(uuid.uuid4()),
    }

    translator_region = settings.azure_translator_region.strip()

    if translator_region and translator_region.lower() != "global":
        headers["Ocp-Apim-Subscription-Region"] = translator_region

    response = requests.post(
        url,
        params=params,
        headers=headers,
        json=[{"text": text}],
        timeout=30,
    )

    response.raise_for_status()
    payload = response.json()
    return payload[0]["translations"][0]["text"]
