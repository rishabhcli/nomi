import Foundation

/// Stable time origin for the continuously animated orb shader. A SwiftUI view
/// may be recreated whenever mic amplitude changes; keeping this value in
/// `@State` prevents those updates from resetting the shader's phase.
public struct OrbAnimationEpoch: Equatable, Sendable {
    private let startReferenceTime: TimeInterval

    public init(start: Date = Date()) {
        startReferenceTime = start.timeIntervalSinceReferenceDate
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSinceReferenceDate - startReferenceTime)
    }
}

/// Mic-amplitude envelope for the listening orb (UI.md §12.2): RMS → dB →
/// normalized 0…1, then a fast-attack / slow-release follower so the wave is
/// responsive but never strobes. Pure math — the audio tap feeds it.
public struct MicEnvelope {
    public var current: Double = 0
    let attack: Double   // 0…1 per step (fast)
    let release: Double  // 0…1 per step (slow)

    public init(attack: Double = 0.6, release: Double = 0.12) {
        self.attack = attack
        self.release = release
    }

    /// Map RMS (0…~1) onto a perceptual 0…1 via a dB curve.
    public func normalize(rms: Double) -> Double {
        let clamped = max(rms, 1e-6)
        let db = 20 * log10(clamped)          // ~ -120 (silence) … 0 (full)
        let norm = (db + 60) / 60             // -60dB floor → 0, 0dB → 1
        return min(max(norm, 0), 1)
    }

    /// Advance the envelope toward a target with asymmetric attack/release.
    public mutating func follow(target: Double) -> Double {
        let rate = target > current ? attack : release
        current += (target - current) * rate
        return current
    }
}

/// Render-side smoother that turns the coarse mic envelope (updated only
/// ~12–45×/s by the audio tap) into a fluid, display-rate signal for the orb
/// (UI.md §12.2). Unlike `MicEnvelope.follow` — whose per-step rate silently
/// depends on the audio buffer size — this eases with an exponential coefficient
/// derived from the real frame `dt`, so the smoothing is **frame-rate
/// independent**: nothing staircases at the buffer rate. Fast attack, slow
/// release, and — being a one-pole — it can never overshoot.
public struct AmplitudeSmoother {
    public var current: Double
    let attack: Double   // seconds — time constant while rising
    let release: Double  // seconds — time constant while falling

    public init(current: Double = 0, attack: Double = 0.06, release: Double = 0.18) {
        self.current = current
        self.attack = attack
        self.release = release
    }

    /// Ease toward `target` over the elapsed `dt` seconds. `k = 1 - e^(-dt/τ)`
    /// is exact for exponential decay, so splitting a step into N sub-steps
    /// yields the same result (the property `testFrameRateIndependence` pins).
    public mutating func advance(toward target: Double, dt: Double) -> Double {
        guard dt > 0 else { return current }
        let tau = target >= current ? attack : release
        let k = tau > 0 ? 1 - exp(-dt / tau) : 1
        current += (target - current) * k
        return current
    }
}

/// Per-frame shader uniforms derived from the smoothed amplitude (UI.md §12.4).
/// The only thing that changes per frame; everything else is on the GPU.
public struct OrbUniforms: Equatable, Sendable {
    public static let maxFill = 0.80   // wave-height cap (keep bright band below the notch)
    public static let idleFlow = 0.06  // baseline motion at silence

    public let amplitude: Double
    public let waveHeight: Double
    public let brightness: Double
    public let saturation: Double
    public let scale: Double

    public init(amplitude a: Double) {
        let amp = min(max(a, 0), 1)
        amplitude = amp
        waveHeight = Self.idleFlow + amp * (Self.maxFill - Self.idleFlow)
        brightness = 0.25 + amp * 0.75      // dim → near-white-hot
        saturation = 0.15 + amp * 0.85      // near-gray → full spectrum
        scale = 1.0 + amp * 0.05            // subtle swell (UI.md §12.2: ≤ ~5%)
    }

    /// Reduced Motion keeps the listening target physically stable while the
    /// brightness overlay still communicates live microphone activity.
    public func displayScale(reduceMotion: Bool) -> Double {
        reduceMotion ? 1 : scale
    }
}
