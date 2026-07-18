import Foundation
import XCTest
@testable import MnemoOrchestrator

final class SurfaceAnnouncementTrackerTests: XCTestCase {
    func testQueryAndStreamingAnswerAnnounceExactlyOncePerContiguousState() {
        var tracker = SurfaceAnnouncementTracker()

        var searching = state(phase: .searching)
        XCTAssertEqual(tracker.next(for: searching)?.text, "Searching your memory")

        searching.status = "Reading three sources"
        searching.reasoning = ["Reading Notes.md"]
        XCTAssertNil(tracker.next(for: searching), "status churn must not repeat the query announcement")

        var answering = state(phase: .answering, answer: "First")
        XCTAssertEqual(tracker.next(for: answering)?.text, "Answer ready")

        answering.answer += " streamed token"
        XCTAssertNil(tracker.next(for: answering), "streamed tokens must not repeat the answer announcement")

        _ = tracker.next(for: state(phase: .input))
        XCTAssertEqual(
            tracker.next(for: state(phase: .searching))?.text,
            "Searching your memory",
            "returning to a quiet state must arm the next query announcement"
        )
    }

    func testEachTerminalOutcomeUsesReducerCopyAndAnnouncesOnce() {
        let terminals: [TerminalState] = [
            .indexing(path: "/tmp/Notes.md"),
            .empty(nearest: []),
            .emptyCorpus,
            .modelNotLoaded(model: "local-model"),
            .engineUnreachable,
            .unsupportedAnswer,
        ]

        for terminal in terminals {
            var tracker = SurfaceAnnouncementTracker()
            let terminalState = state(phase: .state, terminal: terminal)

            XCTAssertEqual(
                tracker.next(for: terminalState)?.text,
                NotchReducer.message(for: terminal)
            )
            XCTAssertNil(tracker.next(for: terminalState))
        }
    }

    func testIdleAndInputStatesDoNotAnnounce() {
        var tracker = SurfaceAnnouncementTracker()

        XCTAssertNil(tracker.next(for: state(phase: .idle)))
        XCTAssertNil(tracker.next(for: state(phase: .input)))
    }

    func testGroundingRetryDoesNotRepeatQueryStartAndAnnouncesCorrectedAnswer() {
        var tracker = SurfaceAnnouncementTracker()
        let source = SourceCard(title: "Notes", path: "/tmp/Notes.md", docId: "notes")

        XCTAssertEqual(tracker.next(for: state(phase: .searching))?.text, "Searching your memory")
        XCTAssertEqual(
            tracker.next(for: state(phase: .answering, answer: "Draft", sources: [source]))?.text,
            "Answer ready"
        )
        XCTAssertEqual(
            tracker.next(for: state(phase: .searching, sources: [source]))?.text,
            "Rechecking the answer against your files"
        )
        XCTAssertEqual(
            tracker.next(for: state(phase: .answering, answer: "Corrected", sources: [source]))?.text,
            "Answer ready"
        )
    }

    private func state(
        phase: NotchPhase,
        answer: String = "",
        sources: [SourceCard] = [],
        terminal: TerminalState? = nil
    ) -> NotchState {
        NotchState(
            phase: phase,
            query: "What changed?",
            answer: answer,
            sources: sources,
            terminal: terminal
        )
    }
}

final class SurfacePrivacyAccessibilityTests: XCTestCase {
    func testPrivacyValueReportsCleanAndMeasuredViolationStates() {
        XCTAssertEqual(
            SurfaceAccessibility.privacyValue(for: .clean),
            "On-device, 0 observed outbound connections"
        )
        XCTAssertEqual(
            SurfaceAccessibility.privacyValue(for: .egressDetected(count: 3)),
            "Warning, 3 outbound connection attempts observed"
        )
        XCTAssertEqual(
            SurfaceAccessibility.privacyValue(for: .egressDetected(count: 1)),
            "Warning, 1 outbound connection attempt observed"
        )
    }
}

final class SurfaceAccessibilityWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testSurfacePostsTrackedAnnouncementsAndExposesPrivacyValue() throws {
        let surface = try appSource("NotchSurfaceView.swift")

        XCTAssertTrue(surface.contains("announcementTracker.next(for: newState)"))
        XCTAssertTrue(surface.contains("AccessibilityAnnouncer.post(announcement.text)"))
        XCTAssertTrue(surface.contains(".accessibilityValue(privacyAccessibilityValue)"))
    }

    func testCollapsedDictateTargetHasButtonSemanticsAndActivateAction() throws {
        let surface = try appSource("NotchSurfaceView.swift")

        XCTAssertTrue(surface.contains(".accessibilityAddTraits(.isButton)"))
        XCTAssertTrue(surface.contains(".accessibilityAction { activateDictation() }"))
    }
}
