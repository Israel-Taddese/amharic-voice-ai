import Combine
import Foundation

struct ProcessingAuthorization {
    fileprivate let generation: UInt64
}

enum ProcessingConsentError: LocalizedError {
    case required

    var errorDescription: String? {
        "Allow translation processing in Privacy settings before sending text or audio."
    }
}

final class ProcessingConsentStore {
    private let lock = NSLock()
    private var granted = false
    private var generation: UInt64 = 0

    var isGranted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return granted
    }

    func grant() {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        granted = true
    }

    func withdraw() {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        granted = false
    }

    func authorization() throws -> ProcessingAuthorization {
        lock.lock()
        defer { lock.unlock() }
        guard granted else {
            throw ProcessingConsentError.required
        }
        return ProcessingAuthorization(generation: generation)
    }

    func validate(_ authorization: ProcessingAuthorization) throws {
        lock.lock()
        defer { lock.unlock() }
        guard granted, authorization.generation == generation else {
            throw CancellationError()
        }
    }
}

@MainActor
final class PrivacyConsentViewModel: ObservableObject {
    let store: ProcessingConsentStore
    @Published private(set) var isGranted: Bool

    init(store: ProcessingConsentStore = ProcessingConsentStore()) {
        self.store = store
        isGranted = store.isGranted
    }

    func allow() {
        store.grant()
        isGranted = store.isGranted
    }

    func withdraw() {
        store.withdraw()
        isGranted = store.isGranted
    }
}
