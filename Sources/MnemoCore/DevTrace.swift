import Foundation

// DevTrace.swift — the loopback-only deep-observability bus for the developer
// dashboard. It is created ONLY when devtools is enabled; the query path holds
// it as an optional and every emit is `trace?.…`, so normal runs pay nothing
// and no document text ever leaves the process. Nothing here egresses: it is a
// pure in-memory fan-out consumed by the local SSE server.

/// A minimal, self-describing JSON value — the payload type for `TraceEvent`.
/// Encodes to plain, inline JSON (no case tags) so the browser can read it
/// directly.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        // Order matters: Bool before Int (JSON true/false), Int before Double
        // (keep 5 an int; 5.0 falls through to double).
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                debugDescription: "Unsupported JSON value"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// Literal ergonomics so instrumentation call sites stay legible, e.g.
// `.object(["intent": "lookup", "count": 5])`.
extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}
extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}
extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

/// One observable moment in the query lifecycle. Serialized verbatim over SSE.
/// `phase` is one of `begin` | `end` | `info` | `token`; `begin`/`end` pairs
/// (matched by `stage` within a `queryId`) carry per-stage timing.
public struct TraceEvent: Codable, Sendable, Equatable {
    public var queryId: String
    public var seq: Int
    public var atMs: Int
    public var stage: String
    public var phase: String
    public var durationMs: Int?
    public var message: String?
    public var data: JSONValue?

    public init(queryId: String, seq: Int, atMs: Int, stage: String, phase: String,
                durationMs: Int? = nil, message: String? = nil, data: JSONValue? = nil) {
        self.queryId = queryId
        self.seq = seq
        self.atMs = atMs
        self.stage = stage
        self.phase = phase
        self.durationMs = durationMs
        self.message = message
        self.data = data
    }
}

/// In-memory broadcast bus: fans one `TraceEvent` out to every live subscriber
/// and replays a bounded recent backlog to late subscribers (so the dashboard
/// catches an in-flight query when it connects mid-stream).
public actor DevTrace {
    private var seqCounter = 0
    private var subscribers: [UUID: AsyncStream<TraceEvent>.Continuation] = [:]
    private var recent: [TraceEvent] = []
    private let backlogCap: Int

    public init(backlogCap: Int = 500) { self.backlogCap = backlogCap }

    /// Live stream of events; the recent backlog is replayed first.
    public func subscribe() -> AsyncStream<TraceEvent> {
        let (stream, continuation) = AsyncStream<TraceEvent>.makeStream(bufferingPolicy: .unbounded)
        for e in recent { continuation.yield(e) }
        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    /// Emit a pre-built event (respects its `seq`) — used by tests and callers
    /// that mint their own events.
    public func emit(_ event: TraceEvent) { store(event) }

    /// Emit an event with a bus-assigned monotonic `seq` — used by `QueryTracer`.
    public func append(queryId: String, atMs: Int, stage: String, phase: String,
                       durationMs: Int?, message: String?, data: JSONValue?) {
        let event = TraceEvent(queryId: queryId, seq: seqCounter, atMs: atMs, stage: stage,
                               phase: phase, durationMs: durationMs, message: message, data: data)
        seqCounter += 1
        store(event)
    }

    public func recentEvents() -> [TraceEvent] { recent }

    private func store(_ event: TraceEvent) {
        recent.append(event)
        if recent.count > backlogCap { recent.removeFirst(recent.count - backlogCap) }
        for continuation in subscribers.values { continuation.yield(event) }
    }

    private func removeSubscriber(_ id: UUID) { subscribers[id] = nil }
}

/// Per-query convenience over `DevTrace`: stamps the shared `queryId` and a
/// relative `atMs`, and lets `QueryService` emit stage events without repeating
/// bookkeeping. Held as an optional in the query path (nil when devtools off).
public struct QueryTracer: Sendable {
    public let queryId: String
    private let trace: DevTrace
    private let start: Date

    public init(queryId: String = UUID().uuidString, trace: DevTrace, start: Date = Date()) {
        self.queryId = queryId
        self.trace = trace
        self.start = start
    }

    public func event(_ stage: String, _ phase: String = "info", message: String? = nil,
                      durationMs: Int? = nil, data: JSONValue? = nil) async {
        let atMs = max(0, Int(Date().timeIntervalSince(start) * 1000))
        await trace.append(queryId: queryId, atMs: atMs, stage: stage, phase: phase,
                           durationMs: durationMs, message: message, data: data)
    }

    /// Milliseconds elapsed since the query started — for `durationMs` on `end`.
    public func nowMs() -> Int { max(0, Int(Date().timeIntervalSince(start) * 1000)) }
}
