import XCTest
@testable import MnemoCore

final class ConfigStrictTests: XCTestCase {
    func testUnknownSectionRejected() {
        let text = ConfigTests.sample + "\n[rogue]\nfoo = \"bar\"\n"
        XCTAssertThrowsError(try MnemoConfig.load(from: text)) { err in
            XCTAssertEqual(err as? ConfigError, .unknownKey("unknown section [rogue]"))
        }
    }

    func testUnknownKeyInKnownSectionRejected() {
        let text = ConfigTests.sample.replacingOccurrences(
            of: "[engine]",
            with: "[engine]\ncloud_fallback = \"https://evil.example\"\n")
        XCTAssertThrowsError(try MnemoConfig.load(from: text)) { err in
            XCTAssertEqual(err as? ConfigError, .unknownKey("engine.cloud_fallback"))
        }
    }

    func testInvalidLoggingLevelRejected() throws {
        let text = ConfigTests.sample + "\n[logging]\nlevel = \"trace\"\nrotation_mb = 50\n"
        XCTAssertThrowsError(try MnemoConfig.load(from: text).validateInvariant()) { err in
            if case let .invalidValue(field, _) = err as? ConfigError {
                XCTAssertEqual(field, "logging.level")
            } else { XCTFail("expected invalidValue") }
        }
    }

    func testLoggingOffUsesNullSink() throws {
        let text = ConfigTests.sample + "\n[logging]\nlevel = \"off\"\nrotation_mb = 50\n"
        let c = try MnemoConfig.load(from: text)
        let sink = QueryLogSinkFactory.make(config: c.logging)
        XCTAssertTrue(sink is NullQueryLogSink)
    }

    func testNonStrictLoadAllowsUnknownKeys() throws {
        let text = ConfigTests.sample + "\n[legacy]\nold_key = \"keep\"\n"
        let c = try MnemoConfig.load(from: text, strict: false)
        XCTAssertEqual(c.engine.baseURL.absoluteString, "http://127.0.0.1:6767")
    }
}
