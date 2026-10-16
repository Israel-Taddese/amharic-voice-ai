import XCTest
@testable import AmharicVoiceAI

final class BackendConfigurationTests: XCTestCase {
#if DEBUG
    func testLocalConfigurationUsesLoopbackBackend() {
        XCTAssertEqual(BackendConfiguration.local.baseURL.absoluteString, "http://127.0.0.1:8000")
    }
#endif

    func testProductionConfigurationUsesRenderOverHTTPS() {
        XCTAssertEqual(
            BackendConfiguration.production.baseURL.absoluteString,
            "https://amharic-voice-ai.onrender.com"
        )
        XCTAssertEqual(BackendConfiguration.production.baseURL.scheme, "https")
    }

#if DEBUG
    func testDebugConfigurationAcceptsSafeBackendOverride() {
        let configuration = BackendConfiguration.debug(environment: [
            BackendConfiguration.debugURLOverrideKey: "http://192.168.1.20:8000"
        ])

        XCTAssertEqual(configuration.baseURL.absoluteString, "http://192.168.1.20:8000")
    }

    func testDebugConfigurationRejectsCredentialBearingOverride() {
        let configuration = BackendConfiguration.debug(environment: [
            BackendConfiguration.debugURLOverrideKey: "https://user:password@example.com"
        ])

        XCTAssertEqual(configuration, .local)
    }

    func testDebugConfigurationRejectsOverrideWithUnexpectedPath() {
        let configuration = BackendConfiguration.debug(environment: [
            BackendConfiguration.debugURLOverrideKey: "https://example.com/unexpected"
        ])

        XCTAssertEqual(configuration, .local)
    }
#endif

    func testEndpointBuildsNestedBackendPath() {
        let endpoint = BackendConfiguration.production.endpoint("/api/text-translate/")

        XCTAssertEqual(
            endpoint.absoluteString,
            "https://amharic-voice-ai.onrender.com/api/text-translate"
        )
    }
}
