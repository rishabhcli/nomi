import SwiftUI
import MnemoOrchestrator

/// The notch surface (reference: Tests/Fixtures/reference) as ONE cohesive
/// object: a pure-black body that continues the hardware notch, with a
/// translucent Liquid-Glass tray curving around the bottom (the desktop shows
/// through it) that holds the controls and the home-indicator. Voice is a
/// narrow "drop" that grows straight DOWN from the notch with the reactive orb
/// inside — it never widens the notch.
///
/// Glitch-free rules: the panel never moves; ALL geometry lives in ONE
/// `SurfaceGeometry` value driven by exactly ONE `.animation` modifier. No
/// stacked springs, no separate opacity/clip animations on nested pieces, no
/// desktop-showing gap between the body and the controls.
struct NotchSurfaceView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @ObservedObject var narrator: Narrator
    var notchSize: CGSize

    @FocusState private var focused: Bool
    @State private var answerHeight: CGFloat = 0   // measured once per content change
    @State private var heldDictation = false       // push-to-talk started by a hold (vs a tap)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase: NotchPhase { vm.state.phase }
    private var listening: Bool { dictation.isListening }
    /// The glass tray shows in every expanded state except the listening drop.
    private var showsTray: Bool { phase != .idle && !listening }
    /// The pull-handle appears ONLY when there is a real conversation that
    /// overflows the cap — i.e. there is more to scroll to. Never in the empty
    /// input or the working/searching state.
    private var showsHandle: Bool {
        (phase == .answering || phase == .state) && answerHeight > Surface.answerCap
    }

    /// One value drives width + height + radius so exactly one spring runs.
    private var geometry: SurfaceGeometry {
        SurfaceGeometry(phase: phase, listening: listening,
                        notch: notchSize, answerHeight: answerHeight)
    }

    private var spring: Animation { phase == .idle ? Motion.collapse : Motion.grow }

    var body: some View {
        surface.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var surface: some View {
        let geo = geometry
        return ZStack(alignment: .top) {
            base(geo)
            content
                .padding(.top, notchSize.height)                 // clears the hardware notch
                .padding(.bottom, showsTray ? Surface.trayHeight : 0)
            if showsTray {
                InputTray(vm: vm, dictation: dictation, focused: $focused,
                          searching: phase == .searching, reduceMotion: reduceMotion,
                          showHandle: showsHandle)
                    .frame(height: Surface.trayHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .frame(width: geo.width, height: geo.height, alignment: .top)
        .clipShape(NotchShape(bottomCornerRadius: geo.radius))
        .shadow(color: .black.opacity(phase == .idle ? 0 : Surface.shadowOpacity),
                radius: Surface.shadowRadius, y: Surface.shadowY)
        .overlay(alignment: .bottomLeading) { privacyDot }
        .animation(Motion.adaptive(spring, reduceMotion: reduceMotion), value: geo)
        .contentShape(Rectangle())
        // Click the notch → voice: toggle on-device dictation (the listening
        // orb). Click again while listening stops and submits. A press-hold is
        // push-to-talk. Tap and long-press coexist cleanly here — unlike the old
        // sequenced LongPress→Drag gesture, which swallowed the tap so a click
        // did nothing. Hover still opens the auto-focused text field for typing.
        .onTapGesture {
            if dictation.isListening {
                dictation.stop()
                if !vm.state.query.isEmpty { Task { await vm.submit() } }
            } else {
                if vm.state.phase == .idle { vm.summon() }
                dictation.start()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 50) {
            guard !dictation.isListening else { return }
            if vm.state.phase == .idle { vm.summon() }
            dictation.start()
            heldDictation = true
        } onPressingChanged: { pressing in
            guard !pressing else { return }
            // Release ends push-to-talk — but only if a hold started it, so a
            // quick tap's toggle isn't immediately cancelled by the release.
            if heldDictation, dictation.isListening {
                dictation.stop()
                if !vm.state.query.isEmpty { Task { await vm.submit() } }
            }
            heldDictation = false
        }
        .background(shortcuts)
        .onExitCommand { NSApp.sendAction(#selector(AppDelegate.dismissNotch), to: nil, from: nil) }
        .onChange(of: phase) { _, p in if p == .input || p == .answering { focused = true } }
        // The transcript→query bridge lives on the ALWAYS-mounted surface — the
        // tray (which used to hold it) is unmounted during the listening drop,
        // so binding it here is what lets a dictated phrase reach submit.
        .onChange(of: dictation.transcript) { _, t in if !t.isEmpty { vm.state.query = t } }
        // A dictation failure (denied permission, no model, no mic) has no body
        // space of its own in the input/drop states — surface it as a visible
        // message instead of failing silently.
        .onChange(of: dictation.problem) { _, p in
            guard let p, !p.isEmpty else { return }
            vm.presentInfo(p)
            dictation.problem = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mnemo")
        .accessibilityHint("Click or hold to dictate; hover to type")
    }

    /// The body is opaque #000 (indistinguishable from the hardware notch). The
    /// tray region is left CLEAR so the tray's Liquid Glass samples the desktop
    /// — that is what makes the bottom translucent like the reference. Idle and
    /// the listening drop are fully black.
    @ViewBuilder private func base(_ geo: SurfaceGeometry) -> some View {
        if showsTray {
            VStack(spacing: 0) {
                Rectangle().fill(.black)
                Color.clear.frame(height: Surface.trayHeight)
            }
        } else {
            Rectangle().fill(.black)
        }
    }

    /// The one piece of content that lives in the black body: the answer, or
    /// the listening orb. Input/searching have nothing here — their field and
    /// spinner live in the tray. Swaps ride the shared spring via a blur-morph.
    @ViewBuilder private var content: some View {
        if listening {
            VoiceOrbView(amplitude: dictation.amplitude)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        } else if phase == .answering || phase == .state {
            answerZone
                .frame(maxWidth: .infinity, alignment: .top)
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        } else if phase == .searching {
            searchingHeader
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        }
    }

    /// During search, show what the user asked (spoken or typed) above the tray
    /// spinner — so "heard you → searching" is observable, not a blind spinner.
    private var searchingHeader: some View {
        VStack(spacing: 5) {
            Text(vm.state.query.isEmpty ? "…" : "\u{201C}\(vm.state.query)\u{201D}")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 22)
            Text("Searching your memory…")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }

    /// Answer area (reference): white text, one quiet source chip row, outline
    /// thumbs. Scrolls only past the cap.
    private var answerZone: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AnswerZone(vm: vm, dictation: dictation)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { answerHeight = $0 }
        }
        .frame(height: min(max(answerHeight, 1), Surface.answerCap))
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Privacy folded into a tiny dot: green = 0 egress.
    @ViewBuilder private var privacyDot: some View {
        if phase != .idle {
            Circle()
                .fill(vm.privacy == .clean ? Color.green.opacity(0.85) : Color.orange)
                .frame(width: 4, height: 4)
                .padding(.leading, 13).padding(.bottom, 11)
                .help(vm.privacy == .clean ? "On-device · 0 egress" : "Egress blocked — see log")
                .accessibilityLabel("Privacy status")
        }
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { Task { await vm.submit() } }
                .keyboardShortcut(.return, modifiers: .command).hidden()
            Button("") { vm.newConversation() }
                .keyboardShortcut("k", modifiers: .command).hidden()
            Button("") { vm.copyAnswer() }
                .keyboardShortcut("c", modifiers: [.command, .shift]).hidden()
        }
    }
}

/// The one animated value: width, height, and bottom radius per state. Explicit
/// targets — no per-frame layout feedback except the answer zone's capped
/// height, which grows the read surface as the answer streams.
struct SurfaceGeometry: Equatable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat

    init(phase: NotchPhase, listening: Bool, notch: CGSize, answerHeight: CGFloat) {
        let notchH = max(notch.height, 24)
        if listening {
            // The drop: notch-width (never wider), grows down, semicircle bottom.
            let w = max(notch.width, Surface.dropWidth)
            width = w
            height = notchH + Surface.dropBody
            radius = w / 2
            return
        }
        switch phase {
        case .idle:
            width = notch.width
            height = notchH
            radius = Surface.idleRadius
        case .input, .searching:
            width = Surface.inputWidth
            height = notchH + Surface.trayHeight
            radius = Surface.bottomRadius
        case .answering, .state:
            width = Surface.readWidth
            let zone = min(max(answerHeight, 48), Surface.answerCap)
            height = notchH + zone + 12 + Surface.trayHeight
            radius = Surface.bottomRadius
        }
    }
}
