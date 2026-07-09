import SwiftUI
import MnemoOrchestrator

/// The notch surface (UI.md §0/§3, reference: assets/IMG_1149 + IMG_1150):
/// a solid-black extension of the hardware notch — square top corners flush
/// with the screen top, rounded bottom corners — with a translucent Liquid
/// Glass input band curving around the bottom edge. Idle it IS the notch;
/// expanded it is the notch grown larger.
///
/// Glitch-free rules (UI.md §4): the panel never moves; ALL geometry lives in
/// one `SurfaceGeometry` value animated by ONE `.animation` modifier — no
/// stacked springs, no measurement feedback loops, no glass on the surface.
struct NotchSurfaceView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var dictation: Dictation
    @ObservedObject var narrator: Narrator
    var notchSize: CGSize

    @FocusState private var focused: Bool
    @State private var answerHeight: CGFloat = 0   // measured once per content change
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase: NotchPhase { vm.state.phase }
    private var listening: Bool { dictation.isListening }

    /// One value drives width + height + radius so exactly one spring runs.
    private var geometry: SurfaceGeometry {
        SurfaceGeometry(phase: phase, listening: listening,
                        notch: notchSize, answerHeight: answerHeight)
    }

    private var spring: Animation {
        switch phase {
        case .idle: Motion.collapse
        default: Motion.grow
        }
    }

    var body: some View {
        surface
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var surface: some View {
        let geo = geometry
        return VStack(spacing: 0) {
            blackZone
            InputBand(vm: vm, dictation: dictation, focused: $focused,
                      searching: phase == .searching, reduceMotion: reduceMotion)
                .frame(height: phase == .idle ? 0 : Surface.bandFade + Surface.bandHeight)
                .clipped()
                .opacity(phase == .idle ? 0 : 1)
                .allowsHitTesting(phase != .idle)
        }
        .frame(width: geo.width, height: geo.height, alignment: .top)
        .clipShape(NotchShape(bottomCornerRadius: geo.radius))
        .shadow(color: .black.opacity(phase == .idle ? 0 : Surface.shadowOpacity),
                radius: Surface.shadowRadius, y: Surface.shadowY)
        .overlay(alignment: .bottomLeading) { privacyDot }
        .animation(Motion.adaptive(spring, reduceMotion: reduceMotion), value: geo)
        .background(shortcuts)
        .onExitCommand { NSApp.sendAction(#selector(AppDelegate.dismissNotch), to: nil, from: nil) }
        .onChange(of: phase) { _, p in
            if p == .input || p == .answering { focused = true }
        }
    }

    /// The solid-black body: pure #000 continuing the hardware notch. Content
    /// (answer / orb) lives top-aligned inside it; a gradient at its bottom
    /// bridges into the glass band exactly like the reference.
    private var blackZone: some View {
        ZStack(alignment: .top) {
            Color.black
            Group {
                if listening {
                    VoiceOrbView(amplitude: dictation.amplitude)
                        .padding(.top, 10)
                        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
                } else if phase == .answering || phase == .state {
                    answerZone
                        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
                }
            }
            .padding(.top, notchSize.height)   // content starts below the hardware notch
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(holdToDictate)
        .onTapGesture { if phase == .idle { vm.summon() } }
        .animation(Motion.adaptive(Motion.dissolve, reduceMotion: reduceMotion), value: listening)
        .accessibilityLabel("Mnemo")
        .accessibilityHint("Ask, or hold to dictate")
    }

    /// Answer area per the reference: white text, one quiet source chip row,
    /// outline thumbs. Nothing else. Scrolls only past the cap.
    private var answerZone: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AnswerZone(vm: vm, dictation: dictation)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { answerHeight = $0 }
        }
        .frame(height: min(max(answerHeight, 1), Surface.answerCap))
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Privacy folded into a tiny dot (UI.md §8): green = 0 egress.
    @ViewBuilder private var privacyDot: some View {
        if phase != .idle {
            Circle()
                .fill(vm.privacy == .clean ? Color.green.opacity(0.8) : Color.orange)
                .frame(width: 4, height: 4)
                .padding(.leading, 12).padding(.bottom, 10)
                .help(vm.privacy == .clean ? "On-device · 0 egress" : "Egress blocked — see log")
                .accessibilityLabel("Privacy status")
        }
    }

    /// UI.md §12: press-hold the black surface is push-to-talk; release submits.
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

/// The one animated value: width, height, and bottom radius per phase.
/// Explicit sizes — no layout measurement feeds back into the spring except
/// the answer zone's capped height.
struct SurfaceGeometry: Equatable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat

    init(phase: NotchPhase, listening: Bool, notch: CGSize, answerHeight: CGFloat) {
        let notchH = max(notch.height, 24)
        if listening {
            width = Surface.inputWidth
            height = notchH + Surface.orbZoneHeight + Surface.bandHeight
            radius = Surface.bottomRadius
            return
        }
        switch phase {
        case .idle:
            width = notch.width
            height = notchH
            radius = Surface.idleRadius
        case .input, .searching:
            width = Surface.inputWidth
            height = notchH + 10 + Surface.bandHeight
            radius = Surface.bottomRadius
        case .answering, .state:
            width = Surface.readWidth
            let zone = min(max(answerHeight, 60), Surface.answerCap)
            height = notchH + zone + 14 + Surface.bandHeight
            radius = Surface.bottomRadius
        }
    }
}
