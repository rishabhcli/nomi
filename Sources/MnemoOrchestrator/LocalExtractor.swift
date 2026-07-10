import AVFoundation
import Foundation
import PDFKit
import Speech
import Vision

/// On-device media extraction (M2). The self-hosted engine v0.0.3 routes
/// pdf-OCR/image/audio extraction to cloud APIs (Mistral/Gemini) — which the
/// invariant forbids — so Mnemo extracts locally with the platform frameworks
/// (Vision OCR, PDFKit, Speech transcription, textutil) and hands the engine
/// plain text. Everything here works with the network off.
public enum LocalExtractor {
    // A-102: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-158: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-306: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-254: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-202: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    public enum Kind {
        case image, pdf, docx, audioVideo, unsupported

        public init(url: URL) {
            switch url.pathExtension.lowercased() {
            case "png", "jpg", "jpeg", "tiff", "gif", "heic", "webp", "bmp": self = .image
            case "pdf": self = .pdf
            case "docx", "doc", "rtf", "rtfd", "odt", "webarchive": self = .docx
            case "m4a", "mp3", "wav", "aiff", "aac", "flac", "ogg",
                 "mp4", "mov", "webm", "m4v": self = .audioVideo
            default: self = .unsupported
            }
        }
    }

    /// Extracts plain text from a media file, or nil when the type is not ours.
    public static func extract(_ url: URL) async throws -> String? {
        switch Kind(url: url) {
        case .image: return try ocrImage(url)
        case .pdf: return try ocrPDF(url)
        case .docx: return try convertWithTextutil(url)
        case .audioVideo: return try await transcribe(url)
        case .unsupported: return nil
        }
    }

    // MARK: - Vision OCR

    static func ocrImage(_ url: URL) throws -> String? {
        guard let image = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(image, 0, nil) else { return nil }
        return try ocr(cg)
    }

    static func ocr(_ image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: - PDF (text layer first, OCR fallback per page)

    static func ocrPDF(_ url: URL) throws -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            if let text = page.string, text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 {
                pages.append(text)   // real text layer
                continue
            }
            // No text layer — render the page and OCR it (the "scanned" path).
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 3.0   // ~216dpi for reliable OCR
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { continue }
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
            if let cg = ctx.makeImage(), let text = try ocr(cg) {
                pages.append(text)
            }
        }
        let joined = pages.joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
    }

    // MARK: - Word-processing formats

    static func convertWithTextutil(_ url: URL) throws -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        p.arguments = ["-convert", "txt", "-stdout", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0, let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    // MARK: - Speech transcription (on-device only)

    static func transcribe(_ url: URL) async throws -> String? {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.supportsOnDeviceRecognition else { return nil }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true   // never a server path (invariant)
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    cont.resume(throwing: error)
                } else if let result, result.isFinal {
                    finished = true
                    let text = result.bestTranscription.formattedString
                    cont.resume(returning: text.isEmpty ? nil : text)
                }
            }
        }
    }
}

// M11 scheduling budget (A-358)
extension LocalExtractor {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 300
        public static func registerBudget() { SchedulingBudget.register("LocalExtractor", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
