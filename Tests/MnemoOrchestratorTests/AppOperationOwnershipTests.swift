import Foundation
import XCTest

final class AppOperationOwnershipTests: XCTestCase {
    private func source(_ name: String) throws -> String {
        try String(
            contentsOfFile: "Sources/MnemoApp/\(name)",
            encoding: .utf8
        )
    }

    func testRecoveryButtonsEnterTheOwnedCancellableOperation() throws {
        let blocks = try source("SurfaceBlocks.swift")
        XCTAssertTrue(blocks.contains("vm.beginRecovery(.broaden)"))
        XCTAssertTrue(blocks.contains("vm.beginRecovery(.restartEngine)"))
        XCTAssertFalse(blocks.contains("Task { await vm.recover"))
    }

    func testLateAsyncCommandResultsAreGenerationGuarded() throws {
        let viewModel = try source("NotchViewModel.swift")
        XCTAssertTrue(viewModel.contains("private func isCurrent(_ generation: Int)"))
        XCTAssertTrue(viewModel.contains("guard isCurrent(generation) else { return }"))
        XCTAssertTrue(viewModel.contains("await viewModel.recover(recovery, generation: generation)"))
    }

    func testMountedDriveWorkIsVisibleWithoutHoverAndHeldWhileActive() throws {
        let viewModel = try source("NotchViewModel.swift")
        let controller = try source("NotchController.swift")
        XCTAssertTrue(viewModel.contains("activity.phase == .detected, state.phase == .idle"))
        XCTAssertTrue(controller.contains("guard !vm.volumeActivityPreventsAutoCollapse"))
    }

    func testEgressMonitorArmsFromTheProvenStackReadyPath() throws {
        let controller = try source("NotchController.swift")
        let readyBlock = controller.components(separatedBy: "vm.onStackReady =").last ?? ""
        XCTAssertTrue(readyBlock.contains("await self.egressMonitor.start()"))
        XCTAssertFalse(controller.contains("do {\n                await egressMonitor.start()"))
    }
}
