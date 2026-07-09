import Foundation
@testable import MnemoOrchestrator

enum Phase2Fixtures {
    static func hit(_ label: String, i: Int) -> Retrieved {
        Retrieved(memory: "\(label) fact \(i)", similarity: 0.5 + Double(i % 5) * 0.1,
                  source: SourceLocator(docId: "d\(i)", path: "/\(i).md", title: "t\(i)"))
    }
}
