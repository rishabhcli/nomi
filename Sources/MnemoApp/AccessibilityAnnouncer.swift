import AppKit

/// Posts local application announcements for assistive technologies. This does
/// not synthesize speech itself and never touches the network.
@MainActor
enum AccessibilityAnnouncer {
    static func post(_ text: String) {
        guard !text.isEmpty else { return }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSNumber(value: NSAccessibilityPriorityLevel.medium.rawValue),
            ]
        )
    }
}
