import XCTest
@testable import MnemoOrchestrator

/// On-device extraction for media the engine build can't process locally:
/// Vision OCR (image/scanned-pdf), PDFKit (text-layer pdf), textutil (docx),
/// Speech (audio/video). All offline — the whole point.
final class LocalExtractorTests: XCTestCase {
    static let corpus = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()           // Tests/MnemoOrchestratorTests
        .deletingLastPathComponent()           // Tests
        .appending(path: "Fixtures/corpus")

    func testOCRsPNG() async throws {
        let text = try await LocalExtractor.extract(Self.corpus.appending(path: "fixture-image.png"))
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.lowercased().contains("rotates every 45 days"),
                      "OCR missed the known fact; got: \(text ?? "nil")")
    }

    func testOCRsScannedPDF() async throws {
        let text = try await LocalExtractor.extract(Self.corpus.appending(path: "fixture-scanned.pdf"))
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.lowercased().contains("september 14"),
                      "scanned-PDF OCR missed the known fact; got: \(text ?? "nil")")
    }

    func testExtractsDocx() async throws {
        let text = try await LocalExtractor.extract(Self.corpus.appending(path: "fixture-doc.docx"))
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("250 milliseconds"),
                      "docx extraction missed the known fact; got: \(text ?? "nil")")
    }

    func testTranscribesAudioMemo() async throws {
        let text = try await LocalExtractor.extract(Self.corpus.appending(path: "fixture-memo.m4a"))
        XCTAssertNotNil(text)
        let t = text!.lowercased()
        XCTAssertTrue(t.contains("badge") || t.contains("seven three nine two") || t.contains("7392"),
                      "transcription missed the known fact; got: \(text ?? "nil")")
    }

    func testUnknownTypeReturnsNil() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: "mnemo-unknown.zzz")
        try Data([0x00, 0x01]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let text = try await LocalExtractor.extract(tmp)
        XCTAssertNil(text)
    }
}
