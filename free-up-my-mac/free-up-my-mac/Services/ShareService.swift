import Foundation
import AppKit

struct ShareService: Sendable {

    func generateReport(from result: ScanResult) -> String {
        fatalError("Not yet implemented")
    }

    nonisolated func shareReport(_ report: String, from view: NSView) {
        fatalError("Not yet implemented")
    }

    func exportToCSV(groups: [DuplicateGroup]) -> String {
        fatalError("Not yet implemented")
    }

    func copyToClipboard(_ text: String) {
        fatalError("Not yet implemented")
    }
}
