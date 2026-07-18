import Foundation

private final class DashboardBundleMarker {}

/// Loads the self-contained dashboard HTML (shipped as a bundle resource). The
/// server substitutes the `__MNEMO_TOKEN__` placeholder with the session token
/// at serve time. The page has NO external assets — it renders with the network
/// off, like everything else in Mnemo.
public enum DashboardPage {
    public static func html() -> String {
        html(resourceBundles: resourceBundles())
    }

    static func html(resourceBundles: [Bundle]) -> String {
        for bundle in resourceBundles {
            guard let url = bundle.url(forResource: "dashboard", withExtension: "html"),
                  let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            return contents
        }
        return fallback
    }

    /// `Bundle.module` traps when a SwiftPM resource bundle is omitted from a
    /// packaged app, which would turn optional developer observability into a
    /// launch crash. Resolve the bundle defensively so the local fallback stays
    /// reachable even when packaging is incomplete.
    private static func resourceBundles() -> [Bundle] {
        let bundleName = "Mnemo_MnemoDevServer.bundle"
        let main = Bundle.main
        let roots = [
            main.resourceURL,
            Bundle(for: DashboardBundleMarker.self).resourceURL,
            main.bundleURL,
            main.bundleURL.deletingLastPathComponent(),
        ].compactMap { $0 }

        return roots.compactMap { Bundle(url: $0.appendingPathComponent(bundleName)) }
    }

    static let fallback = """
    <!DOCTYPE html><html><head><meta charset="utf-8"><title>Mnemo Observatory</title></head>
    <body style="background:#0a0d13;color:#e6edf6;font-family:system-ui;padding:40px">
    <h2>Mnemo · Observatory</h2>
    <p>The dashboard.html resource is missing from the bundle. Token: __MNEMO_TOKEN__</p>
    </body></html>
    """
}
