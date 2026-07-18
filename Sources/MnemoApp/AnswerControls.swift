import AppKit
import MnemoOrchestrator
import SwiftUI

/// Compact source cards shared by searching and answer states. Rendering this
/// row during search preserves the source-before-first-token contract.
struct SourceChipRow: View {
    let sources: [SourceCard]
    @Environment(\.colorSchemeContrast) private var contrast

    private var highContrast: Bool { contrast == .increased }

    var body: some View {
        if !sources.isEmpty {
            let cards = Array(sources.prefix(SurfaceUX.CitationAffordance.maxVisibleSources))
            let textWidth = NotchInteraction.sourceChipTextWidth(
                surfaceWidth: Surface.readWidth,
                contentPadding: 20,
                chipPadding: 10,
                spacing: 6,
                chipCount: cards.count
            )
            HStack(spacing: 6) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    Button { reveal(card.path) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(highContrast ? 1 : 0.85))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: textWidth, alignment: .leading)
                            relevanceBar(card.relevance, width: textWidth)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(
                            SurfaceUX.GlassHierarchy.chipFill(highContrast: highContrast))))
                        .overlay(Capsule().stroke(
                            .white.opacity(highContrast ? 0.3 : 0.12), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(helpText(card))
                    .accessibilityLabel(accessibilityLabel(card, index: index))
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func relevanceBar(_ relevance: Double, width: CGFloat) -> some View {
        let fraction = CGFloat(min(1, max(0, relevance)))
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(highContrast ? 0.22 : 0.12))
                .frame(width: width, height: 2)
            Capsule()
                .fill(.white.opacity(highContrast ? 0.85 : 0.55))
                .frame(width: max(2, width * fraction), height: 2)
        }
    }

    private func helpText(_ card: SourceCard) -> String {
        guard let time = RelativeTime.format(iso: card.updatedAt) else { return card.path }
        return "\(card.path) · updated \(time)"
    }

    private func accessibilityLabel(_ card: SourceCard, index: Int) -> String {
        var label = SurfaceUX.CitationAffordance.citationLabel(index: index, title: card.title)
        label += ", relevance \(Int((card.relevance * 100).rounded())) percent"
        if let time = RelativeTime.format(iso: card.updatedAt) { label += ", updated \(time)" }
        return label
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting(
            [URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }
}

/// Familiar icon actions keep the answer surface quiet while exposing the
/// already-local narration, copy, and memory-strength feedback capabilities.
struct AnswerActionRow: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var narrator: Narrator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var copied = false

    private var highContrast: Bool { contrast == .increased }

    var body: some View {
        HStack(spacing: 7) {
            iconButton(
                symbol: narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                label: narrator.isSpeaking ? "Stop reading" : "Read answer aloud",
                selected: narrator.isSpeaking
            ) { narrator.toggle(vm.state.answer) }
            iconButton(
                symbol: copied ? "checkmark" : "doc.on.doc",
                label: copied ? "Copied" : "Copy answer",
                selected: copied
            ) { copyAnswer() }

            Spacer(minLength: 8)

            iconButton(
                symbol: vm.state.feedback == true ? "hand.thumbsup.fill" : "hand.thumbsup",
                label: "Helpful",
                selected: vm.state.feedback == true
            ) { vm.feedback(positive: true) }
            iconButton(
                symbol: vm.state.feedback == false ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: "Not helpful",
                selected: vm.state.feedback == false
            ) { vm.feedback(positive: false) }
        }
        .animation(Motion.adaptive(Motion.glyph, reduceMotion: reduceMotion),
                   value: narrator.isSpeaking)
        .animation(Motion.adaptive(Motion.glyph, reduceMotion: reduceMotion), value: copied)
        .animation(Motion.adaptive(Motion.glyph, reduceMotion: reduceMotion),
                   value: vm.state.feedback)
    }

    private func iconButton(
        symbol: String,
        label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(selected || highContrast ? 1 : 0.72))
                .frame(width: 29, height: 29)
                .background(Circle().fill(.white.opacity(selected ? 0.2 : 0.07)))
                .overlay(Circle().stroke(
                    .white.opacity(highContrast ? 0.35 : 0.13), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func copyAnswer() {
        vm.copyAnswer()
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            copied = false
        }
    }
}

/// Generated follow-ups become real one-click continuations instead of dead
/// reducer state. A fixed two-column grid keeps long labels inside the surface.
struct FollowUpGrid: View {
    @ObservedObject var vm: NotchViewModel
    @Environment(\.colorSchemeContrast) private var contrast

    private var highContrast: Bool { contrast == .increased }
    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    var body: some View {
        let suggestions = SurfaceUX.Suggestions.filtered(vm.state.suggestions)
        if !suggestions.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                    Button { vm.submitSuggestion(suggestion) } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            Text(suggestion)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.white.opacity(highContrast ? 1 : 0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(
                            SurfaceUX.GlassHierarchy.chipFill(highContrast: highContrast))))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            .white.opacity(highContrast ? 0.3 : 0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(suggestion)
                    .accessibilityLabel("Follow up: \(suggestion)")
                }
            }
        }
    }
}
