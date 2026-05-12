import Foundation

final class APIClient {
    // Simulator can use localhost. Physical iPhone needs your Mac's LAN IP, for example http://192.168.1.20:8000
    var baseURL = URL(string: "http://127.0.0.1:8000")!

    func translateSpeech(audioURL: URL, direction: TranslationDirection, speakOutput: Bool = true) async throws -> SpeechTranslateResponse {
        let endpoint = baseURL.appendingPathComponent("api/speech-translate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "direction", value: direction.rawValue)
        appendField(name: "speak_output", value: speakOutput ? "true" : "false")

        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        return try JSONDecoder().decode(SpeechTranslateResponse.self, from: data)
    }
}
