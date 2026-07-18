import XCTest
@testable import MnemoDevServer

/// The dashboard must render with the network OFF — the same invariant as the
/// rest of Mnemo. These tests fail the build if any external asset creeps in.
final class DashboardPageTests: XCTestCase {

    func testPageLoadsFromBundleWithTokenPlaceholder() {
        let html = DashboardPage.html()
        XCTAssertTrue(html.contains("__MNEMO_TOKEN__"), "server substitutes the token at serve time")
        XCTAssertGreaterThan(html.count, 2000, "should be the real dashboard, not the fallback")
        XCTAssertTrue(html.contains("EventSource"), "dashboard subscribes to the SSE feed")
    }

    func testPageHasNoExternalURLs() {
        let html = DashboardPage.html()
        XCTAssertFalse(html.contains("http://"), "no external http URLs allowed (offline / zero-egress invariant)")
        XCTAssertFalse(html.contains("https://"), "no external https URLs allowed (offline / zero-egress invariant)")
        XCTAssertFalse(html.contains("//cdn"), "no CDN references allowed")
        XCTAssertFalse(html.lowercased().contains("<script src"), "no external scripts — all JS is inline")
    }

    func testMissingResourceBundleFallsBackWithoutCrashing() {
        let html = DashboardPage.html(resourceBundles: [])

        XCTAssertTrue(html.contains("resource is missing"))
        XCTAssertTrue(html.contains("__MNEMO_TOKEN__"))
        XCTAssertFalse(html.contains("http://"))
        XCTAssertFalse(html.contains("https://"))
    }
}
