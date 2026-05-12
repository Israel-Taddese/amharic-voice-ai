import os
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    azure_speech_key: str = os.getenv("AZURE_SPEECH_KEY", "")
    azure_speech_region: str = os.getenv("AZURE_SPEECH_REGION", "")
    azure_translator_key: str = os.getenv("AZURE_TRANSLATOR_KEY", "")
    azure_translator_region: str = os.getenv("AZURE_TRANSLATOR_REGION", "")
    azure_translator_endpoint: str = os.getenv(
        "AZURE_TRANSLATOR_ENDPOINT",
        "https://api.cognitive.microsofttranslator.com",
    )
    app_env: str = os.getenv("APP_ENV", "development")
    allowed_origins: tuple[str, ...] = tuple(
        origin.strip()
        for origin in os.getenv("ALLOWED_ORIGINS", "*").split(",")
        if origin.strip()
    )

    def validate(self) -> None:
        missing = []
        if not self.azure_speech_key:
            missing.append("AZURE_SPEECH_KEY")
        if not self.azure_speech_region:
            missing.append("AZURE_SPEECH_REGION")
        if not self.azure_translator_key:
            missing.append("AZURE_TRANSLATOR_KEY")
        if not self.azure_translator_region:
            missing.append("AZURE_TRANSLATOR_REGION")
        if missing:
            raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")


settings = Settings()
