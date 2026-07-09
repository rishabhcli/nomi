import AVFoundation
import Foundation
import MnemoOrchestrator
import Speech

/// Push-to-talk on-device dictation (UI.md §12) on the macOS 26 **Speech
/// framework**: `SpeechAnalyzer` + `SpeechTranscriber` running the on-device
/// model. Audio never egresses — the model is installed locally via
/// `AssetInventory` and analysis is entirely local.
///
/// Concurrency: `Dictation` is @MainActor for its @Published UI state. Every
/// interaction with the background audio thread and the actor-based analyzer is
/// done through @Sendable closures / `await` hops carrying only Sendable values
/// — never a @MainActor closure on a background queue (the executor-check trap).
///
/// Lifecycle: `start()` runs an async `begin()` that suspends at several awaits
/// (permissions, model install, analyzer start). A `session` counter, bumped by
/// every `start()`/`stop()`, is re-checked after each await so a release that
/// lands mid-setup can never leave a live mic or a "stuck listening" state.
///
/// Every failure path degrades to a visible `problem` message — never a crash,
/// never a silent dead mic.
@MainActor
final class Dictation: ObservableObject {
    @Published var transcript = ""
    @Published var amplitude: Double = 0      // smoothed 0…1 for the orb
    @Published var isListening = false
    @Published var problem: String?           // rendered in the surface when set

    private let engine = AVAudioEngine()
    private var envelope = MicEnvelope()
    private let locale = Locale(identifier: "en-US")

    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var tapInstalled = false
    private var session = 0                    // bumped on every start()/stop()

    func start() {
        guard !isListening, startTask == nil else { return }
        problem = nil
        session &+= 1
        let mine = session
        startTask = Task { [weak self] in
            await self?.begin(mine)
            // Only clear the shared handle if a newer start() hasn't taken over.
            if self?.session == mine { self?.startTask = nil }
        }
    }

    private func begin(_ s: Int) async {
        func abort(_ message: String?) {
            // Superseded by a newer start/stop → stay silent; otherwise surface.
            if s == session, let message { problem = message }
        }

        guard await Self.speechAuthorized() else {
            abort("Speech recognition is off. Enable it in System Settings → Privacy & Security."); return
        }
        guard s == session else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            abort("Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone."); return
        }
        guard s == session else { return }
        guard await Self.localeSupported(locale) else {
            abort("On-device dictation isn't available for your language yet."); return
        }
        guard s == session else { return }

        let transcriber = SpeechTranscriber(locale: locale,
                                            transcriptionOptions: [],
                                            reportingOptions: [.volatileResults],
                                            attributeOptions: [])
        do { try await Self.ensureModel(for: transcriber, locale: locale) }
        catch { abort("Couldn't prepare the on-device dictation model."); return }
        guard s == session else { return }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            abort("On-device dictation isn't available on this Mac."); return
        }
        guard s == session else { return }

        let input = engine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        guard tapFormat.sampleRate > 0, tapFormat.channelCount > 0 else {
            abort("No microphone available. Check System Settings → Privacy & Security → Microphone."); return
        }
        guard let converter = AVAudioConverter(from: tapFormat, to: format) else {
            abort("Couldn't set up audio for dictation on this Mac."); return
        }

        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()

        // Reset BEFORE the analyzer/results go live so an early partial is never
        // blanked by a late reset.
        transcript = ""

        // Live results → transcript, on the main actor. Volatile results show
        // the in-progress tail; finalized results are committed.
        let resultsTask = Task { [weak self] in
            var finalized = ""
            do {
                for try await result in transcriber.results {
                    let piece = String(result.text.characters)
                    if result.isFinal { finalized += piece }
                    let display = result.isFinal ? finalized : finalized + piece
                    await MainActor.run { self?.transcript = display }
                }
            } catch {
                await MainActor.run { self?.stop() }
            }
        }

        // The mic tap runs on the audio render thread — @Sendable, touches no
        // @MainActor state. It converts to the analyzer's format and feeds the
        // (Sendable) stream continuation; the nonisolated amplitude helper
        // drives the orb.
        nonisolated(unsafe) let cvt = converter
        nonisolated(unsafe) let outFormat = format
        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { @Sendable [weak self] buffer, _ in
            if let out = Self.convert(buffer, using: cvt, to: outFormat) {
                builder.yield(AnalyzerInput(buffer: out))
            }
            self?.updateAmplitude(buffer)
        }
        engine.prepare()
        do { try engine.start() }
        catch {
            input.removeTap(onBus: 0); builder.finish(); resultsTask.cancel()
            abort("Couldn't start the microphone (\(error.localizedDescription))."); return
        }
        do { try await analyzer.start(inputSequence: stream) }
        catch {
            input.removeTap(onBus: 0); engine.stop(); builder.finish(); resultsTask.cancel()
            abort("Couldn't start dictation."); return
        }

        // A stop() may have landed while `analyzer.start` was suspended. If so,
        // unwind everything — never commit a listening state over a dead engine.
        guard s == session else {
            input.removeTap(onBus: 0); engine.stop(); builder.finish(); resultsTask.cancel()
            Task.detached { try? await analyzer.finalizeAndFinishThroughEndOfInput() }
            return
        }

        self.analyzer = analyzer
        self.inputBuilder = builder
        self.resultsTask = resultsTask
        tapInstalled = true
        isListening = true
    }

    func stop() {
        session &+= 1                       // invalidate any in-flight begin()
        startTask?.cancel(); startTask = nil
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }
        inputBuilder?.finish(); inputBuilder = nil
        resultsTask?.cancel(); resultsTask = nil
        let analyzer = self.analyzer
        self.analyzer = nil
        isListening = false
        amplitude = 0
        // Flush the analyzer off the interactive path — never blocks the UI.
        if let analyzer { Task.detached { try? await analyzer.finalizeAndFinishThroughEndOfInput() } }
    }

    // MARK: - Nonisolated helpers (safe from any thread)

    private static func speechAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }

    private static func localeSupported(_ locale: Locale) async -> Bool {
        let want = locale.identifier(.bcp47)
        return await SpeechTranscriber.supportedLocales.contains { $0.identifier(.bcp47) == want }
    }

    /// Installs the on-device model for the locale once (no-op if present).
    private static func ensureModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let want = locale.identifier(.bcp47)
        if await SpeechTranscriber.installedLocales.contains(where: { $0.identifier(.bcp47) == want }) { return }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    /// Converts one tap buffer to the analyzer's format. Called only on the
    /// audio thread (single-threaded use of the converter).
    private nonisolated static func convert(_ buffer: AVAudioPCMBuffer,
                                            using converter: AVAudioConverter,
                                            to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard capacity > 0, let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return err == nil ? out : nil
    }

    private nonisolated func updateAmplitude(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = n > 0 ? Double((sum / Float(n)).squareRoot()) : 0
        Task { @MainActor in
            guard self.isListening else { return }   // don't revive the orb after stop()
            let target = self.envelope.normalize(rms: rms)
            self.amplitude = self.envelope.follow(target: target)
        }
    }
}
