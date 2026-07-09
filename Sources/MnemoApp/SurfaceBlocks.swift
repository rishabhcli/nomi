import SwiftUI
import MnemoOrchestrator

/// Content for the simplified notch surface (reference: assets/IMG_1149 +
/// IMG_1150): the glass input band and the answer zone. Nothing else renders
/// in the notch — the richer data stays in state for mnemoctl.

// MARK: - Bottom input band (Liquid Glass strip; + / pill field / mic-or-send)

struct InputBand: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @FocusState.Binding var focused: Bool
    let searching: Bool
    let reduceMotion: Bool

    private var hasText: Bool { !vm.state.query.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // The black body fades INTO the glass, per the reference — the
            // gradient lives above the controls, over the glass.
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Surface.bandFade)
                .allowsHitTesting(false)
            GlassEffectContainer {
                HStack(spacing: 10) {
                    circleButton(symbol: "plus", help: "New conversation (⌘K)") {
                        vm.newConversation()
                        focused = true
                    }
                    pill
                    micOrSend
                }
                .padding(.horizontal, 14)
            }
            .frame(height: Surface.bandHeight)
        }
        .background {
            // The band is the ONLY glassy part of the surface: the desktop
            // shows through it, like the checkered region in the reference.
            Rectangle().fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.35)), in: Rectangle())
        }
    }

    /// Dark translucent pill, light placeholder, white text — "Ask Siri" style.
    private var pill: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(searching ? 0.04 : 0.07))
            if searching {
                HStack(spacing: 10) {
                    SixDotSpinner()
                        .frame(width: Surface.spinnerRing + 4, height: Surface.spinnerRing + 4)
                    Text(vm.state.status.isEmpty ? "Working…" : vm.state.status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .id(vm.state.status)
                        .transition(.opacity)
                }
                .padding(.horizontal, 16)
                .animation(Motion.dissolve, value: vm.state.status)
            } else {
                TextField("Ask Mnemo", text: $vm.state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($focused)
                    .onSubmit { Task { await vm.submit() } }
                    .onKeyPress(.upArrow) { vm.recallPrevious(); return .handled }
                    .onKeyPress(.downArrow) { vm.recallNext(); return .handled }
                    .onChange(of: dictation.transcript) { _, t in
                        if !t.isEmpty { vm.state.query = t }
                    }
                    .padding(.horizontal, 16)
                    .onAppear { focused = true }
            }
        }
        .frame(height: 38)
    }

    /// Mic when empty; morphs to a white filled circle with a black ↑ when
    /// text is present — exactly the reference's send morph.
    private var micOrSend: some View {
        Button {
            if dictation.isListening {
                dictation.stop()
                Task { await vm.submit() }
            } else if hasText {
                Task { await vm.submit() }
            } else {
                dictation.start()
            }
        } label: {
            ZStack {
                Circle().fill(hasText ? Color.white : Color.white.opacity(0.09))
                Image(systemName: hasText ? "arrow.up" : "mic.fill")
                    .font(.system(size: 14, weight: hasText ? .bold : .regular))
                    .foregroundStyle(hasText ? Color.black : Color.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .animation(Motion.adaptive(Motion.glyph, reduceMotion: reduceMotion), value: hasText)
        .help(hasText ? "Send (⌘⏎)" : "Dictate")
        .accessibilityLabel(hasText ? "Send" : "Dictate")
    }

    private func circleButton(symbol: String, help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white.opacity(0.09))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Answer zone (white text · one quiet chip row · outline thumbs)

struct AnswerZone: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let problem = dictation.problem {
                Text(problem)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let terminal = vm.state.terminal {
                terminalView(terminal)
            } else if !vm.state.answer.isEmpty {
                answerText
                sourceChips
                thumbs
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Large clean white text, top-left — the scarecrow-joke look. Unsupported
    /// sentences (M5) stay visually distinct.
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
                            .foregroundStyle(.white.opacity(0.65))
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

    /// Outline thumbs — up strengthens the cited memories, down just registers.
    private var thumbs: some View {
        HStack(spacing: 14) {
            Button { vm.feedback(positive: true) } label: {
                Image(systemName: vm.state.feedback == true ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel("Good answer")
            Button { vm.feedback(positive: false) } label: {
                Image(systemName: vm.state.feedback == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .accessibilityLabel("Bad answer")
        }
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    /// Terminal states stay minimal: the message plus one recovery action.
    @ViewBuilder private func terminalView(_ t: TerminalState) -> some View {
        Text(NotchReducer.message(for: t))
            .font(.system(size: Surface.answerFont))
            .lineSpacing(5)
            .foregroundStyle(.white)
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

// MARK: - 6-dot comet spinner (UI.md §8)

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
