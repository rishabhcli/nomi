import Foundation

/// Builds the warm-up generation request that makes the model weights resident.
/// Sent once at bring-up so a cold weight-load never falls on a user query;
/// `keep_alive` (from config) keeps the model pinned between queries.
public enum OllamaWarmup {
    public static func requestBody(model: String, keepAlive: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "prompt": "warm up",
            "stream": false,
            "keep_alive": keepAlive,
            "options": ["num_predict": 1],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }
}
