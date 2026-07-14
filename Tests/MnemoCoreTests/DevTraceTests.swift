import XCTest
@testable import MnemoCore

/// DevTrace is the loopback-only deep-observability bus (dev tool). It must:
///  - serialize a TraceEvent to plain, inline JSON (the SSE wire format),
///  - fan one event out to every live subscriber, in order,
///  - replay the recent backlog to a late subscriber (so the dashboard sees
///    the in-flight query even if it connects mid-stream),
///  - stamp queryId + a monotonic seq via QueryTracer.
final class DevTraceTests: XCTestCase {

    func testTraceEventEncodesInlineJSONAndRoundTrips() throws {
        let event = TraceEvent(
            queryId: "q1", seq: 3, atMs: 42, stage: "assemble", phase: "end",
            durationMs: 7, message: "ctx",
            data: .object([
                "contextTokens": .int(1234),
                "candidates": .array([.object(["score": .double(0.5), "aboveThreshold": .bool(true)])]),
            ]))

        let encoded = try JSONEncoder().encode(event)
        let json = String(data: encoded, encoding: .utf8)!

        // Plain, inline JSON — no enum tags like {"double":0.5}.
        XCTAssertTrue(json.contains("\"stage\":\"assemble\""), json)
        XCTAssertTrue(json.contains("\"contextTokens\":1234"), json)
        XCTAssertFalse(json.contains("\"double\""), "JSONValue must not tag its cases: \(json)")

        let decoded = try JSONDecoder().decode(TraceEvent.self, from: encoded)
        XCTAssertEqual(decoded, event)
    }

    func testNilOptionalFieldsAreOmitted() throws {
        let event = TraceEvent(queryId: "q", seq: 0, atMs: 0, stage: "route", phase: "end")
        let json = String(data: try JSONEncoder().encode(event), encoding: .utf8)!
        XCTAssertFalse(json.contains("durationMs"), json)
        XCTAssertFalse(json.contains("\"data\""), json)
    }

    func testDeliversEmittedEventsInOrder() async {
        let trace = DevTrace()
        let stream = await trace.subscribe()
        await trace.emit(TraceEvent(queryId: "q", seq: 0, atMs: 0, stage: "route", phase: "end"))
        await trace.emit(TraceEvent(queryId: "q", seq: 1, atMs: 1, stage: "done", phase: "end"))

        let got = await Self.take(2, from: stream)
        XCTAssertEqual(got.map(\.seq), [0, 1])
        XCTAssertEqual(got.map(\.stage), ["route", "done"])
    }

    func testFansOutToEverySubscriber() async {
        let trace = DevTrace()
        let s1 = await trace.subscribe()
        let s2 = await trace.subscribe()
        await trace.emit(TraceEvent(queryId: "q", seq: 0, atMs: 0, stage: "route", phase: "end"))
        await trace.emit(TraceEvent(queryId: "q", seq: 1, atMs: 0, stage: "done", phase: "end"))

        let g1 = await Self.take(2, from: s1)
        let g2 = await Self.take(2, from: s2)
        XCTAssertEqual(g1.map(\.seq), [0, 1])
        XCTAssertEqual(g2.map(\.seq), [0, 1])
    }

    func testReplaysBacklogToLateSubscriber() async {
        let trace = DevTrace()
        await trace.emit(TraceEvent(queryId: "q", seq: 0, atMs: 0, stage: "route", phase: "end"))
        await trace.emit(TraceEvent(queryId: "q", seq: 1, atMs: 0, stage: "done", phase: "end"))

        let stream = await trace.subscribe()   // connects AFTER the events
        let got = await Self.take(2, from: stream)
        XCTAssertEqual(got.map(\.seq), [0, 1])
    }

    func testQueryTracerStampsQueryIdAndMonotonicSeq() async {
        let trace = DevTrace()
        let stream = await trace.subscribe()
        let tracer = QueryTracer(queryId: "qX", trace: trace)
        await tracer.event("route", "end", message: "lookup")
        await tracer.event("assemble", "end")
        await tracer.event("done", "end")

        let got = await Self.take(3, from: stream)
        XCTAssertEqual(got.map(\.queryId), ["qX", "qX", "qX"])
        XCTAssertEqual(got.map(\.stage), ["route", "assemble", "done"])
        XCTAssertEqual(got.map(\.seq), [0, 1, 2])
        XCTAssertTrue(got.allSatisfy { $0.atMs >= 0 })
    }

    /// Collect exactly `n` events from a stream that has (at least) `n` buffered.
    private static func take(_ n: Int, from stream: AsyncStream<TraceEvent>) async -> [TraceEvent] {
        var out: [TraceEvent] = []
        for await e in stream {
            out.append(e)
            if out.count == n { break }
        }
        return out
    }
}
