// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Mnemo",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MnemoCore", targets: ["MnemoCore"]),
        .library(name: "MnemoSupervisor", targets: ["MnemoSupervisor"]),
        .library(name: "MnemoOrchestrator", targets: ["MnemoOrchestrator"]),
        .executable(name: "mnemoctl", targets: ["mnemoctl"]),
        .executable(name: "MnemoApp", targets: ["MnemoApp"]),
    ],
    targets: [
        .target(name: "MnemoCore"),
        .target(name: "MnemoSupervisor", dependencies: ["MnemoCore"]),
        .target(name: "MnemoOrchestrator", dependencies: ["MnemoCore"]),
        .executableTarget(name: "mnemoctl", dependencies: ["MnemoSupervisor", "MnemoOrchestrator"]),
        .executableTarget(name: "MnemoApp", dependencies: ["MnemoOrchestrator", "MnemoSupervisor"],
                          exclude: ["Info.plist"],
                          resources: [.process("VoiceOrb.metal")],
                          // A bare SwiftPM executable has no Info.plist, so TCC
                          // KILLS the process on the first privacy-API touch
                          // (mic/speech). Embedding the plist in __TEXT makes
                          // TCC prompt instead (crash fix, verified via the
                          // 2026-07-09 MnemoApp .ips: "must contain an
                          // NSSpeechRecognitionUsageDescription key").
                          linkerSettings: [.unsafeFlags([
                              "-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/MnemoApp/Info.plist",
                          ])]),
        .testTarget(name: "MnemoCoreTests", dependencies: ["MnemoCore"]),
        .testTarget(name: "MnemoSupervisorTests", dependencies: ["MnemoSupervisor"]),
        .testTarget(name: "MnemoOrchestratorTests", dependencies: ["MnemoOrchestrator"]),
    ]
)
