import XCTest
import CoreGraphics
@testable import MnemoOrchestrator

/// UI.md §3 — the Notch Nook silhouette: solid surface with SQUARE top corners
/// flush against the screen top, rounded bottom corners only.
final class NotchShapeGeometryTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 500, height: 300)
    private var path: CGPath { NotchShapeGeometry.path(in: rect, bottomCornerRadius: 34) }

    func testTopCornersAreSquareAndFullBleed() {
        // The extreme top corners belong to the surface (radius 0, flush).
        XCTAssertTrue(path.contains(CGPoint(x: 1, y: 1)))
        XCTAssertTrue(path.contains(CGPoint(x: 499, y: 1)))
        XCTAssertTrue(path.contains(CGPoint(x: 250, y: 1)))
    }

    func testBottomCornersAreRounded() {
        // The extreme bottom corners are cut by the convex rounding…
        XCTAssertFalse(path.contains(CGPoint(x: 2, y: 298)))
        XCTAssertFalse(path.contains(CGPoint(x: 498, y: 298)))
        // …while the bottom-center edge and the inset corner region are filled.
        XCTAssertTrue(path.contains(CGPoint(x: 250, y: 298)))
        XCTAssertTrue(path.contains(CGPoint(x: 40, y: 296)))
    }

    func testSidesAreStraight() {
        XCTAssertTrue(path.contains(CGPoint(x: 1, y: 150)))
        XCTAssertTrue(path.contains(CGPoint(x: 499, y: 150)))
    }

    func testRadiusClampsOnTinyRects() {
        // Idle: the notch rect itself with hardware-like rounding — the radius
        // clamps so the path stays valid.
        let idle = CGRect(x: 0, y: 0, width: 185, height: 32)
        let p = NotchShapeGeometry.path(in: idle, bottomCornerRadius: 8)
        XCTAssertTrue(p.contains(CGPoint(x: 92, y: 16)))
        XCTAssertFalse(p.contains(CGPoint(x: 1, y: 31)), "bottom corners still round at idle")
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
}
