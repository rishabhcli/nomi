import Foundation
import XCTest

final class OnboardingAccessibilityWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testPermissionPrimaryActionOwnsFocusAndReturn() throws {
        let source = try appSource("PermissionOnboardingView.swift")
        let keyboardTargets = source.components(
            separatedBy: ".focused($focusedControl, equals: .primaryAction)"
        ).count - 1
        let defaultActions = source.components(separatedBy: ".keyboardShortcut(.defaultAction)").count - 1

        XCTAssertTrue(source.contains("@FocusState private var focusedControl: FocusTarget?"))
        XCTAssertFalse(source.contains("@AccessibilityFocusState"),
                       "the explicit state announcement owns VoiceOver speech")
        XCTAssertTrue(source.contains("case primaryAction"))
        XCTAssertEqual(keyboardTargets, 2)
        XCTAssertEqual(defaultActions, 2)
        XCTAssertTrue(source.contains(".task(id: vm.permissionOnboardingState)"))
        XCTAssertTrue(source.contains("await Task.yield()"))
    }

    func testPermissionStateChangesAreAnnouncedWithoutReadingPrivateContent() throws {
        let source = try appSource("PermissionOnboardingView.swift")

        XCTAssertTrue(source.contains("handleStateChange(vm.permissionOnboardingState)"))
        XCTAssertTrue(source.contains("AccessibilityAnnouncer.post"))
        XCTAssertTrue(source.contains("Requesting voice permissions."))
        XCTAssertTrue(source.contains("Permission setup ready."))
        XCTAssertTrue(source.contains("lastAnnouncement = nil"))
        XCTAssertFalse(source.contains("AccessibilityAnnouncer.post(message)"))
    }

    func testStarterConsentAndTerminalStatesRestoreDeterministicFocus() throws {
        let source = try appSource("StarterProfileView.swift")

        XCTAssertTrue(source.contains("@FocusState private var focusedControl: FocusTarget?"))
        XCTAssertFalse(source.contains("@AccessibilityFocusState"),
                       "the explicit state announcement owns VoiceOver speech")
        XCTAssertTrue(source.contains("case source(StarterProfileSource)"))
        XCTAssertTrue(source.contains("case reviewPrimary"))
        XCTAssertTrue(source.contains("case failurePrimary"))
        XCTAssertTrue(source.contains(".source(.documents)"))
        XCTAssertTrue(source.contains(".focused($focusedControl, equals: .source(source))"))
        XCTAssertTrue(source.contains(".focused($focusedControl, equals: .reviewPrimary)"))
        XCTAssertTrue(source.contains(".focused($focusedControl, equals: .failurePrimary)"))
        XCTAssertTrue(source.contains(".task(id: vm.starterProfileState)"))
        XCTAssertTrue(source.contains("await Task.yield()"))
    }

    func testFocusRetriesWhenTheContainingPanelBecomesKeyAfterSystemUI() throws {
        let permission = try appSource("PermissionOnboardingView.swift")
        let starter = try appSource("StarterProfileView.swift")

        XCTAssertTrue(permission.contains("NSWindow.didBecomeKeyNotification"))
        XCTAssertTrue(permission.contains("NSWindow.didResignKeyNotification"))
        XCTAssertTrue(permission.contains("object: newWindow"))
        XCTAssertTrue(permission.contains("OnboardingKeyWindowObserver { panelIsKey = $0 }"))
        XCTAssertTrue(starter.contains("OnboardingKeyWindowObserver { panelIsKey = $0 }"))
        XCTAssertTrue(permission.contains(".task(id: panelIsKey)"))
        XCTAssertTrue(starter.contains(".task(id: panelIsKey)"))
        XCTAssertTrue(permission.contains("guard panelIsKey"))
        XCTAssertTrue(starter.contains("guard panelIsKey"))
    }

    func testStarterPrimaryActionsUseReturn() throws {
        let source = try appSource("StarterProfileView.swift")
        let defaultActions = source.components(separatedBy: ".keyboardShortcut(.defaultAction)").count - 1

        XCTAssertEqual(defaultActions, 3, "Build, Done, and Try again must be Return actions")
    }

    func testStarterAsyncStatesPostConciseAnnouncements() throws {
        let source = try appSource("StarterProfileView.swift")

        XCTAssertTrue(source.contains("handleStateChange(vm.starterProfileState)"))
        XCTAssertTrue(source.contains("AccessibilityAnnouncer.post"))
        XCTAssertTrue(source.contains("Building starter profile."))
        XCTAssertTrue(source.contains("Starter profile ready."))
        XCTAssertTrue(source.contains("Starter profile failed."))
        XCTAssertTrue(source.contains("lastAnnouncement = nil"))
        XCTAssertFalse(source.contains("AccessibilityAnnouncer.post(message)"))
    }

    func testOnboardingLeavesEscapeWithTheParentSurface() throws {
        let permission = try appSource("PermissionOnboardingView.swift")
        let starter = try appSource("StarterProfileView.swift")
        let surface = try appSource("NotchSurfaceView.swift")

        XCTAssertFalse(permission.contains(".onExitCommand"))
        XCTAssertFalse(starter.contains(".onExitCommand"))
        XCTAssertFalse(permission.contains(".keyboardShortcut(.cancelAction)"))
        XCTAssertFalse(starter.contains(".keyboardShortcut(.cancelAction)"))
        XCTAssertTrue(surface.contains(".onExitCommand"))
    }
}
