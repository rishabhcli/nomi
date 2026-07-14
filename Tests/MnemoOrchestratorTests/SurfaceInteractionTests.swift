import CoreGraphics
import XCTest
@testable import MnemoOrchestrator

final class SurfaceMaterialGeometryTests: XCTestCase {
    func testGlassRegionIsExactlyBottomThirtySixPercentAtEverySurfaceHeight() {
        let input = SurfaceMaterialGeometry(totalHeight: 146)
        let answer = SurfaceMaterialGeometry(totalHeight: 506)

        XCTAssertEqual(input.glassHeight, 146 * 0.36, accuracy: 0.001)
        XCTAssertEqual(answer.glassHeight, 506 * 0.36, accuracy: 0.001)
        XCTAssertEqual(input.fadeStart, 0.64, accuracy: 0.001)
        XCTAssertEqual(answer.fadeStart, 0.64, accuracy: 0.001)
    }

    func testTopRemainsOpaqueBlackRegardlessOfWindowFocus() {
        let material = SurfaceMaterialGeometry(totalHeight: 300)

        for y in [CGFloat(0), 0.25, 0.63] {
            XCTAssertEqual(material.blackBodyOpacity(at: y, windowIsKey: true), 1)
            XCTAssertEqual(material.blackBodyOpacity(at: y, windowIsKey: false), 1)
        }
        XCTAssertEqual(material.blackBodyOpacity(at: 0.82, windowIsKey: true), 0.5, accuracy: 0.001)
        XCTAssertEqual(material.blackBodyOpacity(at: 0.82, windowIsKey: false), 0.5, accuracy: 0.001)
        XCTAssertEqual(material.blackBodyOpacity(at: 1, windowIsKey: true), 0)
        XCTAssertEqual(material.blackBodyOpacity(at: 1, windowIsKey: false), 0)
    }

    func testMaterialGeometryClampsDegenerateInputs() {
        let empty = SurfaceMaterialGeometry(totalHeight: -20, glassFraction: 2)
        XCTAssertEqual(empty.totalHeight, 0)
        XCTAssertEqual(empty.glassFraction, 1)
        XCTAssertEqual(empty.glassHeight, 0)
        XCTAssertEqual(empty.fadeStart, 0)
    }
}

final class SurfaceDismissGestureTests: XCTestCase {
    func testUpwardDragTracksPointerOneToOne() {
        XCTAssertEqual(SurfaceDismissGesture.interactiveOffset(translationY: -48), -48)
        XCTAssertEqual(SurfaceDismissGesture.progress(translationY: -48), 0.5, accuracy: 0.001)
        XCTAssertEqual(SurfaceDismissGesture.progress(translationY: -200), 1)
    }

    func testDownwardDragRubberBandsInsteadOfFollowingOneToOne() {
        let offset = SurfaceDismissGesture.interactiveOffset(translationY: 80)
        XCTAssertGreaterThan(offset, 0)
        XCTAssertLessThan(offset, 20)
    }

    func testDistanceThresholdCommitsDismissal() {
        XCTAssertFalse(SurfaceDismissGesture.shouldDismiss(translationY: -71, velocityY: 0))
        XCTAssertTrue(SurfaceDismissGesture.shouldDismiss(translationY: -72, velocityY: 0))
    }

    func testFastUpwardFlickCommitsAfterMinimumIntentDistance() {
        XCTAssertTrue(SurfaceDismissGesture.shouldDismiss(translationY: -24, velocityY: -700))
        XCTAssertFalse(SurfaceDismissGesture.shouldDismiss(translationY: -10, velocityY: -900))
        XCTAssertFalse(SurfaceDismissGesture.shouldDismiss(translationY: -30, velocityY: 700))
    }

    func testVelocityEstimateUsesPredictedEndTranslation() {
        let velocity = SurfaceDismissGesture.estimatedVelocityY(
            translationY: -20,
            predictedEndTranslationY: -160
        )
        XCTAssertLessThanOrEqual(velocity, -650)
    }
}

final class SurfaceBodyPolicyTests: XCTestCase {
    func testSearchingOwnsARealActivityTraceBody() {
        XCTAssertEqual(
            SurfaceBodyPolicy.kind(phase: .searching, listening: false),
            .activityTrace
        )
        XCTAssertEqual(SurfaceBodyPolicy.kind(phase: .answering, listening: false), .answer)
        XCTAssertEqual(SurfaceBodyPolicy.kind(phase: .input, listening: false), .none)
        XCTAssertEqual(SurfaceBodyPolicy.kind(phase: .searching, listening: true), .voiceOrb)
    }
}

final class SurfaceAnswerLayoutTests: XCTestCase {
    func testStreamingHeightIsQuantizedAndCapped() {
        XCTAssertEqual(SurfaceAnswerLayout.quantizedHeight(101, cap: 480), 120)
        XCTAssertEqual(SurfaceAnswerLayout.quantizedHeight(119, cap: 480), 120)
        XCTAssertEqual(SurfaceAnswerLayout.quantizedHeight(121, cap: 480), 144)
        XCTAssertEqual(SurfaceAnswerLayout.quantizedHeight(999, cap: 480), 480)
        XCTAssertEqual(SurfaceAnswerLayout.quantizedHeight(-10, cap: 480), 0)
    }
}
