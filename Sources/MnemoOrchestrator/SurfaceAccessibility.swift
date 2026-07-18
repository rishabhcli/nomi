/// Stable accessibility output for the notch lifecycle. The announcement kind
/// deliberately excludes streamed text and live status so VoiceOver hears each
/// query milestone once instead of once per token.
public enum SurfaceAccessibility {
    public struct Announcement: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case queryStarted
            case correctionStarted
            case answerReady
            case terminal(String)
        }

        public let kind: Kind
        public let text: String

        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    public static func announcement(for state: NotchState) -> Announcement? {
        if let terminal = state.terminal {
            let text = NotchReducer.message(for: terminal)
            return Announcement(kind: .terminal(text), text: text)
        }
        if state.phase == .searching {
            return Announcement(kind: .queryStarted, text: "Searching your memory")
        }
        if state.phase == .answering, !state.answer.isEmpty {
            return Announcement(kind: .answerReady, text: "Answer ready")
        }
        return nil
    }

    public static func privacyValue(for indicator: PrivacyIndicator) -> String {
        switch indicator {
        case .clean:
            return "On-device, 0 observed outbound connections"
        case .egressDetected(let rawCount):
            let count = max(0, rawCount)
            let noun = count == 1 ? "attempt" : "attempts"
            return "Warning, \(count) outbound connection \(noun) observed"
        }
    }
}

/// Deduplicates a contiguous lifecycle state while re-arming after a quiet
/// state, so a later query can announce the same milestone again.
public struct SurfaceAnnouncementTracker: Sendable {
    private var previousPhase: NotchPhase?
    private var announcedQueryStart = false
    private var announcedAnswer = false
    private var announcedCorrection = false
    private var announcedTerminal: String?

    public init() {}

    public mutating func next(for state: NotchState) -> SurfaceAccessibility.Announcement? {
        defer { previousPhase = state.phase }

        if state.phase == .idle || state.phase == .input {
            resetCycle()
            return nil
        }

        // `runQuery` clears both answer and sources before entering searching.
        // A grounding correction also returns to searching, but keeps sources;
        // that distinction prevents a retry from masquerading as a new query.
        if state.phase == .searching, state.answer.isEmpty, state.sources.isEmpty,
           previousPhase != .searching {
            resetCycle()
        }

        if let terminal = state.terminal {
            let text = NotchReducer.message(for: terminal)
            guard announcedTerminal != text else { return nil }
            announcedTerminal = text
            return .init(kind: .terminal(text), text: text)
        }

        if state.phase == .searching {
            if !announcedQueryStart {
                announcedQueryStart = true
                return .init(kind: .queryStarted, text: "Searching your memory")
            }
            if announcedAnswer, !announcedCorrection {
                announcedCorrection = true
                announcedAnswer = false
                return .init(
                    kind: .correctionStarted,
                    text: "Rechecking the answer against your files"
                )
            }
            return nil
        }

        if state.phase == .answering, !state.answer.isEmpty, !announcedAnswer {
            announcedAnswer = true
            return .init(kind: .answerReady, text: "Answer ready")
        }
        return nil
    }

    private mutating func resetCycle() {
        announcedQueryStart = false
        announcedAnswer = false
        announcedCorrection = false
        announcedTerminal = nil
    }
}
