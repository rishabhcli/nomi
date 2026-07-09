import XCTest
@testable import MnemoSupervisor

final class OllamaBringupTests: XCTestCase {
    func testParsesModelNamesFromTags() throws {
        let json = """
        {"models":[{"name":"gpt-oss:20b","size":1},{"name":"qwen3:4b","size":2}]}
        """
        let names = try OllamaTags.models(in: Data(json.utf8))
        XCTAssertEqual(names, ["gpt-oss:20b", "qwen3:4b"])
    }

    func testModelPresenceCheck() throws {
        let json = #"{"models":[{"name":"qwen3:4b"}]}"#
        let names = try OllamaTags.models(in: Data(json.utf8))
        XCTAssertTrue(names.contains("qwen3:4b"))
        XCTAssertFalse(names.contains("gpt-oss:20b"))
    }

    func testMalformedTagsThrows() {
        XCTAssertThrowsError(try OllamaTags.models(in: Data("not json".utf8)))
    }
}
