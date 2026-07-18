import CryptoKit
import Foundation
import CoreGraphics

/// Pure, hermetically testable UX invariants for the notch surface (Phase 2
/// Agent E). Every dimension maps to a prompt seed and has XCTest coverage in
/// `SurfaceTests.swift`.
public enum SurfaceUX {

    // MARK: - Perceived latency (E-0001, E-0017, …)

    public enum PerceivedLatency {
        /// Summon spring is snappier than grow — feels instant (seed `d4276e79207e`).
        public static let summonResponse: Double = 0.28
        public static let summonDamping: Double = 0.86
        /// Long-press dictation threshold — short enough to feel responsive.
        public static let dictationHoldSeconds: Double = 0.30
        /// Privacy dot fades in on the first expanded frame, not after spring settles.
        public static func privacyDotVisibleImmediately(phase: NotchPhase) -> Bool {
            phase != .idle
        }
        /// Input width is used on summon so the surface never sideways-jumps later.
        public static func predictiveExpandedWidth(phase: NotchPhase, listening: Bool) -> CGFloat {
            if listening { return 176 }
            switch phase {
            case .idle: return 0
            case .input, .searching: return 520
            case .answering, .state: return 520
            }
        }
        /// Summon animation must be faster than phase morph (lower response = snappier).
        public static func summonFasterThanGrow(summonResponse: Double, growResponse: Double) -> Bool {
            summonResponse < growResponse
        }
    }

    // MARK: - Reading-grade typography (E-0002, …)

    public enum Typography {
        public static let answerPointSize: CGFloat = 17
        public static let answerLineSpacing: CGFloat = 5
        public static let bodyLeading: CGFloat = 1.35
        public static let chipPointSize: CGFloat = 12
        public static let statusPointSize: CGFloat = 13
        public static let minimumContrastRatio: Double = 4.5
        /// WCAG AA: white on black at 0.72 opacity still exceeds 4.5:1.
        public static let secondaryTextOpacity: Double = 0.72
        public static let primaryTextOpacity: Double = 1.0

        public static func lineHeight(for pointSize: CGFloat) -> CGFloat {
            pointSize * bodyLeading
        }

        /// Reading comfort: cap line length at ~65 characters worth of width.
        public static let comfortableReadWidth: CGFloat = 520
    }

    // MARK: - Citation affordance (E-0003, …)

    public enum CitationAffordance {
        public static let maxVisibleSources = 3
        public static let chipMinTapWidth: CGFloat = 44

        /// Numbered citation prefix for VoiceOver rotor order.
        public static func citationLabel(index: Int, title: String) -> String {
            "Source \(index + 1), \(title)"
        }

        /// Reasoning steps that mention a source get a citation marker.
        public static func stepShowsCitationMarker(_ step: String) -> Bool {
            step.contains("[") || step.localizedCaseInsensitiveContains("source")
                || step.localizedCaseInsensitiveContains("reading")
        }

        public static func sourceChipAccessibility(title: String, path: String, index: Int) -> String {
            "\(citationLabel(index: index, title: title)). Path \(path)"
        }
    }

    // MARK: - Error recovery clarity (E-0004, …)

    public enum ErrorRecovery {
        /// Primary recovery actions surface first (glassProminent).
        public static func recoveryIsPrimary(_ recovery: TerminalState.Recovery) -> Bool {
            switch recovery {
            case .restartEngine, .loadModel, .addFiles: return true
            case .broaden, .waitAndRetry: return false
            }
        }

        public static func recoveryButtonTitle(_ recovery: TerminalState.Recovery) -> String {
            switch recovery {
            case .broaden: return "Broaden search"
            case .restartEngine: return "Restart engine"
            case .loadModel: return "Load model"
            case .waitAndRetry: return "Try again"
            case .addFiles: return "Open memory folder"
            }
        }

        /// Status line during recovery must be non-empty so the user sees progress.
        public static func recoveryStatusMessage(_ recovery: TerminalState.Recovery) -> String {
            switch recovery {
            case .restartEngine: return "Restarting the engine…"
            case .loadModel: return "Loading the model…"
            case .broaden: return "Searching more broadly…"
            case .waitAndRetry: return "Trying again…"
            case .addFiles: return "Opening memory folder…"
            }
        }
    }

    // MARK: - VoiceOver rotor order (E-0005, …)

    public enum VoiceOverOrder: Int, CaseIterable, Sendable {
        case queryField = 0
        case reasoningTrace = 1
        case answer = 2
        case sources = 3
        case recovery = 4
        case privacy = 5

        /// SwiftUI reads larger sort priorities before smaller ones. Keep the
        /// enum in the human reading order and invert it at the API boundary.
        public var sortPriority: Int { Self.allCases.count - rawValue }
    }

    public static func voiceOverSortPriority(for element: VoiceOverOrder) -> Int {
        element.sortPriority
    }

    // MARK: - Keyboard-only summon (E-0006, …)

    public enum Keyboard {
        public static let summonShortcut = "⌃⌥M"
        public static let submitShortcut = "⌘⏎"
        public static let newConversationShortcut = "⌘K"
        public static let copyAnswerShortcut = "⇧⌘C"

        public static func focusInputOnSummon(phase: NotchPhase) -> Bool {
            phase == .input
        }
    }

    // MARK: - Press-hold dictation discoverability (E-0007, …)

    public enum DictationDiscoverability {
        public static let holdDurationSeconds: Double = PerceivedLatency.dictationHoldSeconds
        public static let accessibilityHint = "Hold to dictate, or tap the microphone button"

        public static func holdGestureRecognized(duration: Double) -> Bool {
            duration >= holdDurationSeconds
        }
    }

    // MARK: - Reasoning trace legibility (E-0008, …)

    public enum ReasoningTrace {
        public static let stepPointSize: CGFloat = 13
        public static let headerPointSize: CGFloat = 12
        public static let maxVisibleSteps = 12
        public static let collapsedByDefaultOnAnswer = true

        /// Visible whenever there are steps and a query is active or answered:
        /// the trace runs live during search, then PERSISTS (collapsed) above the
        /// streamed answer and terminal states — the progressive live-trace pattern.
        public static func shouldShow(phase: NotchPhase, itemCount: Int) -> Bool {
            guard itemCount > 0 else { return false }
            switch phase {
            case .searching, .answering, .state: return true
            case .idle, .input: return false
            }
        }

        /// Expanded while still working; collapsed once an answer is present.
        public static func startsExpanded(hasAnswer: Bool) -> Bool { !hasAnswer }

        public static func stepOpacity(index: Int, total: Int, reduceMotion: Bool) -> Double {
            guard !reduceMotion else { return 1.0 }
            let base = 0.45
            let step = 0.12
            return min(1.0, base + Double(index + 1) * step)
        }

        public static func truncatedSteps(_ steps: [String]) -> [String] {
            guard steps.count > maxVisibleSteps else { return steps }
            return Array(steps.prefix(maxVisibleSteps - 1)) + [steps[steps.count - 1]]
        }
    }

    // MARK: - Glass material hierarchy (E-0009, …)

    public enum GlassHierarchy {
        public static let trayTintOpacity: Double = 0.74
        public static let pillFillOpacity: Double = 0.10
        public static let chipFillOpacity: Double = 0.12

        /// Increase Contrast: raise opacities so glass reads clearly.
        public static func trayTint(highContrast: Bool) -> Double {
            highContrast ? 0.88 : trayTintOpacity
        }

        public static func pillFill(highContrast: Bool) -> Double {
            highContrast ? 0.22 : pillFillOpacity
        }

        public static func chipFill(highContrast: Bool) -> Double {
            highContrast ? 0.24 : chipFillOpacity
        }

        public static func reasoningBackground(highContrast: Bool) -> Double {
            highContrast ? 0.14 : 0.06
        }
    }

    // MARK: - Spring overshoot elimination (E-0010, …)

    public enum SpringOvershoot {
        public static let maxAllowedOvershoot: Double = 0.02
        public static let collapseDamping: Double = 0.90
        public static let growDamping: Double = 0.88

        public static func dampingPreventsOvershoot(damping: Double) -> Bool {
            damping >= 0.85
        }
    }

    // MARK: - 120fps orb thermal stability (E-0011, …)

    public enum OrbPerformance {
        public static let targetFPS: Double = 120
        public static let frameBudgetMs: Double = 1000.0 / 120.0
        public static let maxUniformUpdatesPerFrame = 1

        public static func withinFrameBudget(elapsedMs: Double) -> Bool {
            elapsedMs <= frameBudgetMs * 1.5
        }
    }

    // MARK: - Empty corpus onboarding (E-0012, …)

    public enum EmptyCorpus {
        public static let onboardingTitle = "No files yet"
        public static let onboardingMessage = "Drop documents into your memory folder to get started."

        public static func showsOnboarding(terminal: TerminalState?) -> Bool {
            if case .emptyCorpus = terminal { return true }
            return false
        }
    }

    // MARK: - In-flight query lock UX (E-0013, …)

    public enum QueryLock {
        public static func blocksResummon(isQuerying: Bool, phase: NotchPhase) -> Bool {
            isQuerying || phase == .searching
        }

        public static func blocksDismissOnMouseOut(isQuerying: Bool, phase: NotchPhase) -> Bool {
            isQuerying || phase == .searching
        }

        public static func blocksRepeatSubmit(phase: NotchPhase) -> Bool {
            phase == .searching
        }
    }

    // MARK: - Unsupported sentence styling (E-0014, …)

    public enum UnsupportedStyling {
        public static let warningOpacity: Double = 0.9
        public static let usesUnderline = true

        public static func isUnsupported(sentenceIndex: Int, unsupported: Set<Int>) -> Bool {
            unsupported.contains(sentenceIndex)
        }
    }

    // MARK: - Suggestion chip relevance (E-0015, …)

    public enum Suggestions {
        public static let maxChips = 4
        public static let minChipLength = 3

        public static func filtered(_ suggestions: [String]) -> [String] {
            suggestions
                .filter { $0.trimmingCharacters(in: .whitespaces).count >= minChipLength }
                .prefix(maxChips)
                .map { $0 }
        }
    }

    // MARK: - Entity chip exploration (E-0016, …)

    public enum EntityChips {
        public static let maxVisible = 5
        public static let minTapHeight: CGFloat = 28

        public static func truncated(_ entities: [String]) -> [String] {
            Array(entities.prefix(maxVisible))
        }

        public static func explorationLabel(_ name: String) -> String {
            "Explore \(name)"
        }
    }

    // MARK: - Multi-display handoff (E-0018, …)

    public enum MultiDisplay {
        /// Panel midX must track notch midX within one point.
        public static let maxMidXDelta: CGFloat = 1.0
        public static let maxTopFlushDelta: CGFloat = 1.0

        public static func isAligned(panelMidX: CGFloat, notchMidX: CGFloat,
                                   topDelta: CGFloat) -> Bool {
            abs(panelMidX - notchMidX) < maxMidXDelta && abs(topDelta) < maxTopFlushDelta
        }
    }

    // MARK: - Reduce Motion morph (E-0019, …)

    public enum ReduceMotion {
        public static let crossFadeDuration: Double = 0.20

        public static func usesOpacityOnly(reduceMotion: Bool) -> Bool {
            reduceMotion
        }
    }

    // MARK: - Increase Contrast glass (E-0020, …)

    public enum IncreaseContrast {
        public static let borderStrokeOpacity: Double = 0.35

        public static func glassUsesStrongerTint(highContrast: Bool) -> Bool {
            highContrast
        }

        public static func textOpacity(primary: Bool, highContrast: Bool) -> Double {
            if highContrast { return primary ? 1.0 : 0.92 }
            return primary ? Typography.primaryTextOpacity : Typography.secondaryTextOpacity
        }
    }

    // MARK: - Prompt registry (maps E-NNNN → seed for tests)

    public static func seed(forPrompt n: Int) -> String {
        let digest = SHA256.hash(data: Data("phase2-E-\(n)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(12).description
    }
}

/// Surfaces cycled by Phase 2 prompts (index = (n-1) % count).
public enum SurfaceTarget: String, CaseIterable, Sendable {
    case notchSurfaceView, surfaceBlocks, reasoningTraceView, notchViewModel
    case notchController, notchPanel, hoverDetector, dictation
    case voiceOrbView, voiceOrbMetal, motion, narrator
    case appCommandHandler, inputTray, terminalRecoveryCTAs, sourceCardChips
    case privacyEgressDot, multiDisplayHandoff, reduceMotionMorph, increaseContrastGlass

    public static func forPrompt(_ n: Int) -> SurfaceTarget {
        allCases[(n - 1) % allCases.count]
    }
}

/// UX dimensions cycled by Phase 2 prompts (index = (n-1) % count).
public enum UXDimension: String, CaseIterable, Sendable {
    case perceivedLatency, readingGradeTypography, citationAffordance, errorRecoveryClarity
    case voiceOverRotorOrder, keyboardOnlySummon, pressHoldDictation, reasoningTraceLegibility
    case glassMaterialHierarchy, springOvershootElimination, orb120fpsThermal, emptyCorpusOnboarding
    case inFlightQueryLock, unsupportedSentenceStyling, suggestionChipRelevance, entityChipExploration

    public static func forPrompt(_ n: Int) -> UXDimension {
        allCases[(n - 1) % allCases.count]
    }
}
