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

const startRecordingBtn = document.getElementById("start-recording-btn");
const stopRecordingBtn = document.getElementById("stop-recording-btn");
const clearRecordingBtn = document.getElementById("clear-recording-btn");
const recordingStatus = document.getElementById("recording-status");
const recordedAudioPlayer = document.getElementById("recorded-audio-player");

let audioContext = null;
let recordingStream = null;
let recorderSource = null;
let recorderProcessor = null;
let recordedSamples = [];
let recordingSampleRate = 44100;
let recordedWavBlob = null;
const TARGET_RECORDING_SAMPLE_RATE = 16000;

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


function mergeFloat32Arrays(chunks) {
  const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const merged = new Float32Array(totalLength);
  let offset = 0;

  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.length;
  }

  return merged;
}


function resampleToSampleRate(samples, originalSampleRate, targetSampleRate) {
  if (originalSampleRate === targetSampleRate) {
    return samples;
  }

  const ratio = originalSampleRate / targetSampleRate;
  const newLength = Math.round(samples.length / ratio);
  const resampled = new Float32Array(newLength);

  for (let i = 0; i < newLength; i += 1) {
    const sourceIndex = i * ratio;
    const indexFloor = Math.floor(sourceIndex);
    const indexCeil = Math.min(indexFloor + 1, samples.length - 1);
    const fraction = sourceIndex - indexFloor;

    resampled[i] =
      samples[indexFloor] * (1 - fraction) +
      samples[indexCeil] * fraction;
  }

  return resampled;
}

function writeString(view, offset, value) {
  for (let i = 0; i < value.length; i += 1) {
    view.setUint8(offset + i, value.charCodeAt(i));
  }
}

function createWavBlob(samples, sampleRate) {
  const bytesPerSample = 2;
  const buffer = new ArrayBuffer(44 + samples.length * bytesPerSample);
  const view = new DataView(buffer);

  writeString(view, 0, "RIFF");
  view.setUint32(4, 36 + samples.length * bytesPerSample, true);
  writeString(view, 8, "WAVE");
  writeString(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * bytesPerSample, true);
  view.setUint16(32, bytesPerSample, true);
  view.setUint16(34, 16, true);
  writeString(view, 36, "data");
  view.setUint32(40, samples.length * bytesPerSample, true);

  let offset = 44;

  for (let i = 0; i < samples.length; i += 1) {
    const sample = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(offset, sample < 0 ? sample * 0x8000 : sample * 0x7fff, true);
    offset += bytesPerSample;
  }

  return new Blob([view], { type: "audio/wav" });
}

async function startBrowserRecording() {
  clearError();

  try {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error("Browser microphone recording is not supported in this browser.");
    }

    recordedSamples = [];
    recordedWavBlob = null;

    recordingStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
    recordingSampleRate = audioContext.sampleRate;

    recorderSource = audioContext.createMediaStreamSource(recordingStream);
    recorderProcessor = audioContext.createScriptProcessor(4096, 1, 1);

    recorderProcessor.onaudioprocess = (event) => {
      const input = event.inputBuffer.getChannelData(0);
      recordedSamples.push(new Float32Array(input));
    };

    recorderSource.connect(recorderProcessor);
    recorderProcessor.connect(audioContext.destination);

    startRecordingBtn.disabled = true;
    stopRecordingBtn.disabled = false;
    clearRecordingBtn.disabled = true;
    recordingStatus.textContent = "Recording... click Stop Recording when finished.";
    recordedAudioPlayer.classList.add("hidden");
    recordedAudioPlayer.removeAttribute("src");
  } catch (error) {
    showError(error.message);
    recordingStatus.textContent = "Recording could not start.";
  }
}

async function stopBrowserRecording() {
  try {
    if (recorderProcessor) {
      recorderProcessor.disconnect();
      recorderProcessor.onaudioprocess = null;
    }

    if (recorderSource) {
      recorderSource.disconnect();
    }

    if (recordingStream) {
      recordingStream.getTracks().forEach((track) => track.stop());
    }

    if (audioContext) {
      await audioContext.close();
    }

    recorderProcessor = null;
    recorderSource = null;
    recordingStream = null;
    audioContext = null;

    const samples = mergeFloat32Arrays(recordedSamples);

    if (!samples.length) {
      throw new Error("No audio was captured. Please try recording again.");
    }

    const resampledSamples = resampleToSampleRate(
      samples,
      recordingSampleRate,
      TARGET_RECORDING_SAMPLE_RATE
    );

    recordedWavBlob = createWavBlob(resampledSamples, TARGET_RECORDING_SAMPLE_RATE);
    recordedAudioPlayer.src = URL.createObjectURL(recordedWavBlob);
    recordedAudioPlayer.classList.remove("hidden");

    startRecordingBtn.disabled = false;
    stopRecordingBtn.disabled = true;
    clearRecordingBtn.disabled = false;
    recordingStatus.textContent = "Recording ready as 16 kHz mono WAV. Click Translate Speech to submit it.";
  } catch (error) {
    showError(error.message);
    startRecordingBtn.disabled = false;
    stopRecordingBtn.disabled = true;
    clearRecordingBtn.disabled = false;
    recordingStatus.textContent = "Recording stopped, but no usable WAV was created.";
  }
}

function clearBrowserRecording() {
  recordedWavBlob = null;
  recordedSamples = [];
  recordedAudioPlayer.removeAttribute("src");
  recordedAudioPlayer.classList.add("hidden");
  recordingStatus.textContent = "No browser recording yet.";
  startRecordingBtn.disabled = false;
  stopRecordingBtn.disabled = true;
  clearRecordingBtn.disabled = true;
}

async function handleSpeechTranslation() {
  clearError();
  setLoading(translateSpeechBtn, true, "Translate Speech");

  try {
    const file = audioFile.files[0];

    if (!file && !recordedWavBlob) {
      throw new Error("Please choose a WAV audio file or create a browser recording.");
    }

    const formData = new FormData();
    formData.append("direction", speechDirection.value);
    formData.append("speak_output", speakOutput.checked ? "true" : "false");

    if (file) {
      formData.append("audio", file);
    } else {
      formData.append("audio", recordedWavBlob, "browser-recording.wav");
    }

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

startRecordingBtn.disabled = false;
stopRecordingBtn.disabled = true;
clearRecordingBtn.disabled = true;

translateTextBtn.addEventListener("click", handleTextTranslation);
translateSpeechBtn.addEventListener("click", handleSpeechTranslation);
startRecordingBtn.addEventListener("click", startBrowserRecording);
stopRecordingBtn.addEventListener("click", stopBrowserRecording);
clearRecordingBtn.addEventListener("click", clearBrowserRecording);
