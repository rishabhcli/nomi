import Foundation
import XCTest

final class AnswerSurfaceWiringTests: XCTestCase {
    private func appSource(_ name: String) throws -> String {
        try String(
            contentsOfFile: "Sources/MnemoApp/\(name)",
            encoding: .utf8
        )
    }

    func testSourcesRenderDuringSearchBeforeTheFirstAnswerToken() throws {
        let surface = try appSource("NotchSurfaceView.swift")

        XCTAssertTrue(surface.contains("SourceChipRow(sources: vm.state.sources)"))
    }

    func testAnswerActionsExposeExistingLocalCapabilities() throws {
        let blocks = try appSource("AnswerControls.swift")

        XCTAssertTrue(blocks.contains("narrator.toggle(vm.state.answer)"))
        XCTAssertTrue(blocks.contains("vm.feedback(positive: true)"))
        XCTAssertTrue(blocks.contains("vm.feedback(positive: false)"))
    }

    func testGeneratedFollowUpsAreRenderedAndSubmitted() throws {
        let blocks = try appSource("AnswerControls.swift")
        let model = try appSource("NotchViewModel.swift")

        XCTAssertTrue(blocks.contains("SurfaceUX.Suggestions.filtered(vm.state.suggestions)"))
        XCTAssertTrue(blocks.contains("vm.submitSuggestion(suggestion)"))
        XCTAssertTrue(model.contains("func submitSuggestion(_ suggestion: String)"))
    }
}
