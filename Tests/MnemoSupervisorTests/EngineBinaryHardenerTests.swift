import Foundation
import XCTest
@testable import MnemoSupervisor

final class EngineBinaryHardenerTests: XCTestCase {
    func testPatchesSupportedSnapshotCadenceExactlyOnce() throws {
        let input = Data(
            "prefix;mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=1e4;function SH2($){return $};suffix".utf8
        )

        let result = try EngineBinaryHardener.patch(input)

        XCTAssertTrue(result.didPatch)
        XCTAssertEqual(
            String(decoding: result.data, as: UTF8.self),
            "prefix;mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=3e5;function SH2($){return $};suffix"
        )
        XCTAssertEqual(result.data.count, input.count, "compiled bundle offsets must not move")
    }

    func testAlreadyHardenedBinaryIsIdempotent() throws {
        let input = Data(
            "prefix;mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=3e5;function SH2($){return $};suffix".utf8
        )

        let result = try EngineBinaryHardener.patch(input)

        XCTAssertFalse(result.didPatch)
        XCTAssertEqual(result.data, input)
    }

    func testPatchesSupportedVersionZeroZeroFiveLayout() throws {
        let input = Data(
            "prefix;HN2=\"supermemory-server\",or=\"0.0.5\";GJ4=1e4;function nJ4($){return $};suffix".utf8
        )

        let result = try EngineBinaryHardener.patch(input)

        XCTAssertTrue(result.didPatch)
        XCTAssertEqual(
            String(decoding: result.data, as: UTF8.self),
            "prefix;HN2=\"supermemory-server\",or=\"0.0.5\";GJ4=3e5;function nJ4($){return $};suffix"
        )
        XCTAssertEqual(result.data.count, input.count)
    }

    func testRejectsUnknownOrAmbiguousBinaryInsteadOfGuessing() {
        XCTAssertThrowsError(try EngineBinaryHardener.patch(Data("unknown".utf8)))
        XCTAssertThrowsError(try EngineBinaryHardener.patch(Data(
            "mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=1e4;function SH2;kH2=1e4;function SH2".utf8
        )))
    }

    func testRejectsCoincidentalPatternWithoutSupportedVersionProvenance() {
        XCTAssertThrowsError(try EngineBinaryHardener.patch(Data(
            "prefix;kH2=1e4;function SH2;suffix".utf8
        )))
    }

    func testHardenUsesSignedAtomicReplacementAndKeepsOriginalBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnemo-engine-hardener-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appendingPathComponent("supermemory-server")
        let original = Data(
            "prefix;mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=1e4;function SH2;suffix".utf8
        )
        try original.write(to: binary)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: binary.path
        )
        var signedTemporaryPath: String?

        let changed = try EngineBinaryHardener.harden(at: binary.path) { path in
            signedTemporaryPath = path
            XCTAssertEqual(
                try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int,
                0o755
            )
        }

        XCTAssertTrue(changed)
        XCTAssertNotEqual(signedTemporaryPath, binary.path)
        XCTAssertEqual(
            try Data(contentsOf: binary),
            Data("prefix;mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=3e5;function SH2;suffix".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: binary.appendingPathExtension("pre-mnemo-snapshot-hardening-v0.0.3")),
            original
        )
        XCTAssertFalse(try EngineBinaryHardener.harden(at: binary.path) { _ in
            XCTFail("idempotent hardening must not sign again")
        })
    }

    func testSignerFailureLeavesSourceAndBackupUntouched() throws {
        struct SigningFailure: Error {}
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnemo-engine-hardener-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appendingPathComponent("supermemory-server")
        let original = Data(
            "mk8=\"supermemory-server\",CT=\"0.0.3\";kH2=1e4;function SH2".utf8
        )
        try original.write(to: binary)

        XCTAssertThrowsError(try EngineBinaryHardener.harden(at: binary.path) { _ in
            throw SigningFailure()
        })
        XCTAssertEqual(try Data(contentsOf: binary), original)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: binary.appendingPathExtension("pre-mnemo-snapshot-hardening-v0.0.3").path
        ))
    }

    func testDownloadedVersionZeroZeroFiveBinaryWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["MNEMO_SUPERMEMORY_005_FIXTURE"] else {
            throw XCTSkip("set MNEMO_SUPERMEMORY_005_FIXTURE for release-binary integration")
        }
        let input = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)

        let result = try EngineBinaryHardener.patch(input)

        XCTAssertTrue(result.didPatch)
        XCTAssertEqual(result.sourceVersion, "0.0.5")
        XCTAssertEqual(result.data.count, input.count)
        XCTAssertNotNil(result.data.range(of: Data("GJ4=3e5;function nJ4".utf8)))
        XCTAssertNil(result.data.range(of: Data("GJ4=1e4;function nJ4".utf8)))
    }
}
