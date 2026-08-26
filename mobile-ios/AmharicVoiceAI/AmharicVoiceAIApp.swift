import Foundation
import SwiftUI

@main
struct AmharicVoiceAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                checksHealthOnAppear: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
            )
        }
    }
}
