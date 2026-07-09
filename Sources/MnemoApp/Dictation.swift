import AVFoundation
import Foundation
import MnemoOrchestrator
import Speech

/// Push-to-talk on-device dictation (UI.md §12). Speech recognition is forced
/// on-device — audio never egresses. The mic tap feeds a smoothed amplitude
/// envelope that drives the listening orb.
///
/// Every failure path (permission denied, no input device, recognizer
/// unavailable, engine start failure) degrades to a visible `problem` message —
/// never a crash, never a silent dead mic.
@MainActor
final class Dictation: ObservableObject {
    @Published var transcript = ""
    @Published var amplitude: Double = 0      // smoothed 0…1 for the orb
    @Published var isListening = false
    @Published var problem: String?           // rendered in the surface when set

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var envelope = MicEnvelope()

    func start() {
        guard !isListening else { return }
        problem = nil
        // Gate on speech authorization first so the first-run prompt doesn't
        // drop audio; the mic prompt follows on engine start.
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            beginCapture()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    if status == .authorized { self.beginCapture() }
                    else { self.problem = "Speech recognition is off. Enable it in System Settings → Privacy & Security." }
                }
            }
        default:
            problem = "Speech recognition is off. Enable it in System Settings → Privacy & Security."
        }
    }

    private func beginCapture() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            problem = "On-device dictation isn't available on this Mac."
            return
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // No input device (or mic permission denied) → a zero-rate format.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            problem = "No microphone available. Check System Settings → Privacy & Security → Microphone."
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true    // invariant: no server path
        request = req

        // Capture the request locally so the realtime tap never touches
        // @MainActor state — only `req.append` and the amplitude helper.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            self?.updateAmplitude(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            request = nil
            problem = "Couldn't start the microphone (\(error.localizedDescription))."
            return
        }

        transcript = ""
        isListening = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.transcript = result.bestTranscription.formattedString }
            } else if error != nil {
                Task { @MainActor in
                    // Recognition died mid-stream (e.g. asset missing): stop
                    // cleanly and tell the user instead of listening forever.
                    if self.isListening && self.transcript.isEmpty {
                        self.problem = "Dictation stopped. You can keep typing."
                    }
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
        amplitude = 0
    }

    private nonisolated func updateAmplitude(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = n > 0 ? Double((sum / Float(n)).squareRoot()) : 0
        Task { @MainActor in
            let target = self.envelope.normalize(rms: rms)
            self.amplitude = self.envelope.follow(target: target)
        }
    }
}
