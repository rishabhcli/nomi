import CoreGraphics
import Foundation

/// Pure material math for the black-to-Liquid-Glass seep. The top body is a
/// fixed opaque black layer; only the bottom fraction fades away to reveal the
/// real system glass behind it. Window focus never participates in this math.
public struct SurfaceMaterialGeometry: Equatable, Sendable {
    public static let defaultGlassFraction = ProductDocContract.glassFraction

    public let totalHeight: CGFloat
    public let glassFraction: CGFloat
    public let glassHeight: CGFloat
    /// Normalized y position where opaque black begins fading into glass.
    public let fadeStart: CGFloat

    public init(
        totalHeight rawHeight: CGFloat,
        glassFraction rawFraction: CGFloat = Self.defaultGlassFraction
    ) {
        let height = rawHeight.isFinite ? max(0, rawHeight) : 0
        let fraction = rawFraction.isFinite ? min(1, max(0, rawFraction)) : 0
        totalHeight = height
        glassFraction = fraction
        glassHeight = height * fraction
        fadeStart = 1 - fraction
    }

    /// Opacity of the fixed-black body at a normalized top-to-bottom position.
    /// `windowIsKey` is intentionally ignored: losing focus must not gray or
    /// fade the notch body.
    public func blackBodyOpacity(at normalizedY: CGFloat, windowIsKey: Bool) -> CGFloat {
        _ = windowIsKey
        let y = min(1, max(0, normalizedY.isFinite ? normalizedY : 0))
        guard glassFraction > 0, y > fadeStart else { return 1 }
        return max(0, (1 - y) / glassFraction)
    }
}

/// Keeps view composition driven by the reducer phase instead of parallel local
/// flags. In particular, `.searching` always owns a visible activity-trace body.
public enum SurfaceBodyKind: Equatable, Sendable {
    case none
    case activityTrace
    case answer
    case voiceOrb
}

public enum SurfaceBodyPolicy {
    public static func kind(phase: NotchPhase, listening: Bool) -> SurfaceBodyKind {
        if listening { return .voiceOrb }
        switch phase {
        case .searching: return .activityTrace
        case .answering, .state: return .answer
        case .idle, .input: return .none
        }
    }
}

/// Coalesces token-by-token text reflow into stable layout steps. The panel can
/// grow with an answer without restarting its notch morph spring on every token.
public enum SurfaceAnswerLayout {
    public static let heightStep: CGFloat = 24

    public static func quantizedHeight(_ rawHeight: CGFloat, cap: CGFloat) -> CGFloat {
        guard rawHeight.isFinite, cap.isFinite, cap > 0 else { return 0 }
        let height = min(max(0, rawHeight), cap)
        guard height > 0 else { return 0 }
        return min(cap, ceil(height / heightStep) * heightStep)
    }
}

/// Physics policy for the handle's hold-and-swipe-up dismissal. Views own the
/// gesture lifecycle; this helper owns the deterministic distance/velocity
/// decision and the interactive rubber band.
public enum SurfaceDismissGesture {
    public static let holdDuration: Double = 0.18
    public static let progressDistance: CGFloat = 96
    public static let distanceThreshold: CGFloat = 72
    public static let minimumFlickDistance: CGFloat = 20
    public static let upwardVelocityThreshold: CGFloat = -650
    public static let predictionDuration: CGFloat = 0.20
    public static let maximumDownwardRubberBand: CGFloat = 18

    /// Upward motion follows the pointer exactly. Downward motion is resisted so
    /// the top-anchored surface never drifts far away from the hardware notch.
    public static func interactiveOffset(translationY rawTranslation: CGFloat) -> CGFloat {
        guard rawTranslation.isFinite else { return 0 }
        if rawTranslation <= 0 { return rawTranslation }
        let response = 1 - exp(-rawTranslation / 24)
        return maximumDownwardRubberBand * response
    }

    public static func progress(translationY: CGFloat) -> CGFloat {
        guard progressDistance > 0 else { return 1 }
        return min(1, max(0, -interactiveOffset(translationY: translationY) / progressDistance))
    }

    /// SwiftUI supplies a predicted end translation. Converting its projected
    /// delta to points/second keeps the commit policy testable without depending
    /// on a particular gesture API's velocity type.
    public static func estimatedVelocityY(
        translationY: CGFloat,
        predictedEndTranslationY: CGFloat
    ) -> CGFloat {
        guard translationY.isFinite, predictedEndTranslationY.isFinite,
              predictionDuration > 0 else { return 0 }
        return (predictedEndTranslationY - translationY) / predictionDuration
    }

    public static func shouldDismiss(translationY: CGFloat, velocityY: CGFloat) -> Bool {
        let upwardDistance = max(0, -translationY)
        if upwardDistance >= distanceThreshold { return true }
        return upwardDistance >= minimumFlickDistance && velocityY <= upwardVelocityThreshold
    }
}
