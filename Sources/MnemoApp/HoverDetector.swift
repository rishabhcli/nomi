// Agent-B audit B-008
// Agent-B audit B-026
import AppKit
import MnemoOrchestrator

/// Arms the surface when the cursor reaches the top of the screen over the
/// notch, and collapses it when the cursor leaves an empty input (UI.md §5A/F).
/// Decisions are the pure `NotchHover` functions so they're covered by tests.
@MainActor
final class HoverDetector {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var leaveWork: DispatchWorkItem?
    private var lastLocation = NSEvent.mouseLocation
    private let hoverZonePx: CGFloat
    private let dwell: TimeInterval = 0.4
    private let onMove: (CGPoint) -> Void
    private let onArm: () -> Void
    private let onLeave: () -> Void
    /// Returns the current mouse-out hot rect, or nil when leave-collapse is off.
    private let leaveRegion: () -> CGRect?

    init(hoverZonePx: CGFloat,
         onMove: @escaping (CGPoint) -> Void = { _ in },
         onArm: @escaping () -> Void,
         onLeave: @escaping () -> Void = {},
         leaveRegion: @escaping () -> CGRect? = { nil }) {
        self.hoverZonePx = hoverZonePx
        self.onMove = onMove
        self.onArm = onArm
        self.onLeave = onLeave
        self.leaveRegion = leaveRegion
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(at: event.locationInWindow)
        }
        // Global monitors do not receive events delivered to this app. Once the
        // panel is key, the local monitor keeps mouse-out collapse responsive.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let location = event.window?.convertPoint(toScreen: event.locationInWindow)
                ?? event.locationInWindow
            self?.handleMouseMove(at: location)
            return event
        }
    }

    private func handleMouseMove(at location: CGPoint) {
        lastLocation = location
        onMove(location)
        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(location, $0.frame, false)
        }) ?? NSScreen.main else { return }
        let notch = screen.mnemoNotchRectOrVirtual
        if NotchHover.isArmed(cursor: location, notchRect: notch, screenFrame: screen.frame,
                              hoverZonePx: hoverZonePx) {
            cancelLeave()
            onArm()
            return
        }
        trackLeave(cursor: location)
    }

    /// Mouse-out collapse with a dwell: fires only after the cursor has been
    /// fully outside the hot rect for `dwell` seconds.
    private func trackLeave(cursor: CGPoint) {
        guard let hot = leaveRegion() else { cancelLeave(); return }
        guard NotchHover.isOutside(cursor: cursor, hotRect: hot) else { cancelLeave(); return }
        guard leaveWork == nil else { return }   // dwell already running
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.leaveWork = nil
            guard let hot = self.leaveRegion(),
                  NotchHover.isOutside(cursor: self.lastLocation, hotRect: hot) else { return }
            self.onLeave()
        }
        leaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dwell, execute: work)
    }

    private func cancelLeave() {
        leaveWork?.cancel()
        leaveWork = nil
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        cancelLeave()
    }
}
