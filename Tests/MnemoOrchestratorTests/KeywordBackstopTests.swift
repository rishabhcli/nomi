import XCTest
@testable import MnemoOrchestrator

final class KeywordBackstopTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "backstop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        # Job Finder Handoff
        Current state: research complete.
        Chrome control is paused at the user's request; resume browser control only when asked.
        Verified submitted count is 0.
        """.write(to: dir.appending(path: "job-readme.md"), atomically: true, encoding: .utf8)
        try """
        # Profile
        Resume file: Bansal Resume 2026.pdf
        """.write(to: dir.appending(path: "profile.md"), atomically: true, encoding: .utf8)
        try """
        # Application Profile Draft
        Use this only for applications that pass the tracker filters.

        ## Known Personal Info
        - Location: Fremont, CA
        - Email: someone@example.com
        """.write(to: dir.appending(path: "application-profile.md"), atomically: true, encoding: .utf8)
        try """
        # Eligible Criteria Prune
        Pruned on 2026-05-26 from `linkedin-high-reach-leads.csv`.

        - Rows before: 421
        - Rows kept: 47
        """.write(to: dir.appending(path: "prune-summary.md"), atomically: true, encoding: .utf8)
        try Data([0xFF, 0xD8, 0xFF, 0x00]).write(to: dir.appending(path: "binary.jpg"))
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testSalientTermsSkipStopwords() {
        let terms = KeywordBackstop.salientTerms("What is the status of Chrome control in my job search?")
        XCTAssertTrue(terms.contains("chrome"))
        XCTAssertFalse(terms.contains("what"))
        XCTAssertFalse(terms.contains("the"))
    }

    func testUncoveredFindsMissingTerms() {
        let ev = [Retrieved(memory: "Job search research is complete.", similarity: 0.7,
                            source: .init(docId: "a", path: "/a.md", title: "a"))]
        let missing = KeywordBackstop.uncovered(terms: ["chrome", "search"], in: ev)
        XCTAssertEqual(missing, ["chrome"], "'search' is covered by evidence; 'chrome' is not")
    }

    func testGrepFindsParagraphInMount() {
        let hits = KeywordBackstop.grep(term: "chrome", root: dir.path, maxMatches: 3)
        XCTAssertEqual(hits.count, 1)
        XCTAssertTrue(hits[0].memory.contains("Chrome control is paused"))
        XCTAssertTrue(hits[0].source.title.contains("job-readme"))
    }

    func testGrepSkipsBinaryAndMissingTerm() {
        XCTAssertTrue(KeywordBackstop.grep(term: "zzzznotthere", root: dir.path, maxMatches: 3).isEmpty)
    }

    func testRescueMergesOnlyUncovered() {
        let ev = [Retrieved(memory: "Resume file: Bansal Resume 2026.pdf", similarity: 0.8,
                            source: .init(docId: "p", path: "/profile.md", title: "Profile"))]
        let (merged, note) = KeywordBackstop.rescue(query: "What is my resume filename and Chrome status?",
                                                    evidence: ev, mountRoot: dir.path)
        XCTAssertNotNil(note)
        XCTAssertTrue(merged.contains { $0.memory.contains("Chrome control is paused") })
        // Evidence already covering "resume"/"bansal" is kept, not duplicated.
        XCTAssertEqual(merged.filter { $0.source.title == "Profile" }.count, 1)
    }

    func testRescueNoopWhenCovered() {
        let ev = [Retrieved(memory: "Chrome control is paused at the user's request.", similarity: 0.8,
                            source: .init(docId: "j", path: "/j.md", title: "J"))]
        let (merged, note) = KeywordBackstop.rescue(query: "chrome control status?",
                                                    evidence: ev, mountRoot: dir.path)
        XCTAssertNil(note)
        XCTAssertEqual(merged.count, ev.count)
    }

    func testStemMatchesInflections() {
        // "located" must match a file that only says "Location:".
        let (merged, note) = KeywordBackstop.rescue(
            query: "Where am I located according to my application profile?",
            evidence: [], mountRoot: dir.path)
        XCTAssertNotNil(note)
        XCTAssertTrue(merged.contains { $0.memory.contains("Fremont") },
                      "stem 'locat' should pull the Location paragraph: \(merged.map(\.memory))")
    }

    func testNumericQuestionPrefersDigitParagraph() {
        let (merged, _) = KeywordBackstop.rescue(
            query: "How many rows existed before the LinkedIn leads prune?",
            evidence: [], mountRoot: dir.path)
        XCTAssertTrue(merged.contains { $0.memory.contains("421") },
                      "digit-bearing prune paragraph should be rescued: \(merged.map(\.memory))")
    }

    func testHeadingBodyExtension() {
        // A match on a heading-only paragraph must carry its body along.
        let hits = KeywordBackstop.best(terms: ["eligible"], root: dir.path,
                                        wantDigits: false, maxMatches: 2)
        XCTAssertTrue(hits.contains { $0.memory.contains("Pruned on") })
    }

    func testFindsNestedBinaryByExactFilename() throws {
        let nested = dir.appending(path: "Archives/Contracts")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appending(path: "Orion SSD Archive.pdf")
        try Data([0x25, 0x50, 0x44, 0x46]).write(to: file)

        let hits = KeywordBackstop.best(
            terms: ["orion", "ssd", "archive"],
            root: dir.path,
            wantDigits: false,
            maxMatches: 3
        )

        XCTAssertEqual(hits.first?.source.path, file.resolvingSymlinksInPath().path)
        XCTAssertTrue(hits.first?.memory.contains("Orion SSD Archive.pdf") == true)
    }
}
