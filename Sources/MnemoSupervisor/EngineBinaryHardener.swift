import Darwin
import Foundation

public enum EngineBinaryHardeningError: Error, Equatable {
    case unsupportedBinary
    case ambiguousBinary
    case signingFailed(Int32)
    case replacementFailed(Int32)
}

public enum EngineBinaryHardener {
    public struct PatchResult: Equatable, Sendable {
        public let data: Data
        public let didPatch: Bool
        public let sourceVersion: String
    }

    private struct CadencePatch {
        let version: String
        let versionMarker: Data
        let upstream: Data
        let hardened: Data
    }

    private static let supportedCadencePatches = [
        CadencePatch(
            version: "0.0.3",
            versionMarker: Data("mk8=\"supermemory-server\",CT=\"0.0.3\"".utf8),
            upstream: Data("kH2=1e4;function SH2".utf8),
            hardened: Data("kH2=3e5;function SH2".utf8)
        ),
        CadencePatch(
            version: "0.0.5",
            versionMarker: Data("HN2=\"supermemory-server\",or=\"0.0.5\"".utf8),
            upstream: Data("GJ4=1e4;function nJ4".utf8),
            hardened: Data("GJ4=3e5;function nJ4".utf8)
        ),
    ]

    /// The bundled server currently snapshots a large PGlite image every ten
    /// seconds. Its dump takes longer than that for real corpora, keeping several
    /// full database copies resident continuously. The replacement is deliberately
    /// byte-for-byte in length so Bun's compiled bundle offsets remain unchanged.
    public static func patch(_ input: Data) throws -> PatchResult {
        let versionCounts = supportedCadencePatches.map {
            occurrenceCount(of: $0.versionMarker, in: input)
        }
        guard versionCounts.reduce(0, +) == 1,
              let patchIndex = versionCounts.firstIndex(of: 1)
        else { throw EngineBinaryHardeningError.unsupportedBinary }

        let cadencePatch = supportedCadencePatches[patchIndex]
        let upstreamCount = occurrenceCount(of: cadencePatch.upstream, in: input)
        let hardenedCount = occurrenceCount(of: cadencePatch.hardened, in: input)
        if upstreamCount == 0, hardenedCount == 1 {
            return PatchResult(
                data: input,
                didPatch: false,
                sourceVersion: cadencePatch.version
            )
        }
        guard upstreamCount == 1, hardenedCount == 0 else {
            throw upstreamCount > 1 || hardenedCount > 1
                ? EngineBinaryHardeningError.ambiguousBinary
                : EngineBinaryHardeningError.unsupportedBinary
        }

        var output = input
        guard let range = output.range(of: cadencePatch.upstream) else {
            throw EngineBinaryHardeningError.unsupportedBinary
        }
        output.replaceSubrange(range, with: cadencePatch.hardened)
        return PatchResult(
            data: output,
            didPatch: true,
            sourceVersion: cadencePatch.version
        )
    }

    /// Applies the supported binary patch through a signed temporary file and
    /// atomic rename. An unknown upstream build fails closed instead of guessing.
    @discardableResult
    public static func harden(
        at path: String,
        fileManager: FileManager = .default,
        signer: ((String) throws -> Void)? = nil
    ) throws -> Bool {
        let sourceURL = URL(fileURLWithPath: path)
        let result = try patch(Data(contentsOf: sourceURL, options: .mappedIfSafe))
        guard result.didPatch else { return false }

        let backupURL = sourceURL.appendingPathExtension(
            "pre-mnemo-snapshot-hardening-v\(result.sourceVersion)"
        )
        let temporaryURL = sourceURL.appendingPathExtension("mnemo-hardening-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try result.data.write(to: temporaryURL, options: .atomic)
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        if let permissions = attributes[.posixPermissions] {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: temporaryURL.path)
        }
        try (signer ?? adHocSign)(temporaryURL.path)
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: sourceURL, to: backupURL)
        }
        guard rename(temporaryURL.path, sourceURL.path) == 0 else {
            throw EngineBinaryHardeningError.replacementFailed(errno)
        }
        return true
    }

    private static func occurrenceCount(of needle: Data, in haystack: Data) -> Int {
        var count = 0
        var lowerBound = haystack.startIndex
        while lowerBound < haystack.endIndex,
              let range = haystack.range(
                  of: needle,
                  in: lowerBound..<haystack.endIndex
              ) {
            count += 1
            lowerBound = range.upperBound
        }
        return count
    }

    private static func adHocSign(_ path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", "--timestamp=none", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw EngineBinaryHardeningError.signingFailed(process.terminationStatus)
        }
    }
}
