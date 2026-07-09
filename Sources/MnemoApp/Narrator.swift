// Agent-B audit B-012
// Agent-B audit B-030
import AVFoundation
import Foundation

/// Reads the answer aloud with on-device speech synthesis (#7). `AVSpeechSynthesizer`
/// runs entirely locally — no network, honoring the invariant.
@MainActor
final class Narrator: ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    private let delegate = NarratorDelegate()

    init() {
        synth.delegate = delegate
        delegate.setHandler { [weak self] speaking in
            Task { @MainActor in self?.isSpeaking = speaking }
        }
    }

    /// Toggle: speak the given text, or stop if already speaking.
    func toggle(_ text: String) {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: stripMarkup(text))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = true
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    /// Strip citation markup and markdown emphasis so speech reads cleanly.
    private func stripMarkup(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
        // Drop bracketed/【】 citations.
        for pattern in ["\\[[^\\]]*\\]", "【[^】]*】"] {
            out = out.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class NarratorDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private var onChange: (@Sendable (Bool) -> Void)?
    func setHandler(_ h: @escaping @Sendable (Bool) -> Void) { onChange = h }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { onChange?(true) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { onChange?(false) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { onChange?(false) }
}
