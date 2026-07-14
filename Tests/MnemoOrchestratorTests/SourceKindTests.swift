import XCTest
@testable import MnemoOrchestrator

/// M13: every ingested document is tagged with the source it came from, and each
/// source maps to its own Supermemory container so it can be scoped, toggled, and
/// forgotten independently.
final class SourceKindTests: XCTestCase {

    func testEachSourceMapsToADistinctContainer() {
        let containers = SourceKind.allCases.map(\.container)
        XCTAssertEqual(Set(containers).count, SourceKind.allCases.count,
                       "every SourceKind must map to a unique container")
        XCTAssertEqual(SourceKind.file.container, "files")
        XCTAssertEqual(SourceKind.messages.container, "messages")
    }

    func testStampWritesSourceKindAndPreservesExistingMetadata() {
        let stamped = SourceProvenance.stamp(.messages, into: ["mnemo_original_path": "/x/y.txt"])
        XCTAssertEqual(stamped[SourceProvenance.sourceKindKey], "messages")
        XCTAssertEqual(stamped["mnemo_original_path"], "/x/y.txt",
                       "existing provenance metadata must be preserved")
    }

    func testKindRoundTripsFromMetadata() {
        let stamped = SourceProvenance.stamp(.mail)
        XCTAssertEqual(SourceProvenance.kind(fromMetadata: stamped), .mail)
    }

    func testMissingOrUnknownSourceKindIsNil() {
        XCTAssertNil(SourceProvenance.kind(fromMetadata: nil))
        XCTAssertNil(SourceProvenance.kind(fromMetadata: [:]))
        XCTAssertNil(SourceProvenance.kind(fromMetadata: [SourceProvenance.sourceKindKey: "bogus"]))
    }
}
