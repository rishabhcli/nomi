import XCTest
@testable import MnemoOrchestrator

final class MicEnvelopeTests: XCTestCase {
    func testRMSToNormalizedAmplitude() {
        // Silence → ~0; loud → ~1; monotonic in between.
        let env = MicEnvelope()
        let quiet = env.normalize(rms: 0.0001)
        let mid = env.normalize(rms: 0.05)
        let loud = env.normalize(rms: 0.5)
        XCTAssertLessThan(quiet, 0.1)
        XCTAssertGreaterThan(loud, 0.8)
        XCTAssertLessThan(quiet, mid)
        XCTAssertLessThan(mid, loud)
    }

    func testEnvelopeFollowerFastAttackSlowRelease() {
        var env = MicEnvelope()
        // A spike rises fast…
        let rising = env.follow(target: 1.0)
        XCTAssertGreaterThan(rising, 0.3, "fast attack tracks a spike quickly")
        // …then silence decays slowly (still elevated after one step).
        let releasing = env.follow(target: 0.0)
        XCTAssertGreaterThan(releasing, 0.05, "slow release: doesn't snap to zero")
        XCTAssertLessThan(releasing, rising)
    }

    func testMapsToOrbUniforms() {
        // AT-M12.10: wave height + brightness + saturation rise with amplitude,
        // capped so the bright band never hides behind the notch (maxFill).
        let low = OrbUniforms(amplitude: 0.05)
        let high = OrbUniforms(amplitude: 0.95)
        XCTAssertLessThan(low.waveHeight, high.waveHeight)
        XCTAssertLessThan(low.brightness, high.brightness)
        XCTAssertLessThan(low.saturation, high.saturation)
        XCTAssertLessThanOrEqual(high.waveHeight, OrbUniforms.maxFill)
        XCTAssertGreaterThan(low.waveHeight, 0, "idle flow: never dead-static")
        XCTAssertLessThanOrEqual(high.scale, 1.06 + 0.001)
    }
}

/// The render-side smoother that turns the ~12–45 Hz mic envelope into a fluid,
/// display-rate signal for the orb (UI.md §12.2). It must be frame-rate
/// independent, ease fast on the way up and slow on the way down, and never
/// overshoot.
final class AmplitudeSmootherTests: XCTestCase {
    func testConvergesTowardTargetOverTime() {
        var s = AmplitudeSmoother()
        for _ in 0..<200 { _ = s.advance(toward: 1.0, dt: 1.0 / 120.0) }
        XCTAssertEqual(s.current, 1.0, accuracy: 0.01, "reaches the target given time")
    }

    func testFrameRateIndependence() {
        // The whole point: the eased value after a fixed wall-clock interval is
        // the same whether we tick once at 0.1s or ten times at 0.01s. This is
        // what kills the ~12 Hz staircase without coupling to frame rate.
        var coarse = AmplitudeSmoother()
        _ = coarse.advance(toward: 1.0, dt: 0.1)
        var fine = AmplitudeSmoother()
        for _ in 0..<10 { _ = fine.advance(toward: 1.0, dt: 0.01) }
        XCTAssertEqual(coarse.current, fine.current, accuracy: 1e-9)
    }

    func testAttackIsFasterThanRelease() {
        // Same dt: rising from 0→1 covers more ground than falling 1→0.
        var up = AmplitudeSmoother()
        let rose = up.advance(toward: 1.0, dt: 0.05)      // distance moved up
        var down = AmplitudeSmoother(current: 1.0)
        let fell = 1.0 - down.advance(toward: 0.0, dt: 0.05)  // distance moved down
        XCTAssertGreaterThan(rose, fell, "fast attack, slow release")
    }

    func testZeroDtHolds() {
        var s = AmplitudeSmoother(current: 0.4)
        XCTAssertEqual(s.advance(toward: 1.0, dt: 0), 0.4, "no time elapsed → no change")
    }

    func testNeverOvershoots() {
        var s = AmplitudeSmoother()
        for _ in 0..<500 { _ = s.advance(toward: 1.0, dt: 1.0) }  // huge steps
        XCTAssertLessThanOrEqual(s.current, 1.0, "one-pole easing cannot overshoot")
    }
}

final class OrbAnimationEpochTests: XCTestCase {
    func testElapsedTimeUsesOneStableEpoch() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let epoch = OrbAnimationEpoch(start: start)

        XCTAssertEqual(epoch.elapsed(at: start.addingTimeInterval(0.25)), 0.25, accuracy: 0.0001)
        XCTAssertEqual(epoch.elapsed(at: start.addingTimeInterval(1.5)), 1.5, accuracy: 0.0001)
        XCTAssertEqual(epoch.elapsed(at: start.addingTimeInterval(-1)), 0)
    }
}
