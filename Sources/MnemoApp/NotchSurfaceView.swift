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
    @Environment(\.colorSchemeContrast) private var contrast
    @Namespace private var glassNS
    /// System "Increase Contrast" — strengthens tints, text, and the edge.
    private var highContrast: Bool { contrast == .increased }

    private var phase: NotchPhase { vm.state.phase }
    private var listening: Bool { dictation.isListening }
    private var showsPermissionOnboarding: Bool { vm.showsPermissionOnboarding }
    private var showsStarterProfile: Bool { vm.showsStarterProfile }
    private var showsOnboarding: Bool { showsPermissionOnboarding || showsStarterProfile }
    /// The glass tray shows in every expanded state except the listening drop.
    private var showsTray: Bool { phase != .idle && !listening && !showsOnboarding }
    private var showsGlass: Bool { (phase != .idle || showsOnboarding) && !listening }
    /// One value drives width + height + radius so exactly one spring runs.
    private var geometry: SurfaceGeometry {
        SurfaceGeometry(phase: phase, listening: listening,
                        notch: notchSize, answerHeight: answerHeight,
                        starterProfile: showsOnboarding)
    }

    private var spring: Animation { phase == .idle ? Motion.collapse : Motion.grow }

    var body: some View {
        surface.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var surface: some View {
        let geo = geometry
        // One GlassEffectContainer groups every glass element (the bottom
        // material + the terminal-recovery buttons) so glass never samples glass
        // (UI.md §1.2, fidelity F5).
        return GlassEffectContainer {
            ZStack(alignment: .top) {
                material(geo)
                if showsPermissionOnboarding {
                    PermissionOnboardingView(vm: vm)
                        .padding(.top, notchSize.height)
                        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
                } else if showsStarterProfile {
                    StarterProfileView(vm: vm)
                        .padding(.top, notchSize.height)
                        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
                } else {
                    content
                        .padding(.top, notchSize.height)             // clears the hardware notch
                        .padding(.bottom, showsTray ? Surface.trayHeight : 0)
                    if showsTray {
                        InputTray(vm: vm, dictation: dictation, focused: $focused,
                                  searching: phase == .searching, reduceMotion: reduceMotion)
                            .frame(height: Surface.trayHeight)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.opacity)
                    }
                    voiceGestureTarget(surfaceWidth: geo.width)
                }
            }
        }
        // Liquid Glass responds to the control-active environment by default.
        // This system surface has a fixed visual identity, so keep its material
        // active even when another app becomes key; the body itself remains #000.
        .environment(\.controlActiveState, .active)
        .frame(width: geo.width, height: geo.height, alignment: .top)
        .clipShape(NotchShape(topCornerRadius: geo.shoulder, bottomCornerRadius: geo.radius))
        // A hairline edge separates the black slab from a dark desktop without
        // breaking the seamless top: the stroke is clear at the very top (where
        // the surface continues the bezel) and strongest down the sides/bottom.
        .overlay {
            if phase != .idle {
                NotchShape(topCornerRadius: geo.shoulder, bottomCornerRadius: geo.radius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0),
                                     .white.opacity(highContrast
                                         ? SurfaceUX.IncreaseContrast.borderStrokeOpacity : 0.08)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.75)
            }
        }
        .shadow(color: .black.opacity(phase == .idle ? 0 : Surface.shadowOpacity),
                radius: Surface.shadowRadius, y: Surface.shadowY)
        .overlay(alignment: .bottomLeading) { privacyDot }
        .surfaceDismissGesture(enabled: showsGlass, surfaceHeight: geo.height, phase: phase)
        // Only phase/listening transitions own the notch morph spring. Answer
        // text reflow changes height in quantized steps without continuously
        // retargeting that spring as tokens stream.
        .animation(
            Motion.adaptive(spring, reduceMotion: reduceMotion),
            value: SurfaceAnimationKey(phase: phase, listening: listening)
        )
        // Voice gestures are attached only to the collar overlay above. The
        // input, answer, source, and recovery regions remain normal controls.
        .background(shortcuts)
        .onExitCommand { NSApp.sendAction(#selector(AppDelegate.dismissNotch), to: nil, from: nil) }
        .onChange(of: phase) { _, p in
            if p == .searching { answerHeight = 0 }
            if p == .input || p == .answering { focused = true }
        }
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
        .accessibilityHint("Click or hold the notch to dictate; hover to type")
    }

    /// Stable, notch-sized hit target. Keeping these gestures off the outer
    /// surface prevents ordinary interaction with the expanded UI from
    /// unexpectedly opening the microphone.
    private func voiceGestureTarget(surfaceWidth: CGFloat) -> some View {
        let target = NotchInteraction.voiceTargetRect(
            surfaceWidth: surfaceWidth,
            notchSize: notchSize
        )
        return Color.clear
            .frame(width: target.width, height: target.height)
            .contentShape(Rectangle())
            .accessibilityLabel("Dictate")
            // Click the notch -> voice: toggle on-device dictation. Click again
            // while listening stops and submits; press-hold is push-to-talk.
        .onTapGesture {
            if dictation.isListening {
                dictation.stop()
                if !vm.state.query.isEmpty { vm.beginSubmit() }
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
                if !vm.state.query.isEmpty { vm.beginSubmit() }
            }
            heldDictation = false
        }
    }

    /// The surface material (UI.md §3). Idle and the listening drop are solid
    /// opaque black (indistinguishable from the hardware notch). In the expanded
    /// states, Liquid Glass fills the bottom ~third and the opaque-black body
    /// fades out across it — one seamless melt from pure black at the top to
    /// translucent glass at the bottom (the desktop shows through). The glass is
    /// drawn BEHIND the body so it samples the desktop, not the black; the
    /// body's downward fade is what reveals it.
    @ViewBuilder private func material(_ geo: SurfaceGeometry) -> some View {
        if showsGlass {
            let material = SurfaceMaterialGeometry(
                totalHeight: geo.height,
                glassFraction: Surface.glassFraction
            )
            ZStack(alignment: .top) {
                Rectangle().fill(.clear)
                    .glassEffect(
                        .regular.tint(.black.opacity(
                            SurfaceUX.GlassHierarchy.trayTint(highContrast: highContrast))),
                        in: Rectangle())
                    .glassEffectID("surface", in: glassNS)
                    .frame(height: material.glassHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Rectangle().fill(.black)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: material.fadeStart),
                                .init(color: .white.opacity(0), location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom))
            }
        } else {
            Rectangle().fill(.black)
        }
    }

    /// Content in the black body: live activity while searching, the answer, or
    /// the listening orb. Input stays tray-only. Swaps use the shared morph.
    @ViewBuilder private var content: some View {
        switch SurfaceBodyPolicy.kind(phase: phase, listening: listening) {
        case .voiceOrb:
            VoiceOrbView(amplitude: dictation.amplitude)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        case .answer:
            answerZone
                .frame(maxWidth: .infinity, alignment: .top)
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        case .activityTrace:
            searchingActivityBody
                .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        case .none:
            EmptyView()
        }
    }

    /// Searching gets a real body above the tray: the question plus the same
    /// expandable activity trace that persists with the answer. The spinner can
    /// stay compact in the tray without making the work a black box.
    private var searchingActivityBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(vm.state.query.isEmpty ? "Working on your request" : vm.state.query)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ReasoningTraceView(
                    steps: vm.state.reasoning,
                    status: vm.state.status,
                    understanding: vm.state.understanding,
                    phase: vm.state.phase,
                    hasAnswer: false,
                    reduceMotion: reduceMotion
                )
                SourceChipRow(sources: vm.state.sources)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(height: Surface.searchingBodyHeight)
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Answer area (reference): white text, one quiet source chip row, outline
    /// thumbs. Scrolls only past the cap.
    private var answerZone: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AnswerZone(vm: vm, dictation: dictation, narrator: narrator)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { measured in
                    let next = SurfaceAnswerLayout.quantizedHeight(measured, cap: Surface.answerCap)
                    if next != answerHeight { answerHeight = next }
                }
        }
        .frame(height: min(max(answerHeight, 1), Surface.answerCap))
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Privacy folded into a tiny dot: green = 0 egress.
    @ViewBuilder private var privacyDot: some View {
        if phase != .idle || showsStarterProfile {
            Circle()
                .fill(vm.privacy == .clean ? Color.green.opacity(0.85) : Color.orange)
                .frame(width: 4, height: 4)
                .padding(.leading, 13).padding(.bottom, 11)
                .help(vm.privacy == .clean ? "On-device · 0 observed outbound" : "Outbound observed — see log")
                .accessibilityLabel("Privacy status")
        }
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { vm.beginSubmit() }
                .keyboardShortcut(.return, modifiers: .command).hidden()
            Button("") { vm.newConversation() }
                .keyboardShortcut("k", modifiers: .command).hidden()
            Button("") { vm.copyAnswer() }
                .keyboardShortcut("c", modifiers: [.command, .shift]).hidden()
        }
    }
}

private struct SurfaceAnimationKey: Equatable {
    let phase: NotchPhase
    let listening: Bool
}

/// The one animated value: width, height, and bottom radius per state. Explicit
/// targets — no per-frame layout feedback except the answer zone's capped
/// height, which grows the read surface as the answer streams.
struct SurfaceGeometry: Equatable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    /// Concave top-corner (shoulder) radius; rides the same spring as `radius`.
    let shoulder: CGFloat

    init(phase: NotchPhase, listening: Bool, notch: CGSize, answerHeight: CGFloat,
         starterProfile: Bool = false) {
        let notchH = max(notch.height, 24)
        if starterProfile {
            width = Surface.readWidth
            height = notchH + Surface.starterProfileBodyHeight
            radius = Surface.bottomRadius
            shoulder = Surface.shoulderRadius
            return
        }
        if listening {
            // The drop: notch-width (never wider), grows down, semicircle bottom.
            // The semicircle leaves no room for a shoulder (geometry clamps it).
            let w = max(notch.width, Surface.dropWidth)
            width = w
            height = notchH + Surface.dropBody
            radius = w / 2
            shoulder = Surface.idleShoulder
            return
        }
        switch phase {
        case .idle:
            width = notch.width
            height = notchH
            radius = Surface.idleRadius
            shoulder = Surface.idleShoulder
        case .input:
            width = Surface.inputWidth
            height = notchH + Surface.trayHeight
            radius = Surface.bottomRadius
            shoulder = Surface.shoulderRadius
        case .searching:
            width = Surface.inputWidth
            height = notchH + Surface.searchingBodyHeight + Surface.trayHeight
            radius = Surface.bottomRadius
            shoulder = Surface.shoulderRadius
        case .answering, .state:
            width = Surface.readWidth
            let zone = min(max(answerHeight, 48), Surface.answerCap)
            height = notchH + zone + 12 + Surface.trayHeight
            radius = Surface.bottomRadius
            shoulder = Surface.shoulderRadius
        }
    }
}
