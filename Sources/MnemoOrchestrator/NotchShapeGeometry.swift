import CoreGraphics

/// Pure geometry for the notch surface (UI.md §3): a solid black extension of
/// the hardware notch. The **top edge is full-bleed and flush** with the screen
/// top (invariant F3), but the two top corners are **concave "shoulders"** that
/// flare the inset side walls back out to that edge — the MacBook-notch look,
/// "the notch grown wider." The bottom two corners are **convex rounded**. All
/// four corners use **continuous curvature** (cubic Béziers, squircle-leaning)
/// rather than plain arcs. At idle the rect degenerates to the notch itself
/// with a small shoulder + rounding. Kept in the orchestrator target so it is
/// hermetically testable; the SwiftUI `NotchShape` calls straight into `path`.
public enum NotchShapeGeometry {
    /// Cubic-Bézier "magic" ratio for a smooth (near-circular / squircle-leaning)
    /// quarter corner: control points pull from each endpoint toward the square
    /// corner by this fraction.
    private static let cornerSmoothing: CGFloat = 0.5523

    /// The surface outline in a top-anchored rect (origin top-left, y down —
    /// the CGPath convention used for hit-testing in tests). `topCornerRadius`
    /// is the concave shoulder inset; `bottomCornerRadius` the convex bottom
    /// rounding. Both clamp to the rect so the path is always valid (e.g. the
    /// listening drop's semicircle bottom clamps the shoulder to 0).
    public static func path(in rect: CGRect,
                            topCornerRadius: CGFloat,
                            bottomCornerRadius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let halfW = rect.width / 2
        let halfH = rect.height / 2
        let br = max(0, min(bottomCornerRadius, halfH, halfW))
        // The walls run from y=tr to y=maxY-br, and the bottom straight edge
        // needs room for both corners: 2*(tr+br) <= width. Clamp the shoulder
        // to whatever room the bottom rounding leaves (→ 0 for a semicircle).
        let tr = max(0, min(topCornerRadius, halfH, rect.height - br, halfW - br))

        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY

        // A continuous-curvature quarter corner: cubic from `a` to `b` whose two
        // control points pull toward the square corner `c`. Works for both the
        // convex bottom corners and the concave top shoulders (only the corner
        // position differs).
        func corner(from a: CGPoint, toward c: CGPoint, to b: CGPoint) {
            let k = cornerSmoothing
            let c1 = CGPoint(x: a.x + (c.x - a.x) * k, y: a.y + (c.y - a.y) * k)
            let c2 = CGPoint(x: b.x + (c.x - b.x) * k, y: b.y + (c.y - b.y) * k)
            p.addCurve(to: b, control1: c1, control2: c2)
        }

        p.move(to: CGPoint(x: minX, y: minY))                              // top-left, on the edge
        // Concave shoulder (top-left): scoop from the top edge down to the wall.
        corner(from: CGPoint(x: minX, y: minY),
               toward: CGPoint(x: minX + tr, y: minY),
               to: CGPoint(x: minX + tr, y: minY + tr))
        p.addLine(to: CGPoint(x: minX + tr, y: maxY - br))                 // inset left wall
        corner(from: CGPoint(x: minX + tr, y: maxY - br),                  // bottom-left, convex
               toward: CGPoint(x: minX + tr, y: maxY),
               to: CGPoint(x: minX + tr + br, y: maxY))
        p.addLine(to: CGPoint(x: maxX - tr - br, y: maxY))                 // bottom edge
        corner(from: CGPoint(x: maxX - tr - br, y: maxY),                  // bottom-right, convex
               toward: CGPoint(x: maxX - tr, y: maxY),
               to: CGPoint(x: maxX - tr, y: maxY - br))
        p.addLine(to: CGPoint(x: maxX - tr, y: minY + tr))                 // inset right wall
        corner(from: CGPoint(x: maxX - tr, y: minY + tr),                  // concave shoulder, top-right
               toward: CGPoint(x: maxX - tr, y: minY),
               to: CGPoint(x: maxX, y: minY))
        p.addLine(to: CGPoint(x: minX, y: minY))                           // full-bleed top edge
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

    /// Passive pointer movement may retract only a pristine input. Drafts,
    /// results, and recovery controls stay put until an explicit ESC, hotkey,
    /// or click-away. Otherwise a slow local answer can finish off-pointer and
    /// disappear before the user ever sees it.
    public static func shouldAutoCollapse(phase: NotchPhase,
                                          hasDraft: Bool,
                                          isListening: Bool,
                                          isQuerying: Bool) -> Bool {
        phase == .input && !hasDraft && !isListening && !isQuerying
    }

    /// Losing key status is an explicit click-away only after interactive work
    /// has stopped. The first streamed token changes the phase to `.answering`,
    /// so phase alone cannot distinguish a completed answer from a live one.
    public static func shouldCollapseOnResignKey(phase: NotchPhase,
                                                  isListening: Bool,
                                                  isQuerying: Bool) -> Bool {
        phase != .idle && phase != .searching && !isListening && !isQuerying
    }
}

/// The resident panel is much larger than the visible idle collar. Keep that
/// transparent area out of AppKit's event path until the surface is actually
/// expanded or listening.
public enum NotchPanelInteraction {
    public static func acceptsEvents(phase: NotchPhase,
                                     isListening: Bool,
                                     showsOnboarding: Bool) -> Bool {
        phase != .idle || isListening || showsOnboarding
    }

    /// The SwiftUI surface is top-centered inside a resident maximum-size
    /// panel. Only that visible rectangle should participate in AppKit mouse
    /// routing; the rest must behave like ordinary desktop space.
    public static func surfaceRect(panelFrame: CGRect, surfaceSize: CGSize) -> CGRect {
        let width = max(0, min(surfaceSize.width, panelFrame.width))
        let height = max(0, min(surfaceSize.height, panelFrame.height))
        return CGRect(
            x: panelFrame.midX - width / 2,
            y: panelFrame.maxY - height,
            width: width,
            height: height
        )
    }

    public static func capturesMouse(allowsInteraction: Bool,
                                     pointer: CGPoint,
                                     panelFrame: CGRect,
                                     surfaceSize: CGSize) -> Bool {
        allowsInteraction && surfaceRect(panelFrame: panelFrame, surfaceSize: surfaceSize)
            .contains(pointer)
    }
}

/// Pure hit geometry for the collar's voice control. The expanded body is
/// deliberately excluded so text fields, source chips, and recovery buttons
/// never double as dictation triggers.
public enum NotchInteraction {
    public static func voiceTargetRect(surfaceWidth: CGFloat, notchSize: CGSize) -> CGRect {
        let width = max(0, min(notchSize.width, surfaceWidth))
        let height = max(0, notchSize.height)
        return CGRect(x: (surfaceWidth - width) / 2, y: 0, width: width, height: height)
    }

    /// Cancelling abandons partial output but keeps the original query ready to
    /// edit or retry. Completed conversation turns remain available for recall.
    public static func cancelledState(_ current: NotchState) -> NotchState {
        var next = current
        next.phase = .input
        next.answer = ""
        next.sources = []
        next.terminal = nil
        next.unsupportedSentences = []
        next.status = ""
        next.understanding = ""
        next.suggestions = []
        next.related = []
        next.entities = []
        next.reasoning = []
        next.feedback = nil
        return next
    }

    /// Maximum label width for an equal-budget citation row. Padding and gaps
    /// are accounted for so the last chip never lands under the surface clip.
    public static func sourceChipTextWidth(surfaceWidth: CGFloat,
                                           contentPadding: CGFloat,
                                           chipPadding: CGFloat,
                                           spacing: CGFloat,
                                           chipCount: Int) -> CGFloat {
        guard chipCount > 0 else { return 0 }
        let gaps = spacing * CGFloat(max(0, chipCount - 1))
        let contentWidth = max(0, surfaceWidth - 2 * contentPadding - gaps)
        return max(0, contentWidth / CGFloat(chipCount) - 2 * chipPadding)
    }
}
