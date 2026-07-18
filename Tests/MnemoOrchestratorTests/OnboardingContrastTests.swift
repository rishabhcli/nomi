import Foundation
import XCTest
@testable import MnemoOrchestrator

final class OnboardingContrastBehaviorTests: XCTestCase {
    func testNormalTextOpacityIsUnchanged() {
        for opacity in [0.48, 0.52, 0.56, 0.58, 0.62, 0.70, 0.72, 0.75, 0.82, 0.90] {
            XCTAssertEqual(
                SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
                    normal: opacity,
                    primary: opacity == 0.90,
                    highContrast: false,
                    differentiateWithoutColor: false
                ),
                opacity
            )
        }
    }

    func testIncreasedContrastRaisesSecondaryAndPrimaryText() {
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
                normal: 0.48,
                primary: false,
                highContrast: true,
                differentiateWithoutColor: false
            ),
            0.92
        )
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
                normal: 0.90,
                primary: true,
                highContrast: true,
                differentiateWithoutColor: false
            ),
            1.0
        )
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
                normal: 0.97,
                primary: false,
                highContrast: true,
                differentiateWithoutColor: false
            ),
            0.97,
            "contrast adaptation must never reduce an already-strong treatment"
        )
    }

    func testDifferentiateWithoutColorAlsoStrengthensSecondaryText() {
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
                normal: 0.58,
                primary: false,
                highContrast: false,
                differentiateWithoutColor: true
            ),
            0.92
        )
    }

    func testDividerKeepsNormalValueAndUsesExistingContrastToken() {
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveDividerOpacity(
                normal: 0.10,
                highContrast: false,
                differentiateWithoutColor: false
            ),
            0.10
        )
        XCTAssertEqual(
            SurfaceUX.IncreaseContrast.adaptiveDividerOpacity(
                normal: 0.10,
                highContrast: true,
                differentiateWithoutColor: false
            ),
            SurfaceUX.IncreaseContrast.borderStrokeOpacity
        )
    }
}

final class OnboardingContrastWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testPermissionOnboardingConsumesAdaptiveContrast() throws {
        let source = try appSource("PermissionOnboardingView.swift")

        XCTAssertTrue(source.contains("@Environment(\\.colorSchemeContrast)"))
        XCTAssertTrue(source.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))
        XCTAssertTrue(source.contains("adaptiveTextOpacity"))
        XCTAssertTrue(source.contains("adaptiveDividerOpacity"))
        XCTAssertTrue(source.contains("enhancedContrast ? Color.white : Color.green"))
        XCTAssertTrue(source.contains("OnboardingContrastForeground(enabled: enhancedContrast)"))
        XCTAssertFalse(source.contains(".white.opacity(0."))
    }

    func testStarterProfileConsumesAdaptiveContrastForEverySecondaryTreatment() throws {
        let source = try appSource("StarterProfileView.swift")

        XCTAssertTrue(source.contains("@Environment(\\.colorSchemeContrast)"))
        XCTAssertTrue(source.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))
        XCTAssertTrue(source.contains("adaptiveTextOpacity"))
        XCTAssertFalse(source.contains(".white.opacity(0."))
    }
}
