import AppKit
import MnemoOrchestrator

extension NSScreen {
    var mnemoNotchRect: CGRect? {
        NotchGeometry.rect(screenFrame: frame, safeAreaTop: safeAreaInsets.top,
                           auxLeftWidth: auxiliaryTopLeftArea?.width ?? 0,
                           auxRightWidth: auxiliaryTopRightArea?.width ?? 0)
    }
    /// Virtual notch for no-notch displays (200x32 pill at top-center). Full spec: UI.md §2.
    var mnemoNotchRectOrVirtual: CGRect {
        mnemoNotchRect ?? CGRect(x: frame.midX - 100, y: frame.maxY - 32, width: 200, height: 32)
    }
}
