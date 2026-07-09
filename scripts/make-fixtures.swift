#!/usr/bin/env swift
// Generates the M2 multi-type fixture corpus OFFLINE (no network):
//   fixture-image.png     — rendered text (OCR target)
//   fixture-scanned.pdf   — image-only PDF, no text layer (OCR target)
//   fixture-doc.docx      — via textutil
//   fixture-memo.m4a      — via `say` (on-device TTS) + afconvert
// Each carries a distinct, greppable fact.
import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "Tests/Fixtures/corpus")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(text: String, size: CGSize) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    NSColor.white.setFill()
    CGRect(origin: .zero, size: size).fill()
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 6
    (text as NSString).draw(
        in: CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 28, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: style,
        ])
    img.unlockFocus()
    return img
}

func pngData(_ img: NSImage) -> Data {
    let tiff = img.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    return rep.representation(using: .png, properties: [:])!
}

// 1. PNG with a unique fact (OCR).
let pngFact = "The staging database password rotates every 45 days according to the platform runbook."
let png = render(text: "PLATFORM RUNBOOK\n\n\(pngFact)", size: .init(width: 1200, height: 500))
try pngData(png).write(to: outDir.appending(path: "fixture-image.png"))
print("wrote fixture-image.png")

// 2. Image-only (scanned-style) PDF — draw the bitmap into a PDF context; no text layer.
let pdfFact = "The Orion project kickoff was moved to September 14 because the vendor contract slipped."
let pdfImg = render(text: "MEETING NOTES (SCANNED)\n\n\(pdfFact)", size: .init(width: 1200, height: 700))
var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 400)
let pdfURL = outDir.appending(path: "fixture-scanned.pdf") as CFURL
let ctx = CGContext(pdfURL, mediaBox: &mediaBox, nil)!
ctx.beginPDFPage(nil)
var rect = CGRect(x: 0, y: 0, width: 612, height: 400)
let cgImg = pdfImg.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
ctx.draw(cgImg, in: mediaBox)
ctx.endPDFPage()
ctx.closePDF()
print("wrote fixture-scanned.pdf")

// 3. docx via textutil.
let docFact = "Quarterly OKR review: the search latency target was tightened to 250 milliseconds."
let mdPath = outDir.appending(path: "tmp-doc.md")
try "# Team OKRs\n\n\(docFact)\n".write(to: mdPath, atomically: true, encoding: .utf8)
let textutil = Process()
textutil.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
textutil.arguments = ["-convert", "docx", mdPath.path, "-output", outDir.appending(path: "fixture-doc.docx").path]
try textutil.run(); textutil.waitUntilExit()
try FileManager.default.removeItem(at: mdPath)
print("wrote fixture-doc.docx (rc=\(textutil.terminationStatus))")

// 4. Audio memo via on-device TTS.
let memoFact = "Reminder to myself: the conference badge pickup code is seven three nine two."
let aiff = outDir.appending(path: "tmp-memo.aiff")
let say = Process()
say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
say.arguments = ["-o", aiff.path, memoFact]
try say.run(); say.waitUntilExit()
let afconvert = Process()
afconvert.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
afconvert.arguments = ["-f", "m4af", "-d", "aac", aiff.path, outDir.appending(path: "fixture-memo.m4a").path]
try afconvert.run(); afconvert.waitUntilExit()
try? FileManager.default.removeItem(at: aiff)
print("wrote fixture-memo.m4a (say rc=\(say.terminationStatus), afconvert rc=\(afconvert.terminationStatus))")

print("fixture corpus ready at \(outDir.path)")
