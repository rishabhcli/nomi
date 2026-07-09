import XCTest
@testable import MnemoOrchestrator

final class ProfileDecodeTests: XCTestCase {
    // Captured from the live engine: POST /v4/profile
    static let json = """
    {"profile":{"static":["User's name is Alex."],
      "dynamic":["User's favorite build tool is Bazel.","User switched to Bazel in March 2025."]},
     "searchResults":{"results":[
       {"id":"m1","memory":"User's favorite build tool is Bazel.","similarity":0.78,
        "filepath":null,
        "documents":[{"id":"d1","title":"# Build tooling notes"}]}]}}
    """

    func testDecodesProfileEnvelope() throws {
        let p = try JSONDecoder().decode(EngineClient.ProfileEnvelope.self, from: Data(Self.json.utf8))
        XCTAssertEqual(p.profile.static, ["User's name is Alex."])
        XCTAssertEqual(p.profile.dynamic.count, 2)
        XCTAssertEqual(p.searchResults.results.count, 1)
    }
}

final class ProfileDedupeTests: XCTestCase {
    func testDedupePriorityStaticOverDynamicOverSearch() {
        let mem = Retrieved(memory: "User's favorite build tool is Bazel.", similarity: 0.7,
                            source: .init(docId: "d1", path: "/f.md", title: "f"))
        let p = Profile(
            statics: ["User's favorite build tool is Bazel.", "User's name is Alex."],
            dynamics: ["User's favorite build tool is Bazel.",   // dup of static → dropped
                       "User switched to Bazel in March 2025."],
            memories: [mem,                                       // dup of static → dropped
                       Retrieved(memory: "User used CMake for four years.", similarity: 0.6,
                                 source: .init(docId: "d1", path: "/f.md", title: "f"))])
        let d = ProfileDedupe.dedupe(p)
        XCTAssertEqual(d.statics.count, 2)
        XCTAssertEqual(d.dynamics, ["User switched to Bazel in March 2025."])
        XCTAssertEqual(d.memories.map(\.memory), ["User used CMake for four years."])
    }

    func testNormalizationIgnoresCaseAndPunctuation() {
        let p = Profile(statics: ["User prefers dark mode."],
                        dynamics: ["user prefers DARK MODE"],
                        memories: [])
        let d = ProfileDedupe.dedupe(p)
        XCTAssertTrue(d.dynamics.isEmpty, "case/punct variant is the same fact")
    }
}
