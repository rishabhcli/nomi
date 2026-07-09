import XCTest
import CoreGraphics
@testable import MnemoOrchestrator

final class NotchGeometryTests: XCTestCase {
    func testComputesCenteredNotchRect() {
        // 1512-wide screen, notch height 38, aux areas 656 each -> notch width 200, centered
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let r = NotchGeometry.rect(screenFrame: screen, safeAreaTop: 38, auxLeftWidth: 656, auxRightWidth: 656)!
        XCTAssertEqual(r.width, 200, accuracy: 0.5)
        XCTAssertEqual(r.height, 38, accuracy: 0.5)
        XCTAssertEqual(r.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)   // pinned to top
    }
    func testNoNotchWhenSafeAreaZero() {
        XCTAssertFalse(NotchGeometry.hasNotch(safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0))
        XCTAssertNil(NotchGeometry.rect(screenFrame: .init(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0))
    }
}
