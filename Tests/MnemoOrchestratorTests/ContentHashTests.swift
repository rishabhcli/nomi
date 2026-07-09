import XCTest
@testable import MnemoOrchestrator

final class ContentHashTests: XCTestCase {
    func tempFile(_ contents: String, name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "mnemo-hash-\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testSameContentSameHashAcrossPaths() throws {
        let a = try tempFile("identical bytes", name: "a")
        let b = try tempFile("identical bytes", name: "b")
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        XCTAssertEqual(try ContentHash.sha256(of: a), try ContentHash.sha256(of: b))
    }

    func testDifferentContentDifferentHash() throws {
        let a = try tempFile("alpha", name: "c")
        let b = try tempFile("beta", name: "d")
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        XCTAssertNotEqual(try ContentHash.sha256(of: a), try ContentHash.sha256(of: b))
    }

    func testKnownVector() throws {
        // sha256("abc") — classic test vector
        let f = try tempFile("abc", name: "v")
        defer { try? FileManager.default.removeItem(at: f) }
        XCTAssertEqual(try ContentHash.sha256(of: f),
                       "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testCacheAvoidsRehashUntilFileChanges() async throws {
        let f = try tempFile("cache me", name: "e")
        defer { try? FileManager.default.removeItem(at: f) }
        let cache = HashCache()
        let h1 = try await cache.hash(of: f.path)
        let h2 = try await cache.hash(of: f.path)
        XCTAssertEqual(h1, h2)
        let hits = await cache.cacheHits
        XCTAssertEqual(hits, 1, "second lookup must come from cache")
        // mutate → size/mtime change → rehash
        try "cache me changed".write(to: f, atomically: true, encoding: .utf8)
        let h3 = try await cache.hash(of: f.path)
        XCTAssertNotEqual(h1, h3)
    }
}
