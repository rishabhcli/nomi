// Agent-B audit B-010
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

    private static let diameter: CGFloat = 132
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let uniforms = OrbUniforms(amplitude: amplitude)
            // Idle breathing keeps the sphere alive at silence (§12.2.4).
            let breathe = reduceMotion ? 0 : 0.008 * sin(t * 1.3)
            Circle()
                .fill(.black)
                .frame(width: Self.diameter, height: Self.diameter)
                .modifier(OrbShaderModifier(time: t, amplitude: amplitude,
                                            reduceMotion: reduceMotion, diameter: Self.diameter))
                .scaleEffect(uniforms.scale + breathe)
                .shadow(color: .black.opacity(0.45), radius: 16, y: 7)   // contact shadow
                .accessibilityLabel("Listening")
                .accessibilityValue("Input level \(Int(amplitude * 100)) percent")
        }
    }
}

/// Applies the Metal color effect, with a Reduce-Motion fallback that is a
/// calm amplitude pulse (opacity/scale only — no wave/hue/aberration, §12.6).
private struct OrbShaderModifier: ViewModifier {
    let time: Double
    let amplitude: Double
    let reduceMotion: Bool
    let diameter: CGFloat

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .overlay(Circle().fill(.white.opacity(0.15 + amplitude * 0.5)))
        } else {
            content.colorEffect(
                ShaderLibrary.bundle(.module).voiceOrb(
                    .float2(Float(diameter), Float(diameter)),
                    .float(time),
                    .float(amplitude),
                    .float(0)))
        }
    }
}
