import XCTest
@testable import MnemoSupervisor

final class OllamaWarmupTests: XCTestCase {
    func testWarmupBodyPinsModelAndKeepAlive() throws {
        let data = try OllamaWarmup.requestBody(model: "gpt-oss:20b", keepAlive: "30m")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["model"] as? String, "gpt-oss:20b")
        XCTAssertEqual(obj["keep_alive"] as? String, "30m")
        XCTAssertEqual(obj["stream"] as? Bool, false)
        // The warm-up must not generate a long completion — bounded tokens.
        let opts = obj["options"] as! [String: Any]
        XCTAssertEqual(opts["num_predict"] as? Int, 1)
    }
}
