import Foundation
import XCTest

final class PermissionOnboardingWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    private func runSigningIdentityResolver(
        config: String,
        environment overrides: [String: String]
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["scripts/resolve-signing-identity.sh", config]
        process.currentDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        process.environment = ProcessInfo.processInfo.environment.merging(overrides) { _, override in
            override
        }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
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
        let resolver = try String(
            contentsOfFile: "scripts/resolve-signing-identity.sh",
            encoding: .utf8
        )
        XCTAssertTrue(resolver.contains("MNEMO_CODESIGN_IDENTITY"))
        XCTAssertTrue(resolver.contains("Apple Development"))
        XCTAssertFalse(script.contains("codesign --force --sign - \"$APP\""))
    }

    func testReleasePackagingNeverSilentlyFallsBackToAdHocSigning() throws {
        let script = try String(contentsOfFile: "scripts/build-app.sh", encoding: .utf8)
        let resolver = try String(
            contentsOfFile: "scripts/resolve-signing-identity.sh",
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("resolve-signing-identity.sh"))
        XCTAssertTrue(resolver.contains("MNEMO_ALLOW_ADHOC_SIGNING"))
        XCTAssertTrue(resolver.contains("[ \"$CONFIG\" = \"release\" ]"))
        XCTAssertTrue(resolver.contains("exit 1"))
    }

    func testReleasePackagingRejectsExplicitAdHocIdentityBeforeBuilding() throws {
        let result = try runSigningIdentityResolver(
            config: "release",
            environment: ["MNEMO_CODESIGN_IDENTITY": "-"]
        )

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(
            result.output.contains("release packaging requires a stable Apple signing identity"),
            result.output
        )
    }

    func testDebugPackagingRequiresExplicitAdHocOptIn() throws {
        let rejected = try runSigningIdentityResolver(
            config: "debug",
            environment: [
                "MNEMO_CODESIGN_IDENTITY": "-",
                "MNEMO_ALLOW_ADHOC_SIGNING": "0",
            ]
        )
        XCTAssertNotEqual(rejected.status, 0, rejected.output)
        XCTAssertTrue(rejected.output.contains("MNEMO_ALLOW_ADHOC_SIGNING=1"), rejected.output)

        let accepted = try runSigningIdentityResolver(
            config: "debug",
            environment: [
                "MNEMO_CODESIGN_IDENTITY": "-",
                "MNEMO_ALLOW_ADHOC_SIGNING": "1",
            ]
        )
        XCTAssertEqual(accepted.status, 0, accepted.output)
        XCTAssertEqual(accepted.output.trimmingCharacters(in: .whitespacesAndNewlines), "-")
    }

    func testPackagedAppUsesHardenedRuntimeWithAudioInputEntitlement() throws {
        let script = try String(contentsOfFile: "scripts/build-app.sh", encoding: .utf8)
        let entitlements = try String(
            contentsOfFile: "scripts/Mnemo.entitlements",
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("--options runtime"))
        XCTAssertTrue(script.contains("--entitlements \"$ENTITLEMENTS\""))
        XCTAssertTrue(entitlements.contains("com.apple.security.device.audio-input"))
        XCTAssertTrue(entitlements.contains("<true/>"))
    }

    func testPackagedAppIncludesEveryRuntimeResourceBundle() throws {
        let script = try String(contentsOfFile: "scripts/build-app.sh", encoding: .utf8)
        XCTAssertTrue(script.contains("Mnemo_MnemoApp.bundle"))
        XCTAssertTrue(script.contains("Mnemo_MnemoDevServer.bundle"))
    }
}
