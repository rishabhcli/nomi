import Foundation
import XCTest
@testable import MnemoOrchestrator

final class NotchPanelInteractionPolicyTests: XCTestCase {
    func testIdleSurfacePassesEventsThrough() {
        XCTAssertFalse(NotchPanelInteraction.acceptsEvents(
            phase: .idle, isListening: false, showsOnboarding: false))
    }

    func testEveryExpandedSurfaceAcceptsEvents() {
        for phase in [NotchPhase.input, .searching, .answering, .state] {
            XCTAssertTrue(NotchPanelInteraction.acceptsEvents(
                phase: phase, isListening: false, showsOnboarding: false))
        }
    }

    func testListeningSurfaceRemainsInteractiveEvenIfPhaseIsIdle() {
        XCTAssertTrue(NotchPanelInteraction.acceptsEvents(
            phase: .idle, isListening: true, showsOnboarding: false))
    }

    func testOnboardingRemainsInteractiveEvenIfPhaseIsIdle() {
        XCTAssertTrue(NotchPanelInteraction.acceptsEvents(
            phase: .idle, isListening: false, showsOnboarding: true))
    }

    func testExpandedPanelCapturesOnlyTheVisibleSurface() {
        let panel = CGRect(x: 100, y: 200, width: 640, height: 652)
        let surface = CGSize(width: 360, height: 120)

        XCTAssertTrue(NotchPanelInteraction.capturesMouse(
            allowsInteraction: true,
            pointer: CGPoint(x: panel.midX, y: panel.maxY - 60),
            panelFrame: panel,
            surfaceSize: surface
        ))
        XCTAssertFalse(NotchPanelInteraction.capturesMouse(
            allowsInteraction: true,
            pointer: CGPoint(x: panel.midX, y: panel.minY + 40),
            panelFrame: panel,
            surfaceSize: surface
        ), "transparent space below a short surface must pass through")
        XCTAssertFalse(NotchPanelInteraction.capturesMouse(
            allowsInteraction: false,
            pointer: CGPoint(x: panel.midX, y: panel.maxY - 60),
            panelFrame: panel,
            surfaceSize: surface
        ))
    }
}

final class NotchSummonDisplayPolicyTests: XCTestCase {
    func testPointerSummonPrefersPointerDisplay() {
        XCTAssertEqual(NotchSummonDisplayPolicy.preferredDisplay(
            origin: .pointer,
            pointerDisplay: "pointer",
            keyWindowDisplay: "key-window",
            mainDisplay: "main",
            fallbackDisplay: "fallback"
        ), "pointer")
    }

    func testHotkeySummonPrefersKeyWindowThenMainDisplay() {
        XCTAssertEqual(NotchSummonDisplayPolicy.preferredDisplay(
            origin: .hotkey,
            pointerDisplay: "pointer",
            keyWindowDisplay: "key-window",
            mainDisplay: "main",
            fallbackDisplay: "fallback"
        ), "key-window")

        XCTAssertEqual(NotchSummonDisplayPolicy.preferredDisplay(
            origin: .hotkey,
            pointerDisplay: "pointer",
            keyWindowDisplay: nil,
            mainDisplay: "main",
            fallbackDisplay: "fallback"
        ), "main", "hotkey summon must not jump to a remote pointer display")
    }

    func testSummonFallsBackWhenPreferredDisplaysAreUnavailable() {
        XCTAssertEqual(NotchSummonDisplayPolicy.preferredDisplay(
            origin: .pointer,
            pointerDisplay: nil,
            keyWindowDisplay: nil,
            mainDisplay: nil,
            fallbackDisplay: "fallback"
        ), "fallback")
        XCTAssertEqual(NotchSummonDisplayPolicy.preferredDisplay(
            origin: .hotkey,
            pointerDisplay: "pointer",
            keyWindowDisplay: nil,
            mainDisplay: nil,
            fallbackDisplay: "fallback"
        ), "fallback")
    }
}

final class NotchControllerWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testPanelKeyAndMouseEligibilityFollowSurfaceInteraction() throws {
        let panel = try appSource("NotchPanel.swift")
        let controller = try appSource("NotchController.swift")

        XCTAssertTrue(panel.contains("private(set) var acceptsInteraction = false"))
        XCTAssertTrue(panel.contains("ignoresMouseEvents = !NotchPanelInteraction.capturesMouse"))
        XCTAssertTrue(panel.contains("override var canBecomeKey: Bool { acceptsInteraction }"))
        XCTAssertTrue(controller.contains("NotchPanelInteraction.acceptsEvents"))
        XCTAssertTrue(controller.contains("combineLatest(dictation.$isListening)"))
        XCTAssertTrue(controller.contains("showsOnboarding:"))
        XCTAssertTrue(panel.contains("NotchPanelInteraction.capturesMouse"))
        XCTAssertTrue(controller.contains("panel.updatePointerLocation"))
        XCTAssertTrue(controller.contains("onSurfaceSizeChange:"))
    }

    func testIdleCollarUsesGlobalHoverToBecomeInteractiveBeforePressHold() throws {
        let main = try appSource("main.swift")
        let hover = try appSource("HoverDetector.swift")

        XCTAssertTrue(hover.contains("addGlobalMonitorForEvents(matching: .mouseMoved)"))
        XCTAssertTrue(hover.contains("handleMouseMove(at: event.locationInWindow)"))
        XCTAssertTrue(main.contains("onMove: { [weak self] location in"))
        XCTAssertTrue(main.contains("onArm: { [weak self] in self?.controller.summon(origin: .pointer) }"))
    }

    func testHoverAndHotkeyUseDistinctSummonOrigins() throws {
        let main = try appSource("main.swift")
        let controller = try appSource("NotchController.swift")

        XCTAssertTrue(main.contains("controller.summon(origin: .pointer)"))
        XCTAssertTrue(main.contains("c.summon(origin: .hotkey)"))
        XCTAssertTrue(controller.contains("func summon(origin: NotchSummonOrigin)"))
        XCTAssertTrue(controller.contains("NotchSummonDisplayPolicy.preferredDisplay"))
    }

    func testResignKeyDelegatesToOnboardingAwareControllerPolicy() throws {
        let main = try appSource("main.swift")
        let controller = try appSource("NotchController.swift")

        XCTAssertTrue(main.contains("handlePanelDidResignKey()"))
        XCTAssertTrue(controller.contains("func handlePanelDidResignKey()"))
        XCTAssertTrue(controller.contains("showsOnboarding:"))
        XCTAssertTrue(controller.contains("vm.showsPermissionOnboarding"))
        XCTAssertTrue(controller.contains("vm.showsStarterProfile"))
    }

    func testDisplayParameterChangesReanchorTheController() throws {
        let main = try appSource("main.swift")
        let controller = try appSource("NotchController.swift")

        XCTAssertTrue(main.contains("NSApplication.didChangeScreenParametersNotification"))
        XCTAssertTrue(main.contains("screenParametersDidChange()"))
        XCTAssertTrue(controller.contains("func screenParametersDidChange()"))
        XCTAssertTrue(controller.contains("anchoredDisplayID"))
        XCTAssertTrue(controller.contains("$0.mnemoDisplayID == displayID"))
    }

    func testDisplayReanchorDoesNotResetQueryState() throws {
        let controller = try appSource("NotchController.swift")
        let marker = "func screenParametersDidChange()"
        guard let start = controller.range(of: marker)?.lowerBound else {
            return XCTFail("screenParametersDidChange must be implemented")
        }
        let tail = controller[start...]
        let end = tail.range(of: "\n    func dismiss()")?.lowerBound ?? tail.endIndex
        let method = tail[..<end]

        XCTAssertFalse(method.contains("vm.summon"))
        XCTAssertFalse(method.contains("vm.dismiss"))
        XCTAssertFalse(method.contains("vm.state"))
    }
}
