// Agent-B audit B-006
// Agent-B audit B-024
import SwiftUI
import MnemoOrchestrator

/// The surface outline (UI.md §3): a full-bleed top edge with concave
/// "shoulders" flaring the inset walls out to the screen top (the MacBook-notch
/// look), plus convex rounded bottom corners — the notch grown wider.
/// Delegates to the pure, hermetically tested `NotchShapeGeometry`.
struct NotchShape: Shape, @unchecked Sendable {
    var topCornerRadius: CGFloat = Surface.shoulderRadius
    var bottomCornerRadius: CGFloat = Surface.bottomRadius

    // Both radii ride the same spring that grows the surface.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        Path(NotchShapeGeometry.path(in: rect,
                                     topCornerRadius: topCornerRadius,
                                     bottomCornerRadius: bottomCornerRadius))
    }
}
