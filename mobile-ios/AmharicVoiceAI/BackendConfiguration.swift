import Foundation

struct BackendConfiguration: Equatable {
    let baseURL: URL

#if DEBUG
    static let debugURLOverrideKey = "AMHARICVOICE_BACKEND_URL"

    static let local = BackendConfiguration(
        baseURL: URL(string: "http://127.0.0.1:8000")!
    )
#endif

    static let production = BackendConfiguration(
        baseURL: URL(string: "https://amharic-voice-ai.onrender.com")!
    )

    static var current: BackendConfiguration {
#if DEBUG
        return debug(environment: ProcessInfo.processInfo.environment)
#else
        return production
#endif
    }

#if DEBUG
    static func debug(environment: [String: String]) -> BackendConfiguration {
        guard let overrideURL = safeOverrideURL(
            from: environment[debugURLOverrideKey]
        ) else {
            return local
        }

        return BackendConfiguration(baseURL: overrideURL)
    }
#endif

    func endpoint(_ path: String) -> URL {
        let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relativePath
            .split(separator: "/")
            .reduce(baseURL) { url, component in
                url.appendingPathComponent(String(component))
            }
    }

#if DEBUG
    private static func safeOverrideURL(from rawValue: String?) -> URL? {
        guard
            let rawValue,
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host != nil,
            url.user == nil,
            url.password == nil,
            url.query == nil,
            url.fragment == nil,
            url.path.isEmpty || url.path == "/"
        else {
            return nil
        }

        return url
    }
#endif
}
