import SwiftUI
import MnemoOrchestrator

/// Beautifully surfaces live `QueryEvent` reasoning/retrieval progress in the
/// answer zone (prompts B-241…B-280). Collapsible glass timeline; auto-hides
/// when tokens stream or query completes.
struct ReasoningTraceView: View {
    let steps: [String]
    let status: String
    let understanding: String
    let phase: NotchPhase
    let reduceMotion: Bool
    @State private var expanded = true
    @Environment(\.colorSchemeContrast) private var colorContrast

    private var highContrast: Bool { colorContrast == .increased }

    private var items: [String] {
        var out: [String] = []
        if !understanding.isEmpty { out.append(understanding) }
        if !status.isEmpty, status != understanding { out.append(status) }
        out.append(contentsOf: SurfaceUX.ReasoningTrace.truncatedSteps(steps))
        return out
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(Motion.adaptive(Motion.dissolve, reduceMotion: reduceMotion)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Working")
                            .font(.system(size: SurfaceUX.ReasoningTrace.headerPointSize, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(SurfaceUX.IncreaseContrast.textOpacity(primary: false, highContrast: highContrast)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse reasoning trace" : "Expand reasoning trace")
                .accessibilitySortPriority(Double(SurfaceUX.voiceOverSortPriority(for: .reasoningTrace)))

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(.white.opacity(highContrast ? 0.55 : 0.35))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    if SurfaceUX.CitationAffordance.stepShowsCitationMarker(step) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.45))
                                            .accessibilityHidden(true)
                                    }
                                    Text(step)
                                        .font(.system(size: SurfaceUX.ReasoningTrace.stepPointSize))
                                        .foregroundStyle(.white.opacity(SurfaceUX.IncreaseContrast.textOpacity(primary: false, highContrast: highContrast)))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .opacity(SurfaceUX.ReasoningTrace.stepOpacity(index: i, total: items.count,
                                                                          reduceMotion: reduceMotion))
                            .animation(Motion.adaptive(Motion.reveal, reduceMotion: reduceMotion)
                                .delay(Double(i) * Motion.stagger), value: items.count)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(SurfaceUX.GlassHierarchy.reasoningBackground(highContrast: highContrast)))
                            .overlay {
                                if highContrast {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(SurfaceUX.IncreaseContrast.borderStrokeOpacity), lineWidth: 1)
                                }
                            }
                    }
                }
            }
            .transition(Motion.adaptiveTransition(reduceMotion: reduceMotion))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Reasoning trace")
        }
    }

    private var shouldShow: Bool {
        SurfaceUX.ReasoningTrace.shouldShow(phase: phase, itemCount: items.count, hasAnswer: false)
    }
}

extension Motion {
    static func adaptiveTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top))
    }
}

/// Icon + copy for each terminal state (B-041…B-080).
enum TerminalPresentation {
    static func icon(for terminal: TerminalState) -> String {
        switch terminal {
        case .indexing: return "doc.badge.clock"
        case .empty: return "magnifyingglass"
        case .emptyCorpus: return "folder.badge.plus"
        case .modelNotLoaded: return "cpu"
        case .engineUnreachable: return "bolt.horizontal.circle"
        case .unsupportedAnswer: return "exclamationmark.shield"
        }
    }

    static func title(for terminal: TerminalState) -> String {
        switch terminal {
        case .indexing: return "Still indexing"
        case .empty: return "No close match"
        case .emptyCorpus: return SurfaceUX.EmptyCorpus.onboardingTitle
        case .modelNotLoaded: return "Model not loaded"
        case .engineUnreachable: return "Engine unreachable"
        case .unsupportedAnswer: return "Couldn't ground an answer"
        }
    }
}
