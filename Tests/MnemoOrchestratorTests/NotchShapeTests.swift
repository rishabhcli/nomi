import XCTest
import CoreGraphics
@testable import MnemoOrchestrator

/// UI.md §3 — the notch silhouette: a full-bleed top EDGE with concave
/// "shoulders" that flare the inset side walls out to the screen top (the
/// MacBook-notch look), plus convex rounded bottom corners. Continuous-curvature
/// corners. The top edge stays flush/full-bleed (invariant F3).
final class NotchShapeGeometryTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 500, height: 300)
    private var path: CGPath {
        NotchShapeGeometry.path(in: rect, topCornerRadius: 20, bottomCornerRadius: 34)
    }

    func testTopEdgeIsFullBleed() {
        // The center of the top edge belongs to the surface — flush, full width.
        XCTAssertTrue(path.contains(CGPoint(x: 250, y: 2)))
        // A point well inside is filled.
        XCTAssertTrue(path.contains(CGPoint(x: 100, y: 150)))
    }

    func testTopCornersAreConcaveShoulders() {
        // The extreme top corners are SCOOPED OUT by the concave shoulder — the
        // wall is inset, so the outer corner wedge is not part of the surface.
        XCTAssertFalse(path.contains(CGPoint(x: 2, y: 2)))
        XCTAssertFalse(path.contains(CGPoint(x: 498, y: 2)))
    }

    func testSideWallsAreInsetByTheShoulder() {
        // Below the shoulder the walls sit at x = topCornerRadius (20): the
        // outer margin is outside, and just inside the wall is filled.
        XCTAssertFalse(path.contains(CGPoint(x: 5, y: 150)))
        XCTAssertFalse(path.contains(CGPoint(x: 495, y: 150)))
        XCTAssertTrue(path.contains(CGPoint(x: 30, y: 150)))
        XCTAssertTrue(path.contains(CGPoint(x: 470, y: 150)))
    }

    func testBottomCornersAreRounded() {
        // The extreme bottom corners are cut by the convex rounding…
        XCTAssertFalse(path.contains(CGPoint(x: 2, y: 298)))
        XCTAssertFalse(path.contains(CGPoint(x: 498, y: 298)))
        // …while the bottom-center edge is filled.
        XCTAssertTrue(path.contains(CGPoint(x: 250, y: 298)))
    }

    func testRadiusClampsOnTinyRects() {
        // Idle: the notch rect itself with hardware-like rounding — the radii
        // clamp so the path stays valid.
        let idle = CGRect(x: 0, y: 0, width: 185, height: 32)
        let p = NotchShapeGeometry.path(in: idle, topCornerRadius: 5, bottomCornerRadius: 8)
        XCTAssertTrue(p.contains(CGPoint(x: 92, y: 16)))
        XCTAssertFalse(p.contains(CGPoint(x: 1, y: 31)), "bottom corners still round at idle")
    }

    func testSemicircleDropClampsShoulderAway() {
        // The listening drop uses bottomRadius = width/2 (semicircle); there is
        // no room for a shoulder, so it clamps to 0 without a degenerate path,
        // and the top edge stays full-bleed.
        let drop = CGRect(x: 0, y: 0, width: 176, height: 200)
        let p = NotchShapeGeometry.path(in: drop, topCornerRadius: 6, bottomCornerRadius: 88)
        XCTAssertTrue(p.contains(CGPoint(x: 88, y: 2)), "top edge still full-bleed")
        XCTAssertTrue(p.contains(CGPoint(x: 88, y: 100)))
    }
}

/// UI.md §2/§4 — panel anchoring: top edge flush with the screen top, centered
/// on the notch. This is the pure math whose inversion caused the mid-screen bug.
final class NotchPanelRectTests: XCTestCase {
    func testPanelRectIsTopFlushAndCentered() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let notch = CGRect(x: 663.5, y: 950, width: 185, height: 32)   // measured M3 Max
        let r = NotchGeometry.panelRect(screenFrame: screen, notch: notch,
                                        panelSize: CGSize(width: 620, height: 648))
        XCTAssertEqual(r.midX, notch.midX, accuracy: 0.5, "panel centered on the notch")
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5, "panel top edge flush with the screen top")
        XCTAssertEqual(r.width, 620)
        XCTAssertEqual(r.height, 648)
    }

    func testPanelRectOnSecondaryScreenOffsets() {
        let screen = CGRect(x: 1512, y: 200, width: 1920, height: 1080)
        let notch = CGRect(x: 1512 + 860, y: 200 + 1048, width: 200, height: 32)
        let r = NotchGeometry.panelRect(screenFrame: screen, notch: notch,
                                        panelSize: CGSize(width: 600, height: 600))
        XCTAssertEqual(r.midX, notch.midX, accuracy: 0.5)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)
    }
}

final class HoverGeometryTests: XCTestCase {
    func testHoverZoneArmsNearTopEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let notch = CGRect(x: 656, y: 944, width: 200, height: 38)
        XCTAssertTrue(NotchHover.isArmed(cursor: CGPoint(x: 756, y: 980), notchRect: notch,
                                         screenFrame: screen, hoverZonePx: 8))
        XCTAssertFalse(NotchHover.isArmed(cursor: CGPoint(x: 756, y: 500), notchRect: notch,
                                          screenFrame: screen, hoverZonePx: 8))
        XCTAssertFalse(NotchHover.isArmed(cursor: CGPoint(x: 100, y: 980), notchRect: notch,
                                          screenFrame: screen, hoverZonePx: 8))
    }

    func testMouseOutCollapse() {
        // UI.md §5F: collapse only after the cursor leaves the combined
        // notch + surface hot rect (plus grace margin).
        let hot = CGRect(x: 400, y: 700, width: 700, height: 282)
        XCTAssertFalse(NotchHover.isOutside(cursor: CGPoint(x: 756, y: 900), hotRect: hot))
        XCTAssertTrue(NotchHover.isOutside(cursor: CGPoint(x: 756, y: 300), hotRect: hot))
        XCTAssertTrue(NotchHover.isOutside(cursor: CGPoint(x: 100, y: 900), hotRect: hot))
    }

    func testMouseOutOnlyAutoCollapsesAnEmptyInput() {
        XCTAssertTrue(NotchHover.shouldAutoCollapse(
            phase: .input, hasDraft: false, isListening: false, isQuerying: false))

        XCTAssertFalse(NotchHover.shouldAutoCollapse(
            phase: .input, hasDraft: true, isListening: false, isQuerying: false),
            "moving the pointer must not discard a draft")
        XCTAssertFalse(NotchHover.shouldAutoCollapse(
            phase: .searching, hasDraft: true, isListening: false, isQuerying: true))
        XCTAssertFalse(NotchHover.shouldAutoCollapse(
            phase: .answering, hasDraft: true, isListening: false, isQuerying: false),
            "a completed answer must remain visible until explicit dismissal")
        XCTAssertFalse(NotchHover.shouldAutoCollapse(
            phase: .state, hasDraft: true, isListening: false, isQuerying: false),
            "recovery controls must remain visible until explicit dismissal")
        XCTAssertFalse(NotchHover.shouldAutoCollapse(
            phase: .input, hasDraft: false, isListening: true, isQuerying: false))
    }

    func testResigningKeyDoesNotCollapseAStreamingAnswer() {
        XCTAssertFalse(NotchHover.shouldCollapseOnResignKey(
            phase: .answering,
            isListening: false,
            isQuerying: true,
            showsOnboarding: false
        ), "clicking another app after the first token must not cancel the live query")

        XCTAssertFalse(NotchHover.shouldCollapseOnResignKey(
            phase: .searching,
            isListening: false,
            isQuerying: true,
            showsOnboarding: false
        ))
        XCTAssertFalse(NotchHover.shouldCollapseOnResignKey(
            phase: .answering,
            isListening: true,
            isQuerying: false,
            showsOnboarding: false
        ))
        XCTAssertTrue(NotchHover.shouldCollapseOnResignKey(
            phase: .answering,
            isListening: false,
            isQuerying: false,
            showsOnboarding: false
        ), "a completed answer still follows the explicit click-away collapse policy")
    }

    func testResigningKeyDoesNotCollapsePermissionOrStarterOnboarding() {
        XCTAssertFalse(NotchHover.shouldCollapseOnResignKey(
            phase: .input,
            isListening: false,
            isQuerying: false,
            showsOnboarding: true
        ), "permission UI and starter-profile controls may temporarily move key focus")
    }

    func testVoiceTargetMatchesOnlyTheNotchCollar() {
        let target = NotchInteraction.voiceTargetRect(
            surfaceWidth: 520,
            notchSize: CGSize(width: 185, height: 32))

        XCTAssertEqual(target, CGRect(x: 167.5, y: 0, width: 185, height: 32))
        XCTAssertTrue(target.contains(CGPoint(x: 260, y: 16)))
        XCTAssertFalse(target.contains(CGPoint(x: 260, y: 60)),
                       "clicking the input or answer body must not start dictation")
        XCTAssertFalse(target.contains(CGPoint(x: 40, y: 16)),
                       "the expanded shoulders are not the voice control")
    }

    func testCancellingSearchReturnsToEditableQueryWithoutPartialOutput() {
        var searching = NotchState(
            phase: .searching,
            query: "what is my build tool?",
            answer: "partial",
            sources: [SourceCard(title: "Draft", path: "/draft", docId: "d")]
        )
        searching.status = "Reading your files…"
        searching.terminal = .engineUnreachable

        let cancelled = NotchInteraction.cancelledState(searching)

        XCTAssertEqual(cancelled.phase, .input)
        XCTAssertEqual(cancelled.query, "what is my build tool?")
        XCTAssertEqual(cancelled.answer, "")
        XCTAssertEqual(cancelled.sources, [])
        XCTAssertEqual(cancelled.status, "")
        XCTAssertNil(cancelled.terminal)
    }

    func testThreeSourceChipsFitInsideTheReadingSurface() {
        let textWidth = NotchInteraction.sourceChipTextWidth(
            surfaceWidth: 520,
            contentPadding: 20,
            chipPadding: 10,
            spacing: 6,
            chipCount: 3
        )
        let occupied = 3 * (textWidth + 20) + 2 * 6

        XCTAssertEqual(textWidth, 136, accuracy: 0.01)
        XCTAssertLessThanOrEqual(occupied, 480,
                                 "citation chips must fit inside the padded answer width")
    }
}
