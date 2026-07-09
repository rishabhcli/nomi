import SwiftUI

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

    /// The signature blur-morph (UI.md §6): outgoing blurs 0→10 and shrinks to
    /// 0.97; incoming arrives blurred 8→0 from 1.03. Reduce Motion → opacity.
    static func blurMorph(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: BlurMorph(blur: 8, scale: 1.03, opacity: 0),
                                 identity: BlurMorph(blur: 0, scale: 1, opacity: 1)),
            removal: .modifier(active: BlurMorph(blur: 10, scale: 0.97, opacity: 0),
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
/// screenshots in assets/IMG_1149 + IMG_1150.
enum Surface {
    static let inputWidth: CGFloat = 440          // hover-open width
    static let readWidth: CGFloat = 520           // answering width
    static let bandHeight: CGFloat = 64           // glass input band
    static let bandFade: CGFloat = 26             // black → glass gradient bridge
    static let orbZoneHeight: CGFloat = 168       // black zone while dictating
    static let answerCap: CGFloat = 400           // answer zone scrolls beyond this
    static let answerFont: CGFloat = 16           // reference: large clean white text
    static let bottomRadius: CGFloat = 34         // expanded bottom corners (top = 0, square)
    static let idleRadius: CGFloat = 8            // hardware-like idle rounding
    static let maxBodyHeight: CGFloat = 560       // panel sizing bound
    static let shadowBleed: CGFloat = 60          // panel margin for the shadow
    static let shadowRadius: CGFloat = 30
    static let shadowY: CGFloat = 9
    static let shadowOpacity = 0.30
    static let spinnerRing: CGFloat = 18
    static let spinnerDot: CGFloat = 2.5
    static let spinnerRPS = 1.0
}
