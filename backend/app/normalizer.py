import re
from dataclasses import dataclass


@dataclass
class NormalizationResult:
    original_text: str
    normalized_text: str
    was_normalized: bool
    note: str | None = None
    translation_override: str | None = None


def _clean_amharic_for_matching(text: str) -> str:
    """
    Normalize Amharic text for phrase matching.
    This does not replace the user's original transcript.
    It only helps us detect common phrase patterns.
    """
    cleaned = text.strip()

    # Normalize Ethiopic/common punctuation into spacing.
    cleaned = cleaned.replace("።", " ")
    cleaned = cleaned.replace("፡", " ")
    cleaned = cleaned.replace("፣", " ")
    cleaned = cleaned.replace(".", " ")
    cleaned = cleaned.replace(",", " ")
    cleaned = cleaned.replace("?", " ")
    cleaned = cleaned.replace("!", " ")
    cleaned = cleaned.replace(":", " ")
    cleaned = cleaned.replace(";", " ")

    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def _clean_english_for_matching(text: str) -> str:
    cleaned = text.lower().strip()
    cleaned = re.sub(r"[^a-z\s]", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def normalize_before_translation(
    text: str,
    source_language: str,
    target_language: str
) -> NormalizationResult:
    """
    Handles common Amharic/English phrase-level corrections before Azure translation.
    This prevents literal translations like:
    'ሰላም እንዴት ነው?' -> 'How is peace?'
    """

    original = text.strip()

    if not original:
        return NormalizationResult(
            original_text=text,
            normalized_text=text,
            was_normalized=False
        )

    # Amharic greeting patterns
    if source_language == "am" and target_language == "en":
        compact = _clean_amharic_for_matching(original)

        greeting_patterns = [
            r"^ሰላም\s+እንዴት\s+ነው$",
            r"^ሰላም\s+እንዴት\s+ነህ$",
            r"^ሰላም\s+እንዴት\s+ነሽ$",
            r"^ሰላም\s+እንዴት\s+ነዎት$",
            r"^ሰላም\s+እንዴት\s+ናችሁ$",
        ]

        for pattern in greeting_patterns:
            if re.match(pattern, compact):
                return NormalizationResult(
                    original_text=original,
                    normalized_text="ሰላም። እንዴት ነው?",
                    was_normalized=True,
                    note="Recognized common Amharic greeting phrase and translated by meaning instead of literal word-by-word translation.",
                    translation_override="Hello. How are you?"
                )

    # English greeting patterns
    if source_language == "en" and target_language == "am":
        compact = _clean_english_for_matching(original)

        english_greetings = {
            "hello how are you",
            "hi how are you",
            "hello how are you doing",
            "hi how are you doing",
        }

        if compact in english_greetings:
            return NormalizationResult(
                original_text=original,
                normalized_text="Hello. How are you?",
                was_normalized=True,
                note="Recognized common English greeting phrase and converted it to a natural Amharic greeting.",
                translation_override="ሰላም። እንዴት ነህ?"
            )

    return NormalizationResult(
        original_text=original,
        normalized_text=original,
        was_normalized=False
    )
