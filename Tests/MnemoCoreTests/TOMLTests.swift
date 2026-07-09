import XCTest
@testable import MnemoCore

final class TOMLTests: XCTestCase {
    func testParsesSectionsAndScalars() throws {
        let text = """
        # comment
        root_key = "hi"

        [engine]
        base_url = "http://127.0.0.1:6767"
        rerank = true
        limit = 12
        threshold = 0.35
        """
        let t = try TOML.parse(text)
        XCTAssertEqual(t[""]?["root_key"], .string("hi"))
        XCTAssertEqual(t["engine"]?["base_url"], .string("http://127.0.0.1:6767"))
        XCTAssertEqual(t["engine"]?["rerank"], .bool(true))
        XCTAssertEqual(t["engine"]?["limit"], .int(12))
        XCTAssertEqual(t["engine"]?["threshold"], .double(0.35))
    }

    func testStripsInlineCommentsAndWhitespace() throws {
        let t = try TOML.parse("[x]\n a = \"v\"   # trailing\n")
        XCTAssertEqual(t["x"]?["a"], .string("v"))
    }
}
