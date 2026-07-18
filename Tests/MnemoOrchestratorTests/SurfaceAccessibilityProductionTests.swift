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

    func testSurfaceWiresTheDeclaredVoiceOverOrderAtSiblingLevels() throws {
        let surface = try appSource("NotchSurfaceView.swift")
        let blocks = try appSource("SurfaceBlocks.swift")
        let controls = try appSource("AnswerControls.swift")
        let reasoning = try appSource("ReasoningTraceView.swift")

        XCTAssertTrue(blocks.contains("voiceOverSortPriority(for: .answer)"))
        XCTAssertTrue(controls.contains("voiceOverSortPriority(for: .sources)"))
        XCTAssertTrue(surface.contains("voiceOverSortPriority(for: .privacy)"))
        XCTAssertTrue(
            blocks.contains("searching ? .recovery : .queryField"),
            "the spinner/cancel tray must not outrank the real query while searching"
        )

        let searchingStart = try XCTUnwrap(surface.range(of: "private var searchingActivityBody"))
        let searchingEnd = try XCTUnwrap(surface.range(
            of: "/// Answer area",
            range: searchingStart.upperBound..<surface.endIndex
        ))
        XCTAssertTrue(
            surface[searchingStart.lowerBound..<searchingEnd.lowerBound]
                .contains("voiceOverSortPriority(for: .queryField)"),
            "the searching scroll group must carry the top-level query priority"
        )

        let answerZoneStart = try XCTUnwrap(surface.range(of: "private var answerZone"))
        let answerZoneEnd = try XCTUnwrap(surface.range(
            of: "/// Privacy folded",
            range: answerZoneStart.upperBound..<surface.endIndex
        ))
        XCTAssertTrue(
            surface[answerZoneStart.lowerBound..<answerZoneEnd.lowerBound]
                .contains("voiceOverSortPriority(for: .answer)"),
            "the answer scroll group must carry the top-level answer priority"
        )

        let answerStart = try XCTUnwrap(blocks.range(of: "private var answerText"))
        let answerEnd = try XCTUnwrap(blocks.range(
            of: "/// Always-on trust footer",
            range: answerStart.upperBound..<blocks.endIndex
        ))
        XCTAssertTrue(
            blocks[answerStart.lowerBound..<answerEnd.lowerBound]
                .contains("voiceOverSortPriority(for: .answer)"),
            "answer priority must be on the answer sibling, not only its parent scroll group"
        )
        XCTAssertTrue(
            reasoning.contains(
                ".accessibilityLabel(\"Reasoning trace\")\n"
                    + "            .accessibilitySortPriority(Double(\n"
                    + "                SurfaceUX.voiceOverSortPriority(for: .reasoningTrace)"
            ),
            "reasoning priority must be on the contained trace group"
        )
    }
}

final class SurfaceReduceMotionWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testReducedMotionDisablesSpatialSurfaceMorph() throws {
        let motion = try appSource("Motion.swift")
        let surface = try appSource("NotchSurfaceView.swift")

        XCTAssertTrue(motion.contains("reduceMotion ? nil : base"))
        XCTAssertTrue(surface.contains("Motion.geometry(spring, reduceMotion: reduceMotion)"))
    }

    func testReducedMotionUsesAStaticWorkingIndicator() throws {
        let blocks = try appSource("SurfaceBlocks.swift")

        XCTAssertTrue(blocks.contains("@Environment(\\.accessibilityReduceMotion)"))
        XCTAssertTrue(blocks.contains("if reduceMotion"))
        XCTAssertTrue(blocks.contains("spinnerFrame(time: 0)"))
    }
}
