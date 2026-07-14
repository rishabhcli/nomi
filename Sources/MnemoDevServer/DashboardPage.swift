import Foundation

/// Loads the self-contained dashboard HTML (shipped as a bundle resource). The
/// server substitutes the `__MNEMO_TOKEN__` placeholder with the session token
/// at serve time. The page has NO external assets — it renders with the network
/// off, like everything else in Mnemo.
public enum DashboardPage {
    public static func html() -> String {
        if let url = Bundle.module.url(forResource: "dashboard", withExtension: "html"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return contents
        }
        return fallback
    }

    static let fallback = """
    <!DOCTYPE html><html><head><meta charset="utf-8"><title>Mnemo Observatory</title></head>
    <body style="background:#0a0d13;color:#e6edf6;font-family:system-ui;padding:40px">
    <h2>Mnemo · Observatory</h2>
    <p>The dashboard.html resource is missing from the bundle. Token: __MNEMO_TOKEN__</p>
    </body></html>
    """
}
