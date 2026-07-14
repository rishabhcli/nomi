import SwiftUI
import MnemoOrchestrator

/// Keeps the bottom handle's dismissal interaction isolated from the surface's
/// single geometry animation. Only the handle area participates, leaving the
/// answer scroll view, field, and buttons with their normal gestures.
struct SurfaceDismissModifier: ViewModifier {
    let enabled: Bool
    let surfaceHeight: CGFloat
    let phase: NotchPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var opacity = 1.0
    @State private var dismissing = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if enabled { gestureTarget }
            }
            .offset(y: offset)
            .opacity(opacity
                * (1 - Double(SurfaceDismissGesture.progress(translationY: offset)) * 0.08))
            .onChange(of: phase) { _, newPhase in
                if newPhase == .idle { reset() }
            }
    }

    private var gestureTarget: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: max(28, Surface.trayHandle))
            .contentShape(Rectangle())
            .gesture(dismissGesture)
            .allowsHitTesting(!dismissing)
            .accessibilityLabel("Dismiss Mnemo")
            .accessibilityHint("Hold, then swipe up")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }
    }

    private var dismissGesture: some Gesture {
        LongPressGesture(
            minimumDuration: SurfaceDismissGesture.holdDuration,
            maximumDistance: 12
        )
        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
        .onChanged { value in
            guard !dismissing else { return }
            guard case let .second(_, drag?) = value else { return }
            offset = SurfaceDismissGesture.interactiveOffset(
                translationY: drag.translation.height
            )
        }
        .onEnded { value in
            guard case let .second(_, drag?) = value else {
                restore()
                return
            }
            let velocity = SurfaceDismissGesture.estimatedVelocityY(
                translationY: drag.translation.height,
                predictedEndTranslationY: drag.predictedEndTranslation.height
            )
            if SurfaceDismissGesture.shouldDismiss(
                translationY: drag.translation.height,
                velocityY: velocity
            ) {
                commit()
            } else {
                restore()
            }
        }
    }

    private func restore() {
        if reduceMotion {
            reset()
            return
        }
        withAnimation(Motion.adaptive(Motion.summon, reduceMotion: reduceMotion)) {
            offset = 0
        }
    }

    private func commit() {
        guard !dismissing else { return }
        dismissing = true
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.20)) { opacity = 0 }
        } else {
            withAnimation(Motion.collapse) { offset = -max(1, surfaceHeight) }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 210 : 260))
            NSApp.sendAction(#selector(AppDelegate.dismissNotch), to: nil, from: nil)
            reset()
        }
    }

    private func reset() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            offset = 0
            opacity = 1
            dismissing = false
        }
    }
}

extension View {
    func surfaceDismissGesture(
        enabled: Bool,
        surfaceHeight: CGFloat,
        phase: NotchPhase
    ) -> some View {
        modifier(SurfaceDismissModifier(
            enabled: enabled,
            surfaceHeight: surfaceHeight,
            phase: phase
        ))
    }
}
