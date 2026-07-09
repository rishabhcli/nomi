import Foundation

/// Parses Ollama's `/api/tags` response — the local model inventory.
/// M0 uses this to fail loudly when the configured model is missing,
/// instead of silently downloading at query time.
public enum OllamaTags {
    struct Response: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    public static func models(in data: Data) throws -> [String] {
        try JSONDecoder().decode(Response.self, from: data).models.map(\.name)
    }
}
