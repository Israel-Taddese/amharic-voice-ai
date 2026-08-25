from backend.app.normalizer import normalize_before_translation


def test_known_amharic_greeting_normalizes_by_meaning() -> None:
    result = normalize_before_translation(
        "ሰላም እንዴት ነህ?",
        source_language="am",
        target_language="en",
    )

    assert result.was_normalized is True
    assert result.normalized_text == "ሰላም። እንዴት ነው?"
    assert result.translation_override == "Hello. How are you?"


def test_speech_recognition_greeting_variation_normalizes_by_meaning() -> None:
    result = normalize_before_translation(
        "እንዴት ነው ሰላም ነው?",
        source_language="am",
        target_language="en",
    )

    assert result.was_normalized is True
    assert result.normalized_text == "ሰላም። እንዴት ነው?"
    assert result.translation_override == "Hello. How are you?"


def test_english_greeting_normalizes_by_meaning() -> None:
    result = normalize_before_translation(
        "Hello, how are you?",
        source_language="en",
        target_language="am",
    )

    assert result.was_normalized is True
    assert result.normalized_text == "Hello. How are you?"
    assert result.translation_override == "ሰላም። እንዴት ነህ?"


def test_unsupported_text_remains_unchanged() -> None:
    text = "Where is the airport?"
    result = normalize_before_translation(
        text,
        source_language="en",
        target_language="am",
    )

    assert result.was_normalized is False
    assert result.original_text == text
    assert result.normalized_text == text
    assert result.translation_override is None
