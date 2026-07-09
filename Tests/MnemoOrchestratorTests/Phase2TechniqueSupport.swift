import XCTest
@testable import MnemoOrchestrator

/// Shared fixtures for Phase 2 D-0251..D-0500 technique tests.
enum Phase2TechniqueSupport {
    static func sampleMemory(id: String = "m1", forgotten: Bool = false,
                             forgetAfter: String? = nil) -> MemoryEntry {
        MemoryEntry(id: id, memory: "User prefers Bazel for builds.", version: 1,
                    isLatest: true, isForgotten: forgotten, isStatic: false,
                    parentMemoryId: nil, rootMemoryId: id,
                    forgetAfter: forgetAfter, forgetReason: forgotten ? "user" : nil, history: [])
    }

    static func sampleRetrieved(docId: String = "d1", memory: String = "Project uses Bazel.") -> Retrieved {
        Retrieved(memory: memory, similarity: 0.85,
                  source: SourceLocator(docId: docId, path: "/notes/\(docId).md",
                                        title: "\(docId).md", updatedAt: "2026-01-01T00:00:00Z"))
    }

    static func sampleProfile() -> Profile {
        Profile(statics: ["Works on Mnemo."], dynamics: ["Asked about Bazel."],
                memories: [sampleRetrieved()])
    }

    static func assertLoopbackOnly(_ host: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(EgressGuard.isLoopbackHost(host), file: file, line: line)
    }

    static func assertNonLoopback(_ host: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(EgressGuard.isLoopbackHost(host), file: file, line: line)
    }

    static func assertEventsRenderable(_ events: [QueryEvent],
                                       file: StaticString = #file, line: UInt = #line) {
        var state = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        for e in events {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertFalse(events.isEmpty, file: file, line: line)
    }
}
