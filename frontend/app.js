const API_BASE =
  window.AMHARICVOICE_API_BASE ||
  "http://127.0.0.1:8000";

const textDirection = document.getElementById("text-direction");
const textInput = document.getElementById("text-input");
const translateTextBtn = document.getElementById("translate-text-btn");
const sampleAmharicBtn = document.getElementById("sample-amharic");
const sampleEnglishBtn = document.getElementById("sample-english");

const speechDirection = document.getElementById("speech-direction");
const audioFile = document.getElementById("audio-file");
const speakOutput = document.getElementById("speak-output");
const translateSpeechBtn = document.getElementById("translate-speech-btn");

const errorBox = document.getElementById("error-box");
const originalOutput = document.getElementById("original-output");
const translationOutput = document.getElementById("translation-output");
const normalizationOutput = document.getElementById("normalization-output");
const audioPlayer = document.getElementById("audio-player");
const audioNote = document.getElementById("audio-note");
const rawOutput = document.getElementById("raw-output");

function showError(message) {
  errorBox.textContent = message;
  errorBox.classList.remove("hidden");
}

function clearError() {
  errorBox.textContent = "";
  errorBox.classList.add("hidden");
}

function setLoading(button, isLoading, label) {
  button.disabled = isLoading;
  button.textContent = isLoading ? "Working..." : label;
}

function renderResult(data, mode) {
  rawOutput.textContent = JSON.stringify(data, null, 2);

  if (mode === "text") {
    originalOutput.textContent = data.original_text || "No original text returned.";
  } else {
    originalOutput.textContent = data.transcript || "No transcript returned.";
  }

  translationOutput.textContent = data.translated_text || "No translation returned.";

  if (data.normalization_applied) {
    normalizationOutput.textContent = `${data.normalized_text || ""}\n\n${data.normalization_note || ""}`.trim();
  } else {
    normalizationOutput.textContent = "No phrase normalization was applied.";
  }

  if (data.audio_url) {
    audioPlayer.src = `${API_BASE}${data.audio_url}`;
    audioPlayer.classList.remove("hidden");
    audioNote.textContent = `Audio ready: ${data.audio_mime_type || "audio"}`;
  } else {
    audioPlayer.removeAttribute("src");
    audioPlayer.classList.add("hidden");
    audioNote.textContent = "No audio generated for this request.";
  }
}

async function handleTextTranslation() {
  clearError();
  setLoading(translateTextBtn, true, "Translate Text");

  try {
    const payload = {
      text: textInput.value.trim(),
      direction: textDirection.value
    };

    if (!payload.text) {
      throw new Error("Please enter text to translate.");
    }

    const response = await fetch(`${API_BASE}/api/text-translate`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.detail || `Request failed with status ${response.status}`);
    }

    renderResult(data, "text");
  } catch (error) {
    showError(error.message);
  } finally {
    setLoading(translateTextBtn, false, "Translate Text");
  }
}

async function handleSpeechTranslation() {
  clearError();
  setLoading(translateSpeechBtn, true, "Translate Speech");

  try {
    const file = audioFile.files[0];

    if (!file) {
      throw new Error("Please choose a WAV audio file.");
    }

    const formData = new FormData();
    formData.append("direction", speechDirection.value);
    formData.append("speak_output", speakOutput.checked ? "true" : "false");
    formData.append("audio", file);

    const response = await fetch(`${API_BASE}/api/speech-translate`, {
      method: "POST",
      body: formData
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.detail || `Request failed with status ${response.status}`);
    }

    renderResult(data, "speech");
  } catch (error) {
    showError(error.message);
  } finally {
    setLoading(translateSpeechBtn, false, "Translate Speech");
  }
}

sampleAmharicBtn.addEventListener("click", () => {
  textDirection.value = "am-en";
  textInput.value = "ሰላም እንዴት ነው?";
});

sampleEnglishBtn.addEventListener("click", () => {
  textDirection.value = "en-am";
  textInput.value = "Hello, how are you?";
});

translateTextBtn.addEventListener("click", handleTextTranslation);
translateSpeechBtn.addEventListener("click", handleSpeechTranslation);
