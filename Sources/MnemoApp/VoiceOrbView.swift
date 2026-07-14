// Agent-B audit B-010
// Agent-B audit B-028
import SwiftUI
import MnemoOrchestrator

/// The listening orb (UI.md §12): a GPU Metal-shader glass sphere whose
/// meniscus wave tracks the mic envelope — louder → bigger, brighter, more
/// saturated. `TimelineView(.animation)` drives a continuous `time` uniform at
/// the display refresh (120fps ProMotion); the CPU only updates uniforms.
struct VoiceOrbView: View {
    /// Smoothed 0…1 amplitude from the mic envelope.
    var amplitude: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let diameter = Surface.orbDiameter
    private let start = Date()
    // Per-frame smoothing state in a reference holder so the TimelineView
    // view-builder can integrate dt each frame without mutating SwiftUI @State
    // value storage during the update pass.
    @State private var clock = OrbClock()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            // Ease the coarse (~12–45 Hz) mic envelope onto a display-rate value
            // so the wave/brightness/scale never staircase (UI.md §12.2).
            let amp = clock.tick(now: timeline.date, target: amplitude)
            let uniforms = OrbUniforms(amplitude: amp)
            // Idle breathing keeps the sphere alive at silence (§12.2.4).
            let breathe = reduceMotion ? 0 : 0.008 * sin(t * 1.3)
            Circle()
                .fill(.black)
                .frame(width: Self.diameter, height: Self.diameter)
                .modifier(OrbShaderModifier(time: t, uniforms: uniforms,
                                            reduceMotion: reduceMotion, diameter: Self.diameter))
                .scaleEffect(uniforms.scale + breathe)
                .shadow(color: .black.opacity(0.45), radius: 16, y: 7)   // contact shadow
                .accessibilityLabel("Listening")
                .accessibilityValue("Input level \(Int(amp * 100)) percent")
        }
    }
}

/// Integrates the render-frame `dt` to smooth the amplitude. A reference type so
/// the TimelineView view-builder can update it each frame without SwiftUI's
/// "modifying state during view update" trap. Big gaps (first frame, occlusion)
/// are clamped so the orb never lurches.
private final class OrbClock {
    private var smoother = AmplitudeSmoother()
    private var last: Date?
    func tick(now: Date, target: Double) -> Double {
        guard let previous = last else {
            // First frame: start AT the observed level, so the orb doesn't lurch
            // up from zero on appear (and a single offscreen frame renders true).
            last = now
            smoother.current = target
            return target
        }
        last = now
        return smoother.advance(toward: target, dt: min(now.timeIntervalSince(previous), 0.1))
    }
}

/// Applies the Metal color effect, with a Reduce-Motion fallback that is a
/// calm amplitude pulse (opacity/scale only — no wave/hue/aberration, §12.6).
private struct OrbShaderModifier: ViewModifier {
    let time: Double
    let uniforms: OrbUniforms
    let reduceMotion: Bool
    let diameter: CGFloat

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .overlay(Circle().fill(.white.opacity(0.15 + uniforms.amplitude * 0.5)))
        } else {
            // The band height / brightness / saturation come from OrbUniforms —
            // the single, unit-tested source of truth (AT-M12.10) — so the
            // shader no longer re-derives its own divergent mapping.
            content.colorEffect(
                ShaderLibrary.bundle(.module).voiceOrb(
                    .float2(Float(diameter), Float(diameter)),
                    .float(time),
                    .float(uniforms.amplitude),
                    .float(uniforms.waveHeight),
                    .float(uniforms.brightness),
                    .float(uniforms.saturation)))
        }
    }
}
