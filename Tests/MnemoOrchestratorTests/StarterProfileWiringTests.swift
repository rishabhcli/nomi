import Foundation
import XCTest

final class StarterProfileWiringTests: XCTestCase {
    private func source(_ name: String) throws -> String {
        try String(contentsOfFile: "Sources/MnemoApp/\(name)", encoding: .utf8)
    }

    func testFolderConsentStartsWithNoSelectionsAndBuildRequiresOne() throws {
        let viewModel = try source("NotchViewModel.swift")
        let view = try source("StarterProfileView.swift")

        XCTAssertTrue(viewModel.contains(
            "selectedStarterProfileSources: Set<StarterProfileSource> = []"
        ))
        XCTAssertTrue(view.contains(".disabled(vm.selectedStarterProfileSources.isEmpty)"))
    }

    func testStarterProfileIsRenderedByTheRealNotchSurface() throws {
        let surface = try source("NotchSurfaceView.swift")

        XCTAssertTrue(surface.contains("StarterProfileView(vm: vm)"))
        XCTAssertTrue(surface.contains("starterProfile: showsOnboarding"))
    }

    func testEligibilityOfferRunsFromStackReadyAndOpensTheResidentPanel() throws {
        let controller = try source("NotchController.swift")
        let ready = controller.components(separatedBy: "vm.onStackReady =").last ?? ""

        XCTAssertTrue(ready.contains("await self.vm.offerStarterProfileAfterPermissions()"))
        XCTAssertTrue(ready.contains("self.panel.makeKeyAndOrderFront(nil)"))
    }

    func testDismissCancelsOwnedStarterProfileWorkBeforeHiding() throws {
        let viewModel = try source("NotchViewModel.swift")
        let dismiss = viewModel.components(separatedBy: "func dismiss() {").dropFirst().first ?? ""

        XCTAssertTrue(dismiss.contains("starterProfileTask?.cancel()"))
        XCTAssertTrue(dismiss.contains("starterProfileGeneration &+= 1"))
        XCTAssertTrue(dismiss.contains("starterProfilePresented = false"))
    }
}
