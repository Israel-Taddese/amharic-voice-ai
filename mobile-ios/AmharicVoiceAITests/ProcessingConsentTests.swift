import Foundation
import XCTest
@testable import AmharicVoiceAI

final class ProcessingConsentTests: XCTestCase {
    func testNewStoreDeniesProcessingWithClearError() {
        let store = ProcessingConsentStore()

        XCTAssertFalse(store.isGranted)
        XCTAssertThrowsError(try store.authorization()) { error in
            XCTAssertTrue(error is ProcessingConsentError)
            XCTAssertEqual(
                error.localizedDescription,
                "Allow translation processing in Privacy settings before sending text or audio."
            )
        }
    }

    func testConsentDoesNotPersistIntoAnotherStore() throws {
        let firstLaunch = ProcessingConsentStore()
        firstLaunch.grant()
        XCTAssertTrue(firstLaunch.isGranted)
        XCTAssertNoThrow(try firstLaunch.authorization())

        let nextLaunch = ProcessingConsentStore()
        XCTAssertFalse(nextLaunch.isGranted)
        XCTAssertThrowsError(try nextLaunch.authorization())
    }

    func testGrantAllowsCurrentAuthorization() throws {
        let store = ProcessingConsentStore()
        store.grant()

        let authorization = try store.authorization()

        XCTAssertTrue(store.isGranted)
        XCTAssertNoThrow(try store.validate(authorization))
    }

    func testWithdrawalInvalidatesAuthorizationAndDeniesNewProcessing() throws {
        let store = ProcessingConsentStore()
        store.grant()
        let authorization = try store.authorization()

        store.withdraw()

        XCTAssertFalse(store.isGranted)
        XCTAssertThrowsError(try store.validate(authorization)) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertThrowsError(try store.authorization()) { error in
            XCTAssertTrue(error is ProcessingConsentError)
        }
    }

    func testRegrantDoesNotRevalidateOldAuthorization() throws {
        let store = ProcessingConsentStore()
        store.grant()
        let oldAuthorization = try store.authorization()

        store.withdraw()
        store.grant()
        let currentAuthorization = try store.authorization()

        XCTAssertTrue(store.isGranted)
        XCTAssertThrowsError(try store.validate(oldAuthorization)) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertNoThrow(try store.validate(currentAuthorization))
    }

    func testRepeatedGrantInvalidatesEarlierAuthorization() throws {
        let store = ProcessingConsentStore()
        store.grant()
        let oldAuthorization = try store.authorization()

        store.grant()

        XCTAssertThrowsError(try store.validate(oldAuthorization)) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertNoThrow(try store.validate(store.authorization()))
    }
}

@MainActor
final class PrivacyConsentViewModelTests: XCTestCase {
    func testAllowAndWithdrawUpdateSharedStoreAndUIState() throws {
        let store = ProcessingConsentStore()
        let viewModel = PrivacyConsentViewModel(store: store)
        XCTAssertFalse(viewModel.isGranted)

        viewModel.allow()
        let authorization = try store.authorization()
        XCTAssertTrue(viewModel.isGranted)
        XCTAssertTrue(store.isGranted)

        viewModel.withdraw()

        XCTAssertFalse(viewModel.isGranted)
        XCTAssertFalse(store.isGranted)
        XCTAssertThrowsError(try store.validate(authorization)) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testModelReflectsInjectedStoreWithoutGrantingConsent() {
        let store = ProcessingConsentStore()
        store.grant()

        let viewModel = PrivacyConsentViewModel(store: store)

        XCTAssertTrue(viewModel.isGranted)
        XCTAssertTrue(store.isGranted)
        XCTAssertFalse(PrivacyConsentViewModel().isGranted)
    }
}
