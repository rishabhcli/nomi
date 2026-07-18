import Foundation
import MnemoCore

public struct ProcessIdentity: Equatable, Sendable {
    public let executablePath: String
    public let commandLine: String
    public let environmentDescription: String
    public let arguments: [String]
    public let environmentEntries: [String]

    public init(
        executablePath: String,
        commandLine: String,
        environmentDescription: String,
        arguments: [String]? = nil,
        environmentEntries: [String]? = nil
    ) {
        self.executablePath = executablePath
        self.commandLine = commandLine
        self.environmentDescription = environmentDescription
        self.arguments = arguments ?? commandLine.split(separator: " ").map(String.init)
        self.environmentEntries = environmentEntries
            ?? environmentDescription.split(separator: " ").map(String.init)
    }
}

public enum ListenerDisposition: Equatable, Sendable {
    case vacant
    case reusable(ListeningSocket)
    case replaceableManaged(pids: Set<Int>)
    case occupied([ListeningSocket])
}

public enum SMFSMountOwnership: Equatable, Sendable {
    case absent
    case managed
    case foreign
}

/// Runtime enforcement for the self-hosted engine. The binary contains optional
/// cloud extractors, so local provider configuration alone is not a sufficient
/// egress boundary.
public enum EngineLaunchPolicy {
    public static let markerKey = "MNEMO_STACK_SANDBOX_POLICY"
    public static let markerValue = "loopback-only-v1"
    public static let engineShutdownGracePeriodMs = 60_000

    public static let sandboxProfile = """
    (version 1)
    (allow default)
    (deny network-outbound)
    (deny network-inbound)
    (allow network-outbound (remote ip "localhost:*"))
    (allow network-inbound (local ip "localhost:*"))
    """

    private static let cloudEnvironmentMarkers = [
        "ANTHROPIC", "AWS_", "AZURE", "BEDROCK", "CLOUDFLARE", "COHERE",
        "FIREWORKS", "GEMINI", "GOOGLE_", "GROQ", "MISTRAL", "OPENROUTER",
        "PERPLEXITY", "PINECONE", "POSTHOG", "TOGETHER", "VERTEX", "VOYAGE",
        "XAI", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
    ]

    private static func sanitized(
        _ inherited: [String: String],
        markSandboxed: Bool = true
    ) -> [String: String] {
        var result = inherited.filter { key, _ in
            let upper = key.uppercased()
            return !cloudEnvironmentMarkers.contains { upper.contains($0) }
        }
        if markSandboxed { result[markerKey] = markerValue }
        return result
    }

    public static func environment(
        config: MnemoConfig,
        inherited: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> [String: String] {
        var result = sanitized(inherited)
        result["OPENAI_BASE_URL"] = config.model.runtimeBaseURL
            .appending(path: "v1").absoluteString
        result["OPENAI_API_KEY"] = "ollama-local"
        result["OPENAI_MODEL"] = config.model.synthesis
        result["SUPERMEMORY_DATA_DIR"] = homeDirectory + "/.supermemory/data"
        result["SUPERMEMORY_DISABLE_TELEMETRY"] = "1"
        result["SUPERMEMORY_EMBEDDING_PROVIDER"] = "local"
        result["SUPERMEMORY_EMBEDDING_RAM_LIMIT"] = "512mb"
        result["SUPERMEMORY_INGEST_CONCURRENCY"] = "1"
        result["SUPERMEMORY_LOCAL_EMBEDDING_POOL_SIZE"] = "1"
        result["SUPERMEMORY_LOCAL_EMBEDDING_IDLE_TIMEOUT_MS"] = "30000"
        result["BUN_GARBAGE_COLLECTOR_LEVEL"] = "1"
        result["SUPERMEMORY_NO_UPDATE_CHECK"] = "1"
        result["SUPERMEMORY_NO_OPEN"] = "1"
        result["SUPERMEMORY_NO_STARTUP_ANIMATION"] = "1"
        result["SUPERMEMORY_RUN_CRONS_AT_BOOT"] = "0"
        if let port = config.engine.baseURL.port {
            result["PORT"] = String(port)
            result["SUPERMEMORY_PORT"] = String(port)
        }
        return result
    }

    public static func ollamaEnvironment(
        config: MnemoConfig,
        inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var result = sanitized(inherited)
        let host = config.model.runtimeBaseURL.host ?? "127.0.0.1"
        let port = config.model.runtimeBaseURL.port ?? 11434
        result["OLLAMA_HOST"] = "\(host):\(port)"
        result["OLLAMA_NO_CLOUD"] = "1"
        result["OLLAMA_KEEP_ALIVE"] = config.model.keepAlive
        return result
    }

    public static func localProcessEnvironment(
        inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        sanitized(inherited, markSandboxed: false)
    }

    public static func canonicalExecutablePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    public static func hasExpectedExecutable(
        _ identity: ProcessIdentity,
        expectedExecutable: String
    ) -> Bool {
        canonicalExecutablePath(identity.executablePath)
            == canonicalExecutablePath(expectedExecutable)
    }

    public static func isManagedIdentity(
        _ identity: ProcessIdentity,
        expectedExecutable: String,
        requiredArguments: [String] = [],
        requireSandboxMarker: Bool = true
    ) -> Bool {
        guard hasExpectedExecutable(identity, expectedExecutable: expectedExecutable),
              hasRequiredArguments(requiredArguments, in: identity.arguments)
        else { return false }
        return !requireSandboxMarker
            || identity.environmentEntries.contains("\(markerKey)=\(markerValue)")
    }

    static func hasRequiredArguments(_ required: [String], in actual: [String]) -> Bool {
        var index = 0
        while index < required.count {
            let token = required[index]
            if token.hasPrefix("--"),
               index + 1 < required.count,
               !required[index + 1].hasPrefix("--") {
                let splitValues = actual.indices.compactMap { argumentIndex -> String? in
                    guard actual[argumentIndex] == token,
                          actual.indices.contains(argumentIndex + 1)
                    else { return nil }
                    return actual[argumentIndex + 1]
                }
                let equalsPrefix = token + "="
                let equalsValues = actual.compactMap { argument -> String? in
                    guard argument.hasPrefix(equalsPrefix) else { return nil }
                    return String(argument.dropFirst(equalsPrefix.count))
                }
                let values = splitValues + equalsValues
                guard values == [required[index + 1]]
                else { return false }
                index += 2
            } else {
                guard actual.contains(token) else { return false }
                index += 1
            }
        }
        return true
    }

    public static func smfsMountOwnership(
        mountTable: String,
        daemonList: String,
        mountPoint: String
    ) -> SMFSMountOwnership {
        let mountLines = mountTable.split(separator: "\n").map(String.init)
            .filter { $0.contains(" on \(mountPoint) ") }
        guard !mountLines.isEmpty else { return .absent }
        guard mountLines.count == 1,
              let separator = mountLines[0].range(of: " on \(mountPoint) "),
              ["127.0.0.1:/", "localhost:/", "[::1]:/"].contains(
                  String(mountLines[0][..<separator.lowerBound])
              ),
              mountLines[0].contains("(nfs")
        else { return .foreign }

        let registered = daemonList.split(separator: "\n").contains { line in
            let columns = line.split(separator: " ").map(String.init)
            return columns.first == "mnemo" && columns.last == mountPoint
        }
        return registered ? .managed : .foreign
    }

    public static func canReuse(
        _ listener: ListeningSocket,
        identity: ProcessIdentity,
        expectedExecutable: String,
        requiredArguments: [String] = [],
        requireSandboxMarker: Bool = true
    ) -> Bool {
        LoopbackAudit.isLoopbackAddress(listener.address)
            && isManagedIdentity(
                identity,
                expectedExecutable: expectedExecutable,
                requiredArguments: requiredArguments,
                requireSandboxMarker: requireSandboxMarker
            )
    }

    public static func listenerDisposition(
        _ listeners: [ListeningSocket],
        identities: [Int: ProcessIdentity],
        expectedExecutable: String,
        requiredArguments: [String] = [],
        requireSandboxMarker: Bool = true
    ) -> ListenerDisposition {
        guard !listeners.isEmpty else { return .vacant }

        let managed = managedPIDs(
            among: listeners,
            identities: identities,
            expectedExecutable: expectedExecutable,
            requiredArguments: requiredArguments,
            requireSandboxMarker: requireSandboxMarker
        )
        guard managed == Set(listeners.map(\.pid)) else { return .occupied(listeners) }

        if listeners.allSatisfy({ LoopbackAudit.isLoopbackAddress($0.address) }) {
            return .reusable(listeners[0])
        }
        return .replaceableManaged(pids: managed)
    }

    public static func managedPIDs(
        among listeners: [ListeningSocket],
        identities: [Int: ProcessIdentity],
        expectedExecutable: String,
        requiredArguments: [String] = [],
        requireSandboxMarker: Bool = true
    ) -> Set<Int> {
        Set(listeners.compactMap { listener in
            guard let identity = identities[listener.pid],
                  isManagedIdentity(
                      identity,
                      expectedExecutable: expectedExecutable,
                      requiredArguments: requiredArguments,
                      requireSandboxMarker: requireSandboxMarker
                  )
            else { return nil }
            return listener.pid
        })
    }
}
