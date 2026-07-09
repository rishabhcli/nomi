// Agent-B audit B-005
import AppKit

/// Non-activating panel hosting the notch surface (UI.md §4): floats above the
/// menu bar so the collar can sit over the notch, never activates our app, but
/// can become key while expanded so typing is immediate.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        // The window-server shadow hugs the hosting view's rectangular bounds —
        // the "sharp-cornered floating window" artifact. The float shadow is
        // drawn in SwiftUI on the NotchShape itself (UI.md §4).
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none   // all motion is SwiftUI's; never the window's
    }

    override var canBecomeKey: Bool { true }
}
