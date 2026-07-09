import SwiftUI
import MnemoOrchestrator

/// Content for the notch surface (reference: Tests/Fixtures/reference): the
/// Liquid-Glass tray and the answer zone. Nothing else renders in the notch —
/// the richer data (reasoning, related, suggestions) stays in state for mnemoctl.

// MARK: - Bottom glass tray (+ / pill field / mic-or-send / home indicator)

struct InputTray: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @FocusState.Binding var focused: Bool
    let searching: Bool
    let reduceMotion: Bool
    let showHandle: Bool
    var glassNamespace: Namespace.ID

    private var hasText: Bool { !vm.state.query.isEmpty }

    var body: some View {
        GlassEffectContainer {
            ZStack(alignment: .top) {
                // The tray is the ONLY glassy part of the surface: dark, translucent
                // Liquid Glass — the desktop shows through it. The outer NotchShape
                // rounds its bottom corners. (Glass cannot sample glass: nothing
                // else on the surface uses glassEffect.)
                Rectangle().fill(.clear)
                    .glassEffect(.regular.tint(.black.opacity(Surface.trayTint)), in: Rectangle())
                    .glassEffectID("input-tray", in: glassNamespace)
                VStack(spacing: 0) {
                    // The black body melts INTO the glass here — a black→clear
                    // gradient OVER the glass, so there is never a desktop-showing
                    // gap between the body and the controls.
                    LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: Surface.bandFade)
                        .allowsHitTesting(false)
                    HStack(spacing: 10) {
                        pill
                        // The send/mic control is hidden while working, so a second
                        // query can't be fired mid-flight — the tray collapses to
                        // just the spinner.
                        if !searching { micOrSend }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: Surface.bandHeight)
                    if showHandle { HomeIndicator().frame(height: Surface.trayHandle) }
                }
            }
        }
    }

    /// Dark translucent pill: white text, light placeholder. While searching it
    /// shows ONLY the spinner — no step/status text (kept out of the notch).
    private var pill: some View {
        ZStack {
            Capsule().fill(.white.opacity(0.10))
            if searching {
                SixDotSpinner()
                    .frame(width: Surface.spinnerRing + 6, height: Surface.spinnerRing + 6)
            } else {
                TextField("Ask Mnemo", text: $vm.state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($focused)
                    .onSubmit { Task { await vm.submit() } }
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
                dictation.stop(); Task { await vm.submit() }
            } else if hasText {
                Task { await vm.submit() }
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
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReasoningTraceView(steps: vm.state.reasoning,
                               status: vm.state.status,
                               understanding: vm.state.understanding,
                               phase: vm.state.phase,
                               reduceMotion: reduceMotion)
            if !vm.state.suggestions.isEmpty && vm.state.phase == .answering {
                SuggestionChips(suggestions: vm.state.suggestions, reduceMotion: reduceMotion)
            }
            if !vm.state.entities.isEmpty && vm.state.phase == .answering {
                EntityChips(entities: vm.state.entities)
            }
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
            HStack(spacing: 6) {
                ForEach(vm.state.sources.prefix(3), id: \.docId) { card in
                    Button { reveal(card.path) } label: {
                        Text(card.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help(card.path)
                }
            }
        }
    }

    /// Terminal states: icon, title, message, recovery CTA (B-041…B-080).
    @ViewBuilder private func terminalView(_ t: TerminalState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: TerminalPresentation.icon(for: t))
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(TerminalPresentation.title(for: t))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(NotchReducer.message(for: t))
                    .font(.system(size: Surface.answerFont))
                    .lineSpacing(5)
                    .foregroundStyle(.white)
                if case .empty(let nearest) = t, !nearest.isEmpty {
                    NearestMatchesRow(cards: nearest)
                }
                recoveryButtons(for: t)
            }
        }
    }

    @ViewBuilder private func recoveryButtons(for t: TerminalState) -> some View {
        switch t.recovery {
        case .broaden:
            Button("Broaden search") { Task { await vm.recover(.broaden) } }.buttonStyle(.glass)
        case .restartEngine:
            Button("Restart engine") { Task { await vm.recover(.restartEngine) } }.buttonStyle(.glassProminent)
        case .loadModel:
            Button("Load model") { Task { await vm.recover(.loadModel) } }.buttonStyle(.glassProminent)
        case .waitAndRetry:
            Button("Try again") { Task { await vm.recover(.waitAndRetry) } }.buttonStyle(.glass)
        case .addFiles:
            Button("Open memory folder") { Task { await vm.recover(.addFiles) } }.buttonStyle(.glassProminent)
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

// MARK: - Supporting chips & rows

struct SuggestionChips: View {
    let suggestions: [String]
    let reduceMotion: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestions.prefix(4), id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
            }
        }
        .accessibilityLabel("Suggested follow-ups")
    }
}

struct EntityChips: View {
    let entities: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(entities.prefix(5), id: \.self) { name in
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().stroke(.white.opacity(0.2)))
            }
        }
        .accessibilityLabel("Entities mentioned")
    }
}

struct NearestMatchesRow: View {
    let cards: [SourceCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearest matches")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 6) {
                ForEach(cards.prefix(3), id: \.docId) { card in
                    Text(card.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
            }
        }
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
