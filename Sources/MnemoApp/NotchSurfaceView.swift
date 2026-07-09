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

    @Namespace private var glassNamespace
    @FocusState private var focused: Bool
    @State private var answerHeight: CGFloat = 0   // measured once per content change
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase: NotchPhase { vm.state.phase }
    private var listening: Bool { dictation.isListening }
    /// Derived from `NotchSurfacePhaseBinding` — no orphan UI state.
    private var showsTray: Bool { NotchSurfacePhaseBinding.showsTray(phase: phase, listening: listening) }
    private var showsHandle: Bool {
        NotchSurfacePhaseBinding.showsHandle(phase: phase, answerHeight: answerHeight, cap: Surface.answerCap)
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
                          showHandle: showsHandle, glassNamespace: glassNamespace)
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
        .onAppear { vm.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in vm.reduceMotion = v }
        .contentShape(Rectangle())
        .gesture(holdToDictate)
        .onTapGesture {
            // Tapping the listening drop stops + submits; tapping the idle
            // notch summons.
            if dictation.isListening {
                dictation.stop()
                if !vm.state.query.isEmpty { Task { await vm.submit() } }
            } else if phase == .idle {
                vm.summon()
            }
        }
        .background(shortcuts)
        .onExitCommand { NSApp.sendAction(#selector(AppDelegate.dismissNotch), to: nil, from: nil) }
        .onChange(of: phase) { _, p in
            if NotchSurfacePhaseBinding.shouldFocusInput(phase: p) { focused = true }
            if !NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: p, listening: listening) {
                answerHeight = 0
            }
        }
        .onChange(of: listening) { _, nowListening in
            if !NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: phase, listening: nowListening) {
                answerHeight = 0
            }
        }
        // The transcript→query bridge lives on the ALWAYS-mounted surface — the
        // tray (which used to hold it) is unmounted during the listening drop,
        // so binding it here is what lets a dictated phrase reach submit.
        .onChange(of: dictation.transcript) { _, t in
            guard NotchSurfacePhaseBinding.acceptsDictationTranscript(phase: phase, listening: listening),
                  !t.isEmpty else { return }
            vm.state.query = t
        }
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
        .accessibilityHint("Ask, or hold to dictate")
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
        }
    }

    /// Answer area (reference): white text, one quiet source chip row, outline
    /// thumbs. Scrolls only past the cap.
    private var answerZone: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AnswerZone(vm: vm, dictation: dictation, reduceMotion: reduceMotion)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { answerHeight = $0 }
        }
        .frame(height: min(max(answerHeight, 1), Surface.answerCap))
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Privacy folded into a tiny dot: green = 0 egress.
    @ViewBuilder private var privacyDot: some View {
        if NotchSurfacePhaseBinding.showsPrivacyDot(phase: phase) {
            Circle()
                .fill(vm.privacy == .clean ? Color.green.opacity(0.85) : Color.orange)
                .frame(width: 4, height: 4)
                .padding(.leading, 13).padding(.bottom, 11)
                .help(vm.privacy == .clean ? "On-device · 0 egress" : "Egress blocked — see log")
                .accessibilityLabel("Privacy status")
        }
    }

    /// Press-hold the surface is push-to-talk; release submits.
    private var holdToDictate: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                if case .second = value, !dictation.isListening {
                    if vm.state.phase == .idle { vm.summon() }
                    dictation.start()
                }
            }
            .onEnded { _ in
                guard dictation.isListening else { return }
                dictation.stop()
                if !vm.state.query.isEmpty { Task { await vm.submit() } }
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
