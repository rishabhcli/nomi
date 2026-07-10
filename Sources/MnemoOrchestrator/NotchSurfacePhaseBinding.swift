import Foundation

/// Maps view-local UI chrome to `NotchReducer` phases so orphan state cannot
/// desync from backend `QueryEvent`s. Pure logic — hermetically testable.
public enum NotchSurfacePhaseBinding {
    /// View-local keys owned by `NotchSurfaceView` and their valid phases.
    public enum LocalKey: String, CaseIterable, Sendable {
        /// Measured answer-zone height — only meaningful while showing an answer.
        case answerHeight
        /// Text-field first-responder — tray/input phases only.
        case inputFocus
    }

    /// `answerHeight` must reset when leaving answer/terminal phases or entering dictation.
    public static func shouldRetainAnswerHeight(phase: NotchPhase, listening: Bool) -> Bool {
        !listening && (phase == .answering || phase == .state)
    }

    /// Input focus is armed on summon and while typing or reading an answer.
    public static func shouldFocusInput(phase: NotchPhase) -> Bool {
        phase == .input || phase == .answering || phase == .state
    }

    /// The glass tray is visible in every expanded phase except the listening drop.
    public static func showsTray(phase: NotchPhase, listening: Bool) -> Bool {
        phase != .idle && !listening
    }

    /// Pull-handle appears only when conversation content overflows the cap.
    public static func showsHandle(phase: NotchPhase, answerHeight: CGFloat, cap: CGFloat) -> Bool {
        (phase == .answering || phase == .state) && answerHeight > cap
    }

    /// Privacy dot is shown whenever the surface is expanded.
    public static func showsPrivacyDot(phase: NotchPhase) -> Bool {
        phase != .idle
    }

    /// Phases where `Dictation.transcript` may write into `NotchState.query`.
    public static func acceptsDictationTranscript(phase: NotchPhase, listening: Bool) -> Bool {
        listening || phase == .input
    }
}
