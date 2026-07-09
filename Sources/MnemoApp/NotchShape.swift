// Agent-B audit B-006
import SwiftUI
import MnemoOrchestrator

/// The surface outline (UI.md §3): square full-bleed top corners flush with
/// the screen top, rounded bottom corners only — the notch grown larger.
/// Delegates to the pure, hermetically tested `NotchShapeGeometry`.
struct NotchShape: Shape, @unchecked Sendable {
    var bottomCornerRadius: CGFloat = Surface.bottomRadius

    // The bottom radius rides the same spring that grows the surface.
    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(NotchShapeGeometry.path(in: rect, bottomCornerRadius: bottomCornerRadius))
    }
}
