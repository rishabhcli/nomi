import CoreGraphics

/// Pure geometry for the notch surface (UI.md §3): a solid black extension of
/// the hardware notch — **square, full-bleed top corners** flush against the
/// screen's top edge, and generously **rounded bottom corners only**. At idle
/// the rect degenerates to the notch itself (small hardware-like rounding).
/// Kept in the orchestrator target so it is hermetically testable; the SwiftUI
/// `NotchShape` calls straight into `path(in:…)`.
public enum NotchShapeGeometry {
    /// The surface outline in a top-anchored rect (origin top-left, y down —
    /// the CGPath convention used for hit-testing in tests). Top corners are
    /// always square; only the bottom two round.
    public static func path(in rect: CGRect, bottomCornerRadius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let br = max(0, min(bottomCornerRadius, rect.height / 2, rect.width / 2))
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))                    // top-left, square
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.minX + br, y: rect.maxY),      // bottom-left, convex
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - br),      // bottom-right, convex
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))                 // top-right, square
        p.closeSubpath()
        return p
    }
}

/// Hover arming + mouse-out collapse: pure decisions for the detector (UI.md §5).
public enum NotchHover {
    /// Arms ONLY when the cursor is touching the very top edge of the screen
    /// (within `hoverZonePx`) AND horizontally over the notch region — not
    /// merely near the top. Throwing the cursor to the top summons; brushing
    /// below the top edge does not.
    public static func isArmed(cursor: CGPoint, notchRect: CGRect, screenFrame: CGRect, hoverZonePx: CGFloat) -> Bool {
        let atVeryTop = cursor.y >= screenFrame.maxY - hoverZonePx
        let overNotch = cursor.x >= notchRect.minX - hoverZonePx && cursor.x <= notchRect.maxX + hoverZonePx
        return atVeryTop && overNotch
    }

    /// Mouse-out collapse (UI.md §5F): true when the cursor is fully outside
    /// the combined hot rect (notch + expanded surface + grace margin).
    public static func isOutside(cursor: CGPoint, hotRect: CGRect) -> Bool {
        !hotRect.contains(cursor)
    }
}
