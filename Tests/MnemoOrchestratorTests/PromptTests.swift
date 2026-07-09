import XCTest
@testable import MnemoOrchestrator

final class PromptTests: XCTestCase {
    func testSystemStatesContract() {
        XCTAssertTrue(Prompt.system.contains("only from the provided context"))
        XCTAssertTrue(Prompt.system.lowercased().contains("do not"))
    }
    func testContextTagsEachSpanWithSource() {
        let hit = Retrieved(memory: "I moved to SF.", similarity: 0.8,
            source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))
        let ctx = Prompt.context([hit])
        XCTAssertTrue(ctx.contains("I moved to SF."))
        XCTAssertTrue(ctx.contains("[source: f — /m/f.md @0-5]"))
        XCTAssertFalse(ctx.contains("Optional"))
    }

    func testContextOmitsSpanWhenUnresolved() {
        let hit = Retrieved(memory: "Fact.", similarity: 0.8,
            source: .init(docId: "d1", path: "/m/f.md", title: "f"))
        let ctx = Prompt.context([hit])
        XCTAssertTrue(ctx.contains("[source: f — /m/f.md]"))
        XCTAssertFalse(ctx.contains("Optional"))
        XCTAssertFalse(ctx.contains("@"))
    }
    func testEmptyContextIsExplicit() {
        XCTAssertTrue(Prompt.context([]).contains("NO CONTEXT"))
    }
}
