import Foundation

/// Canonical product-doc contracts enforced by `ProductDocTests`.
/// Values here are the source of truth cross-linked from UI.md and PLAN.md.
public enum ProductDocContract {

    // MARK: - UI.md §7 motion tokens (Motion.swift)

    public struct MotionToken: Equatable, Sendable {
        public let name: String
        public let response: Double
        public let damping: Double
    }

    public static let motionTokens: [MotionToken] = [
        .init(name: "summon", response: 0.36, damping: 0.84),
        .init(name: "grow", response: 0.32, damping: 0.88),
        .init(name: "collapse", response: 0.30, damping: 0.90),
        .init(name: "glyph", response: 0.25, damping: 0.80),
    ]

    public static let dissolveDuration: Double = 0.20
    public static let revealDuration: Double = 0.22
    public static let staggerSeconds: Double = 0.06

    // MARK: - UI.md §4 surface dimensions

    public static let inputWidth: CGFloat = 520
    public static let bottomRadius: CGFloat = 46
    public static let idleRadius: CGFloat = 9
    public static let shoulderRadius: CGFloat = 12   // expanded concave shoulder
    public static let idleShoulder: CGFloat = 5      // collapsed concave shoulder
    public static let glassFraction: CGFloat = 0.36  // bottom Liquid Glass region
    public static let orbMaxFill: Double = 0.80
    public static let orbIdleFlow: Double = 0.06

    // MARK: - UI.md §9 terminal copy (NotchReducer.message)

    public static let terminalCopyKeys: [String] = [
        "indexing", "empty", "emptyCorpus", "modelNotLoaded", "engineUnreachable", "unsupportedAnswer"
    ]

    public static func terminalMessageSnippet(for key: String) -> String {
        switch key {
        case "indexing": return "Still indexing"
        case "empty": return "Nothing in your files matches"
        case "emptyCorpus": return "No files yet"
        case "modelNotLoaded": return "isn't loaded"
        case "engineUnreachable": return "isn't responding"
        case "unsupportedAnswer": return "won't guess"
        default: return ""
        }
    }

    // MARK: - PLAN.md Appendix B metrics (field names in structured logs)

    public static let appendixBMetrics: [String] = [
        "query_id", "route_intent", "effort_tier", "retrieval_hop_count",
        "first_token_ms", "total_ms", "egress_blocked_count",
        "verification_pass_rate", "context_token_count", "model_id", "terminal_state"
    ]

    // MARK: - Shared/ Codable field maps (engine JSON ↔ Swift)

    public static let sourceLocatorCodingKeys: [(swift: String, json: String)] = [
        ("docId", "doc_id"), ("charStart", "char_start"), ("charEnd", "char_end")
    ]

    public static let memoryEntryCodingKeys: [(swift: String, json: String)] = [
        ("isLatest", "isLatest"), ("isForgotten", "isForgotten"), ("isStatic", "isStatic"),
        ("parentMemoryId", "parentMemoryId"), ("rootMemoryId", "rootMemoryId"),
        ("forgetAfter", "forgetAfter"), ("forgetReason", "forgetReason"),
        ("documentIds", "documentIds")
    ]

    // MARK: - Hardware tier SLA (README.md + mnemo.toml)

    public struct HardwareTier: Equatable, Sendable {
        public let name: String
        public let minRAMGB: Int
        public let model: String
    }

    public static let hardwareTiers: [HardwareTier] = [
        .init(name: "recommended", minRAMGB: 16, model: "gpt-oss:20b"),
        .init(name: "floor", minRAMGB: 12, model: "qwen3:4b"),
    ]

    public static let slaFirstTokenMs: Int = 1500
    public static let slaSourcesRenderMs: Int = 1000

    // MARK: - Privacy indicator semantics

    public static let privacyCleanLabel = "clean"
    public static let privacyEgressPrefix = "egressDetected"

    // MARK: - Expressiveness timeline shapes

    public static let answerShapes: [String] = [
        "definition", "comparison", "timeline", "list", "synthesis"
    ]

    // MARK: - Siri comparison axes (README.md table)

    public static let comparisonAxes: [String] = [
        "cross_document_synthesis",
        "airplane_mode_hard_questions",
        "conversation_storage",
        "profile_inspectable",
        "citations",
        "model"
    ]

    // MARK: - BS-M acceptance IDs

    public static let beatsSiriMilestones: [String] = (0...12).map { "BS-M\($0)" }
    public static let acceptanceTestMilestones: [String] = (0...12).map { "AT-M\($0)" }
}

import CoreGraphics
