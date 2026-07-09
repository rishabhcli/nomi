import XCTest
@testable import MnemoCore

final class ConfigTests: XCTestCase {
    static let sample = """
    [engine]
    base_url = "http://127.0.0.1:6767"
    byom = "ollama"
    embeddings = "local"
    [model]
    runtime_base_url = "http://127.0.0.1:11434"
    synthesis = "gpt-oss:20b"
    fallback = "qwen3:4b"
    keep_alive = "30m"
    [smfs]
    mount_point = "~/Mnemo/memory"
    backing_store = "http://127.0.0.1:6767"
    [sync]
    poll_seconds = 30
    [retrieval]
    default_mode = "memories"
    rerank = true
    threshold = 0.35
    limit = 12
    """

    func testLoadsAllFields() throws {
        let c = try MnemoConfig.load(from: Self.sample)
        XCTAssertEqual(c.engine.baseURL.absoluteString, "http://127.0.0.1:6767")
        XCTAssertEqual(c.model.synthesis, "gpt-oss:20b")
        XCTAssertEqual(c.smfs.backingStore.absoluteString, "http://127.0.0.1:6767")
        XCTAssertEqual(c.sync.pollSeconds, 30)
        XCTAssertEqual(c.retrieval.limit, 12)
        XCTAssertEqual(c.retrieval.threshold, 0.35, accuracy: 0.0001)
    }

    func testMissingKeyThrows() {
        XCTAssertThrowsError(try MnemoConfig.load(from: "[engine]\nbyom = \"ollama\"\n"))
    }

    func testBenchSampleSizeDefault() throws {
        let c = try MnemoConfig.load(from: Self.sample)
        XCTAssertEqual(c.bench.sampleSize, 4)
    }

    func testDreamingIntervalParsed() throws {
        let text = Self.sample + "\n[dreaming]\ninterval = \"12h\"\n"
        let c = try MnemoConfig.load(from: text)
        XCTAssertEqual(c.dreaming.intervalHours, 12)
    }

    func testInvalidBenchSampleSizeRejected() throws {
        let text = Self.sample + "\n[bench]\nsample_size = 0\n"
        XCTAssertThrowsError(try MnemoConfig.load(from: text).validateInvariant())
    }
}
