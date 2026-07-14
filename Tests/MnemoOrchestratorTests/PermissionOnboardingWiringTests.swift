import Foundation
import XCTest

final class PermissionOnboardingWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testRealNotchRendersFirstRunPermissionOnboarding() throws {
        let surface = try appSource("NotchSurfaceView.swift")
        XCTAssertTrue(surface.contains("PermissionOnboardingView(vm: vm)"))
        XCTAssertTrue(surface.contains("showsPermissionOnboarding"))
    }

    func testControllerOffersPermissionsBeforeStarterProfile() throws {
        let controller = try appSource("NotchController.swift")
        XCTAssertTrue(controller.contains("SystemPermissionAuthorizer"))
        XCTAssertTrue(controller.contains("offerPermissionOnboardingIfNeeded"))
        XCTAssertTrue(controller.contains("offerStarterProfileAfterPermissions"))
    }

    func testOnlyPermissionAuthorizerCanTriggerSystemPrompts() throws {
        let dictation = try appSource("Dictation.swift")
        let authorizer = try appSource("SystemPermissionAuthorizer.swift")

        XCTAssertFalse(dictation.contains("requestAuthorization"))
        XCTAssertFalse(dictation.contains("requestAccess(for: .audio)"))
        XCTAssertTrue(authorizer.contains("SFSpeechRecognizer.requestAuthorization"))
        XCTAssertTrue(authorizer.contains("AVCaptureDevice.requestAccess(for: .audio)"))
    }

    func testPackagedAppUsesStableSigningIdentityWhenAvailable() throws {
        let script = try String(contentsOfFile: "scripts/build-app.sh", encoding: .utf8)
        XCTAssertTrue(script.contains("MNEMO_CODESIGN_IDENTITY"))
        XCTAssertTrue(script.contains("Apple Development"))
        XCTAssertFalse(script.contains("codesign --force --sign - \"$APP\""))
    }
}
