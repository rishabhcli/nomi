import SwiftUI
import MnemoOrchestrator

/// Content for the notch surface (reference: Tests/Fixtures/reference): the
/// Liquid-Glass tray, live reasoning trace, and answer zone.

// MARK: - Bottom glass tray (+ / pill field / mic-or-send / home indicator)

struct InputTray: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @FocusState.Binding var focused: Bool
    let searching: Bool
    let reduceMotion: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    private var hasText: Bool { !vm.state.query.isEmpty }
    private var highContrast: Bool { contrast == .increased }

    // Controls only — the Liquid Glass and the black→glass melt are now the
    // surface's material (NotchSurfaceView.material); the controls sit at the
    // bottom over the fully-melted glass. The Spacer keeps them pinned to the
    // bottom of the reserved tray zone (the glass fade rises behind it).
    var body: some View {
        VStack(spacing: 0) {
            if let activity = vm.volumeActivityText, !searching {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill")
                    Text(activity).lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(height: Surface.bandFade)
                .padding(.horizontal, 18)
                .accessibilityElement(children: .combine)
            } else {
                Spacer(minLength: 0)
                    .frame(height: Surface.bandFade)
            }
            HStack(spacing: 10) {
                pill
                // The send/mic control is hidden while working, so a second
                // query can't be fired mid-flight — the tray collapses to
                // just the spinner.
                if searching { cancelSearch } else { micOrSend }
            }
            .padding(.horizontal, 13)
            .frame(height: Surface.bandHeight)
            HomeIndicator().frame(height: Surface.trayHandle)
        }
    }

    /// Dark translucent pill: white text, light placeholder. While searching it
    /// shows ONLY the spinner — no step/status text (kept out of the notch).
    private var pill: some View {
        ZStack {
            Capsule().fill(.white.opacity(SurfaceUX.GlassHierarchy.pillFill(highContrast: highContrast)))
            if searching {
                SixDotSpinner()
                    .frame(width: Surface.spinnerRing + 6, height: Surface.spinnerRing + 6)
            } else {
                TextField(vm.inputPlaceholder, text: $vm.state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($focused)
                    .onSubmit { vm.beginSubmit() }
                    .onKeyPress(.upArrow) { vm.recallPrevious(); return .handled }
                    .onKeyPress(.downArrow) { vm.recallNext(); return .handled }
                    // transcript→query bridge lives on the always-mounted surface
                    // (NotchSurfaceView) — it must survive the tray unmounting
                    // while the listening drop is up.
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { focused = true }
            }
        }
        .frame(height: 40)
    }

    /// Mic when empty; morphs to a white filled circle with a black ↑ when text
    /// is present — the reference's send morph. Tapping the mic collapses the
    /// surface into the listening drop (one voice UI everywhere).
    private var micOrSend: some View {
        Button {
            if dictation.isListening {
                dictation.stop(); vm.beginSubmit()
            } else if hasText {
                vm.beginSubmit()
            } else {
                dictation.start()
            }
        } label: {
            ZStack {
                Circle().fill(hasText ? Color.white : Color.white.opacity(0.13))
                Image(systemName: hasText ? "arrow.up" : "mic.fill")
                    .font(.system(size: 15, weight: hasText ? .bold : .regular))
                    .foregroundStyle(hasText ? Color.black : Color.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .animation(Motion.adaptive(Motion.glyph, reduceMotion: reduceMotion), value: hasText)
        .help(hasText ? "Send (⌘⏎)" : "Dictate")
        .accessibilityLabel(hasText ? "Send" : "Dictate")
    }

    private var cancelSearch: some View {
        Button { vm.cancelQuery() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.13)))
        }
        .buttonStyle(.plain)
        .help("Cancel")
        .accessibilityLabel("Cancel search")
    }
}

/// The little grab-handle pill at the tray bottom (reference detail).
struct HomeIndicator: View {
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.32))
            .frame(width: Surface.homeIndicatorW, height: Surface.homeIndicatorH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Answer zone (white text · one quiet chip row)

struct AnswerZone: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var highContrast: Bool { contrast == .increased }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Progressive live-trace: the "Working" reasoning timeline persists
            // (collapsed) above the answer — what was searched/ranked/verified.
            ReasoningTraceView(steps: vm.state.reasoning, status: vm.state.status,
                               understanding: vm.state.understanding, phase: vm.state.phase,
                               hasAnswer: !vm.state.answer.isEmpty, reduceMotion: reduceMotion)
            // A dictation problem belongs to the input/dictation moment only —
            // never stacked above an answer or terminal state, where it would
            // read as a stale banner leaking into an unrelated result.
            if let problem = dictation.problem, vm.state.answer.isEmpty, vm.state.terminal == nil {
                Text(problem)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let terminal = vm.state.terminal {
                terminalView(terminal)
            } else if !vm.state.answer.isEmpty {
                answerText
                sourceChips
            }
            if !vm.state.answer.isEmpty || vm.state.terminal != nil {
                trustFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Large clean white text, top-left. Unsupported sentences (M5) stay
    /// visually distinct.
    private var answerText: some View {
        let sentences = Sentences.split(vm.state.answer)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(sentences.enumerated()), id: \.offset) { i, s in
                Text(markdown(s))
                    .font(.system(size: Surface.answerFont))
                    .lineSpacing(5)
                    .foregroundStyle(vm.state.unsupportedSentences.contains(i)
                                     ? AnyShapeStyle(.orange.opacity(0.9))
                                     : AnyShapeStyle(.white))
                    .underline(vm.state.unsupportedSentences.contains(i))
                    .textSelection(.enabled)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Quiet gray chips — the reference's "Riddleness" chip, one per source.
    @ViewBuilder private var sourceChips: some View {
        if !vm.state.sources.isEmpty {
            let chipCount = min(3, vm.state.sources.count)
            let chipTextWidth = NotchInteraction.sourceChipTextWidth(
                surfaceWidth: Surface.readWidth,
                contentPadding: 20,
                chipPadding: 10,
                spacing: 6,
                chipCount: chipCount
            )
            HStack(spacing: 6) {
                ForEach(vm.state.sources.prefix(3), id: \.docId) { card in
                    Button { reveal(card.path) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(highContrast ? 1.0 : 0.85))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: chipTextWidth, alignment: .leading)
                            relevanceBar(card.relevance, width: chipTextWidth)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(
                            SurfaceUX.GlassHierarchy.chipFill(highContrast: highContrast))))
                        .overlay(Capsule().stroke(.white.opacity(highContrast ? 0.3 : 0.12), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(chipHelp(card))
                    .accessibilityLabel(chipAXLabel(card))
                }
            }
        }
    }

    /// Thin relevance bar (0…1 of `width`) — the mockup's ▓▓▓▓░ cue, kept quiet.
    private func relevanceBar(_ r: Double, width: CGFloat) -> some View {
        let frac = CGFloat(min(1, max(0, r)))
        return ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(highContrast ? 0.22 : 0.12)).frame(width: width, height: 2)
            Capsule().fill(.white.opacity(highContrast ? 0.85 : 0.55)).frame(width: max(2, width * frac), height: 2)
        }
    }

    private func chipHelp(_ card: SourceCard) -> String {
        guard let t = RelativeTime.format(iso: card.updatedAt) else { return card.path }
        return "\(card.path) · updated \(t)"
    }

    private func chipAXLabel(_ card: SourceCard) -> String {
        var s = "Source: \(card.title), relevance \(Int((card.relevance * 100).rounded())) percent"
        if let t = RelativeTime.format(iso: card.updatedAt) { s += ", updated \(t)" }
        return s
    }

    /// Always-on trust footer: "● 0 outbound · 0.4s · Grounded" — the per-query
    /// M1a metrics rendered as a calm, reassuring status line under the answer.
    @ViewBuilder private var trustFooter: some View {
        let f = TrustFooterModel.make(metrics: vm.state.metrics,
                                      confidence: vm.state.overallConfidence,
                                      hasAnswer: !vm.state.answer.isEmpty)
        HStack(spacing: 6) {
            Circle()
                .fill(f.egressClean ? Color.green.opacity(0.9) : Color.orange.opacity(0.95))
                .frame(width: 6, height: 6)
            Text(f.egressText)
            if let t = f.timeText { Text("· \(t)") }
            if let c = f.confidenceLabel { Text("· \(c)") }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(highContrast ? 0.9 : 0.5))
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(f.egressClean ? "No outbound network" : f.egressText)"
            + (f.timeText.map { ", \($0)" } ?? "")
            + (f.confidenceLabel.map { ", \($0)" } ?? ""))
    }

    /// Terminal states stay minimal: the message plus one recovery action.
    @ViewBuilder private func terminalView(_ t: TerminalState) -> some View {
        Text(NotchReducer.message(for: t))
            .font(.system(size: Surface.answerFont))
            .lineSpacing(5)
            .foregroundStyle(.white)
        switch t.recovery {
        case .broaden:
            Button("Broaden search") { vm.beginRecovery(.broaden) }.buttonStyle(.glass)
        case .restartEngine:
            Button("Restart engine") { vm.beginRecovery(.restartEngine) }.buttonStyle(.glassProminent)
        case .loadModel:
            Button("Load model") { vm.beginRecovery(.loadModel) }.buttonStyle(.glassProminent)
        case .waitAndRetry:
            Button("Try again") { vm.beginRecovery(.waitAndRetry) }.buttonStyle(.glass)
        case .addFiles:
            Button("Open memory folder") { vm.beginRecovery(.addFiles) }.buttonStyle(.glassProminent)
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting(
            [URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }
}

// MARK: - 6-dot comet spinner

struct SixDotSpinner: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let ring = Surface.spinnerRing / 2
                for i in 0..<6 {
                    let a = (Double(i) / 6.0) * 2 * .pi + t * 2 * .pi * Surface.spinnerRPS
                    let p = CGPoint(x: c.x + ring * cos(a), y: c.y + ring * sin(a))
                    let opacity = 1.0 - Double(i) * 0.125
                    let d = Surface.spinnerDot
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - d/2, y: p.y - d/2, width: d, height: d)),
                             with: .color(.white.opacity(opacity)))
                }
            }
        }
        .accessibilityLabel("Working")
    }
}
