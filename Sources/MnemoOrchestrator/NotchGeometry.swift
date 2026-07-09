import CoreGraphics

public enum NotchGeometry {
    public static func hasNotch(safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> Bool {
        safeAreaTop > 0 && auxLeftWidth > 0 && auxRightWidth > 0
    }
    public static func rect(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> CGRect? {
        guard hasNotch(safeAreaTop: safeAreaTop, auxLeftWidth: auxLeftWidth, auxRightWidth: auxRightWidth) else { return nil }
        let width = screenFrame.width - auxLeftWidth - auxRightWidth
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - safeAreaTop, width: width, height: safeAreaTop)
    }

    /// The panel's frame (UI.md §4): centered on the notch, **top edge flush
    /// with the screen top** — in AppKit's bottom-left origin that means
    /// `origin.y = screen.maxY - height`, never `notch.minY - height` (which
    /// leaves the collar dangling below the notch: the mid-screen bug).
    public static func panelRect(screenFrame: CGRect, notch: CGRect, panelSize: CGSize) -> CGRect {
        CGRect(x: notch.midX - panelSize.width / 2,
               y: screenFrame.maxY - panelSize.height,
               width: panelSize.width, height: panelSize.height)
    }
}
