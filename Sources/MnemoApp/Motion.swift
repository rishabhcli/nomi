import SwiftUI
import MnemoOrchestrator

/// Centralized motion tokens (UI.md §7/§13) — springs measured from the
/// reference recordings. No scattered magic numbers.
enum Motion {
    static let summon   = Animation.spring(response: 0.36, dampingFraction: 0.84) // idle → expanded
    static let grow     = Animation.spring(response: 0.32, dampingFraction: 0.88) // phase morphs + streaming growth
    static let collapse = Animation.spring(response: 0.30, dampingFraction: 0.90) // retract into notch, zero bounce
    static let glyph    = Animation.spring(response: 0.25, dampingFraction: 0.80) // mic ↔ send morph
    static let dissolve = Animation.easeInOut(duration: 0.20)                     // status cross-fade
    static let reveal   = Animation.easeOut(duration: 0.22)                       // block fade
    static let stagger  = 0.06

    /// Reduce Motion fallback: a plain cross-fade, no spring/blur/scale.
    static func adaptive(_ base: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.20) : base
    }

    /// Width and height changes are spatial motion, not a cross-fade. Disable
    /// that animation entirely when Reduce Motion is enabled; content swaps
    /// still use the opacity-only transition below.
    static func geometry(_ base: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : base
    }

    /// The signature blur-morph (UI.md §6): incoming content arrives blurred
    /// 8→0 from scale 1.025, outgoing leaves blurring 0→9 and shrinking to
    /// 0.975. The blur masks the content pop so swaps read as a soft dissolve
    /// rather than a hard cut. Reduce Motion → a plain opacity cross-fade.
    static func blurMorph(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: BlurMorph(blur: 8, scale: 1.025, opacity: 0),
                                 identity: BlurMorph(blur: 0, scale: 1, opacity: 1)),
            removal: .modifier(active: BlurMorph(blur: 9, scale: 0.975, opacity: 0),
                               identity: BlurMorph(blur: 0, scale: 1, opacity: 1)))
    }
}

/// Explicit opacity+blur+scale modifier for the blur-morph transition.
struct BlurMorph: ViewModifier {
    let blur: CGFloat
    let scale: CGFloat
    let opacity: Double
    func body(content: Content) -> some View {
        content.blur(radius: blur).scaleEffect(scale).opacity(opacity)
    }
}

/// Surface dimensions & materials (UI.md §3/§8), matched to the reference
/// screenshots in Tests/Fixtures/reference. The surface is ONE cohesive object:
/// a pure-black body (blends with the hardware notch) with a translucent
/// Liquid-Glass tray curving around the bottom — never separate floating pieces.
enum Surface {
    // Expanded states share ONE width so input↔searching↔answer morph is a pure
    // vertical grow (never a sideways jump) — the premium reference feel.
    static let inputWidth: CGFloat = 520          // hover-open width
    static let readWidth: CGFloat = 520           // answering width
    static let bandHeight: CGFloat = 60           // controls row height inside the tray
    static let bandFade: CGFloat = 34             // empty zone above controls (glass fade rises behind it)
    static let trayHandle: CGFloat = 20           // home-indicator zone below the controls
    /// Full glass tray = blend + controls + handle. The desktop shows through it.
    static var trayHeight: CGFloat { bandFade + bandHeight + trayHandle }
    static let searchingBodyHeight: CGFloat = 170 // live activity trace above the tray
    // Keeps all ordinary onboarding content above the bottom glass transition;
    // only glass-styled actions and the home indicator live inside that layer.
    static let starterProfileBodyHeight: CGFloat = 420
    /// Liquid Glass rises through exactly the bottom fraction of every expanded
    /// surface, melting into the opaque black body (UI.md §3).
    static let glassFraction = SurfaceMaterialGeometry.defaultGlassFraction
    static let answerCap: CGFloat = 400           // answer zone scrolls beyond this
    static let answerFont: CGFloat = 17           // reference: large clean white text
    static let bottomRadius: CGFloat = 46         // expanded bottom corners (convex)
    static let idleRadius: CGFloat = 9            // hardware-like idle rounding
    // Concave "shoulders": the top corners flare the inset walls out to the
    // full-bleed top edge — the MacBook-notch silhouette (UI.md §3). The top
    // edge stays flush; only the walls inset by this radius.
    static let shoulderRadius: CGFloat = 12       // expanded concave shoulder
    static let idleShoulder: CGFloat = 5          // subtle shoulder while collapsed
    static let maxBodyHeight: CGFloat = 560       // panel sizing bound
    // The listening "drop": a narrow pendant that grows straight DOWN from the
    // notch (never widening it), rounded into a semicircle bottom, orb inside.
    static let dropWidth: CGFloat = 176
    static let dropBody: CGFloat = 188            // body length below the notch
    static let orbDiameter: CGFloat = 132         // listening-orb sphere diameter
    // Home-indicator pill at the tray bottom (reference detail).
    static let homeIndicatorW: CGFloat = 40
    static let homeIndicatorH: CGFloat = 5
    // Glass tray tint: dark, so the tray reads as premium black-glass — opaque
    // enough that a busy desktop behind it doesn't bleed through as clutter,
    // while still translucent (real Liquid Glass, samples the desktop).
    static let trayTint = 0.74
    static let shadowBleed: CGFloat = 60          // panel margin for the shadow
    static let shadowRadius: CGFloat = 32
    static let shadowY: CGFloat = 11
    static let shadowOpacity = 0.36
    static let spinnerRing: CGFloat = 18
    static let spinnerDot: CGFloat = 2.5
    static let spinnerRPS = 1.0
}
