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
