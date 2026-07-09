// Agent-B audit B-008
import AppKit
import MnemoOrchestrator

/// Arms the surface when the cursor reaches the top of the screen over the
/// notch, and collapses it when the cursor leaves an empty input (UI.md §5A/F).
/// Decisions are the pure `NotchHover` functions so they're covered by tests.
@MainActor
final class HoverDetector {
    private var monitor: Any?
    private var leaveWork: DispatchWorkItem?
    private let hoverZonePx: CGFloat
    private let dwell: TimeInterval = 0.4
    private let onArm: () -> Void
    private let onLeave: () -> Void
    /// Returns the current mouse-out hot rect, or nil when leave-collapse is off.
    private let leaveRegion: () -> CGRect?

    init(hoverZonePx: CGFloat,
         onArm: @escaping () -> Void,
         onLeave: @escaping () -> Void = {},
         leaveRegion: @escaping () -> CGRect? = { nil }) {
        self.hoverZonePx = hoverZonePx
        self.onArm = onArm
        self.onLeave = onLeave
        self.leaveRegion = leaveRegion
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self else { return }
            let loc = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) })
                    ?? NSScreen.main else { return }
            let notch = screen.mnemoNotchRectOrVirtual
            if NotchHover.isArmed(cursor: loc, notchRect: notch, screenFrame: screen.frame,
                                  hoverZonePx: hoverZonePx) {
                cancelLeave()
                self.onArm()
                return
            }
            trackLeave(cursor: loc)
        }
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
                  NotchHover.isOutside(cursor: NSEvent.mouseLocation, hotRect: hot) else { return }
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
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        cancelLeave()
    }
}
