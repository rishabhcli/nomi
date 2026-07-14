import XCTest
@testable import MnemoOrchestrator

final class PermissionOnboardingTests: XCTestCase {
    private func snapshot(
        speech: PermissionGrantStatus = .authorized,
        microphone: PermissionGrantStatus = .authorized,
        fullDiskAccess: PermissionGrantStatus = .denied
    ) -> PermissionSnapshot {
        PermissionSnapshot(
            speechRecognition: speech,
            microphone: microphone,
            fullDiskAccess: fullDiskAccess
        )
    }

    func testPendingFirstRunIsOfferedEvenWhenVoiceWasAlreadyGranted() {
        XCTAssertTrue(PermissionOnboardingPolicy.shouldOffer(
            preference: .pending,
            snapshot: snapshot()
        ))
    }

    func testCompletedOnboardingNeverReappearsOnOrdinaryLaunch() {
        XCTAssertFalse(PermissionOnboardingPolicy.shouldOffer(
            preference: .completed,
            snapshot: snapshot(speech: .denied, microphone: .denied)
        ))
    }

    func testVoicePromptsMustResolveBeforeOnboardingCanComplete() {
        XCTAssertFalse(PermissionOnboardingPolicy.canComplete(
            snapshot(speech: .notDetermined)
        ))
        XCTAssertFalse(PermissionOnboardingPolicy.canComplete(
            snapshot(microphone: .notDetermined)
        ))
        XCTAssertTrue(PermissionOnboardingPolicy.canComplete(
            snapshot(speech: .denied, microphone: .restricted)
        ))
    }

    func testFullDiskAccessIsOptionalBecauseItRequiresSystemSettings() {
        XCTAssertTrue(PermissionOnboardingPolicy.canComplete(
            snapshot(fullDiskAccess: .denied)
        ))
        XCTAssertTrue(PermissionOnboardingPolicy.canComplete(
            snapshot(fullDiskAccess: .unavailable)
        ))
    }

    func testCompletionPreferenceIsMonotonicAndCancellationSafe() {
        XCTAssertEqual(
            PermissionOnboardingPreferenceTransition.resolve(
                current: .pending,
                requested: .completed,
                isCancelled: true
            ),
            .pending
        )
        XCTAssertEqual(
            PermissionOnboardingPreferenceTransition.resolve(
                current: .completed,
                requested: .pending
            ),
            .completed
        )
    }
}
