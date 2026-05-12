import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = AudioRecorder()
    private let api = APIClient()

    @State private var direction: TranslationDirection = .amToEn
    @State private var transcript = ""
    @State private var translation = ""
    @State private var status = "Ready"
    @State private var isBusy = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Direction", selection: $direction) {
                    ForEach(TranslationDirection.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: recordButtonTapped) {
                    Text(recorder.isRecording ? "Stop Recording" : "Tap to Speak")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(recorder.isRecording ? Color.red.opacity(0.85) : Color.blue.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isBusy)

                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.headline)
                    Text(transcript.isEmpty ? "Your speech transcript will appear here." : transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation")
                        .font(.headline)
                    Text(translation.isEmpty ? "The translation will appear here." : translation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Play Translation") {
                    audioPlayer?.play()
                }
                .disabled(audioPlayer == nil)

                Spacer()
            }
            .padding()
            .navigationTitle("AmharicVoice AI")
        }
    }

    private func recordButtonTapped() {
        Task {
            if recorder.isRecording {
                recorder.stopRecording()
                await sendRecording()
            } else {
                let allowed = await recorder.requestPermission()
                guard allowed else {
                    status = "Microphone permission is required."
                    return
                }
                do {
                    try recorder.startRecording()
                    status = "Listening..."
                    transcript = ""
                    translation = ""
                    audioPlayer = nil
                } catch {
                    status = "Recording failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func sendRecording() async {
        guard let url = recorder.lastRecordingURL else {
            status = "No recording found."
            return
        }

        isBusy = true
        status = "Translating..."
        defer { isBusy = false }

        do {
            let result = try await api.translateSpeech(audioURL: url, direction: direction, speakOutput: true)
            transcript = result.transcript
            translation = result.translatedText

            if let base64 = result.audioBase64, let data = Data(base64Encoded: base64) {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.prepareToPlay()
            }

            status = "Done"
        } catch {
            status = "Translation failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
